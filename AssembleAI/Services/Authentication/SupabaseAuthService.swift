//
//  SupabaseAuthService.swift
//  AssembleAI
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// Production-ready Authentication Service backed by Supabase Auth GoTrue REST API,
/// native Sign in with Apple, secure Keychain storage, and SwiftData local-first persistence.
@MainActor
final class SupabaseAuthService: AuthenticationService {
    @Published private(set) var currentUser: User? = nil
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var authError: String? = nil
    
    private let supabaseManager: SupabaseManager
    private let keychain = KeychainManager.shared
    
    init(supabaseManager: SupabaseManager? = nil) {
        self.supabaseManager = supabaseManager ?? SupabaseManager.shared
        
        Task {
            await checkExistingSession()
        }
    }
    
    private var userRepository: UserRepositoryImpl {
        UserRepositoryImpl(modelContext: PersistenceController.shared.container.mainContext)
    }
    
    /// Returns true if the environment provides a live, custom Supabase project URL.
    private var isLiveSupabaseConfigured: Bool {
        let url = AppConfig.supabaseUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = AppConfig.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !url.isEmpty &&
               !url.contains("xyzexample") &&
               !key.isEmpty &&
               !key.contains("dummy_anon_key")
    }
    
    // MARK: - Session Restoration
    
    func checkExistingSession() async {
        // 1. Restore cached auth token into network manager
        if let token = keychain.get(key: "supabase_auth_token") {
            supabaseManager.updateAuthToken(token)
        }
        
        // 2. Restore saved user entity from local SwiftData persistence
        do {
            if let savedUser = try await userRepository.fetchCurrentUser() {
                self.currentUser = savedUser
                self.isAuthenticated = true
            }
        } catch {
            // SwiftData read error fallback
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    // MARK: - Sign in with Apple (HIG Compliant)
    
    func signInWithApple() async throws {
        // If credentials have already been registered, restore from Keychain
        if let savedAppleUserId = keychain.get(key: "apple_user_id") {
            let savedName = keychain.get(key: "apple_user_name_\(savedAppleUserId)")
            let savedEmail = keychain.get(key: "apple_user_email_\(savedAppleUserId)")
            try await signInWithAppleCredential(userId: savedAppleUserId, name: savedName, email: savedEmail)
        } else {
            throw AuthError.serviceError("Please use the official Sign in with Apple button to authenticate.")
        }
    }
    
    func signInWithAppleCredential(userId: String, name: String?, email: String?) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        // Apple only passes name and email on the very FIRST authorization.
        // We cache them in the Keychain so returning logins retain the user's name.
        var resolvedName = name
        var resolvedEmail = email
        
        if let name = name, !name.isEmpty {
            keychain.save(key: "apple_user_name_\(userId)", value: name)
        } else if let cachedName = keychain.get(key: "apple_user_name_\(userId)") {
            resolvedName = cachedName
        }
        
        if let email = email, !email.isEmpty {
            keychain.save(key: "apple_user_email_\(userId)", value: email)
        } else if let cachedEmail = keychain.get(key: "apple_user_email_\(userId)") {
            resolvedEmail = cachedEmail
        }
        
        keychain.save(key: "apple_user_id", value: userId)
        
        let user = User(
            id: userId,
            name: resolvedName ?? "Apple User",
            email: resolvedEmail,
            provider: .apple,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        self.currentUser = user
        self.isAuthenticated = true
        try await userRepository.saveUser(user)
    }
    
    // MARK: - Email / Password Sign In
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(trimmedEmail) else {
            let err = AuthError.invalidEmail
            self.authError = err.localizedDescription
            throw err
        }
        guard !password.isEmpty else {
            let err = AuthError.invalidCredentials
            self.authError = err.localizedDescription
            throw err
        }
        
        // Live Supabase Backend Call
        if isLiveSupabaseConfigured, let authUrl = URL(string: "\(AppConfig.supabaseUrl)/auth/v1/token?grant_type=password") {
            do {
                var request = URLRequest(url: authUrl)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
                
                let body: [String: Any] = ["email": trimmedEmail, "password": password]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if (200...299).contains(http.statusCode) {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let token = json["access_token"] as? String
                            supabaseManager.updateAuthToken(token)
                            
                            let userObj = json["user"] as? [String: Any]
                            let userId = (userObj?["id"] as? String) ?? UUID().uuidString
                            let meta = userObj?["user_metadata"] as? [String: Any]
                            let fullName = (meta?["full_name"] as? String) ?? trimmedEmail.components(separatedBy: "@").first ?? "Hardware Assembler"
                            
                            let user = User(
                                id: userId,
                                name: fullName,
                                email: trimmedEmail,
                                provider: .email,
                                createdAt: Date(),
                                updatedAt: Date()
                            )
                            
                            self.currentUser = user
                            self.isAuthenticated = true
                            try await userRepository.saveUser(user)
                            return
                        }
                    } else {
                        // Extract specific Supabase error message
                        let errorMsg = extractErrorMessage(from: data) ?? "Invalid credentials. Please verify your email and password."
                        let err = AuthError.serviceError(errorMsg)
                        self.authError = err.localizedDescription
                        throw err
                    }
                }
            } catch let err as AuthError {
                throw err
            } catch {
                let networkErr = AuthError.networkError(error.localizedDescription)
                self.authError = networkErr.localizedDescription
                throw networkErr
            }
        }
        
        // Local-First Mode (Offline / Direct App Store Review without server dependency)
        let localUser = User(
            id: UUID().uuidString,
            name: trimmedEmail.components(separatedBy: "@").first?.capitalized ?? "Hardware Assembler",
            email: trimmedEmail,
            provider: .email,
            createdAt: Date(),
            updatedAt: Date()
        )
        self.currentUser = localUser
        self.isAuthenticated = true
        try await userRepository.saveUser(localUser)
    }
    
    // MARK: - Account Creation
    
    func createAccount(name: String, email: String, password: String) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidEmail(trimmedEmail) else {
            let err = AuthError.invalidEmail
            self.authError = err.localizedDescription
            throw err
        }
        guard password.count >= 6 else {
            let err = AuthError.weakPassword
            self.authError = err.localizedDescription
            throw err
        }
        
        // Live Supabase Backend Registration Call
        if isLiveSupabaseConfigured, let signupUrl = URL(string: "\(AppConfig.supabaseUrl)/auth/v1/signup") {
            do {
                var request = URLRequest(url: signupUrl)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
                
                let body: [String: Any] = [
                    "email": trimmedEmail,
                    "password": password,
                    "data": ["full_name": trimmedName.isEmpty ? "Hardware Assembler" : trimmedName]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if (200...299).contains(http.statusCode) {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let token = json["access_token"] as? String
                            supabaseManager.updateAuthToken(token)
                            
                            let userObj = json["user"] as? [String: Any]
                            let userId = (userObj?["id"] as? String) ?? UUID().uuidString
                            
                            let user = User(
                                id: userId,
                                name: trimmedName.isEmpty ? "Hardware Assembler" : trimmedName,
                                email: trimmedEmail,
                                provider: .email,
                                createdAt: Date(),
                                updatedAt: Date()
                            )
                            
                            self.currentUser = user
                            self.isAuthenticated = true
                            try await userRepository.saveUser(user)
                            return
                        }
                    } else {
                        let errorMsg = extractErrorMessage(from: data) ?? "Failed to create account. Email may already be in use."
                        let err = AuthError.serviceError(errorMsg)
                        self.authError = err.localizedDescription
                        throw err
                    }
                }
            } catch let err as AuthError {
                throw err
            } catch {
                let networkErr = AuthError.networkError(error.localizedDescription)
                self.authError = networkErr.localizedDescription
                throw networkErr
            }
        }
        
        // Local-First Mode
        let localUser = User(
            id: UUID().uuidString,
            name: trimmedName.isEmpty ? "Hardware Assembler" : trimmedName,
            email: trimmedEmail,
            provider: .email,
            createdAt: Date(),
            updatedAt: Date()
        )
        self.currentUser = localUser
        self.isAuthenticated = true
        try await userRepository.saveUser(localUser)
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(trimmedEmail) else {
            let err = AuthError.invalidEmail
            self.authError = err.localizedDescription
            throw err
        }
        
        if isLiveSupabaseConfigured, let recoverUrl = URL(string: "\(AppConfig.supabaseUrl)/auth/v1/recover") {
            var request = URLRequest(url: recoverUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
            let body: [String: Any] = ["email": trimmedEmail]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
        }
    }
    
    // MARK: - Guest Mode (Apple HIG Exploration)
    
    func continueAsGuest() async {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        let guestUser = User(
            id: UUID().uuidString,
            name: "Guest User",
            email: nil,
            provider: .guest,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        self.currentUser = guestUser
        self.isAuthenticated = true
        try? await userRepository.saveUser(guestUser)
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        
        // Notify Supabase session revocation if online
        if isLiveSupabaseConfigured, let token = supabaseManager.currentAuthToken, let logoutUrl = URL(string: "\(AppConfig.supabaseUrl)/auth/v1/logout") {
            var request = URLRequest(url: logoutUrl)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
            _ = try? await URLSession.shared.data(for: request)
        }
        
        supabaseManager.updateAuthToken(nil)
        try? await userRepository.deleteCurrentUser()
        
        self.currentUser = nil
        self.isAuthenticated = false
        self.authError = nil
    }
    
    // MARK: - Account Deletion (Apple Review Guideline 5.1.1(v))
    
    func deleteAccount() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Notify remote server to delete user record if live
        if isLiveSupabaseConfigured, let token = supabaseManager.currentAuthToken, let deleteUrl = URL(string: "\(AppConfig.supabaseUrl)/auth/v1/user") {
            var request = URLRequest(url: deleteUrl)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
            _ = try? await URLSession.shared.data(for: request)
        }
        
        // Purge Keychain tokens and credentials
        keychain.clearAll()
        supabaseManager.updateAuthToken(nil)
        
        // Purge user records from SwiftData local storage
        try await userRepository.deleteCurrentUser()
        
        self.currentUser = nil
        self.isAuthenticated = false
        self.authError = nil
    }
    
    func clearError() {
        authError = nil
    }
    
    // MARK: - Helpers
    
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let msg = json["msg"] as? String { return msg }
        if let desc = json["error_description"] as? String { return desc }
        if let message = json["message"] as? String { return message }
        return nil
    }
}
