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
    @Published private(set) var isSessionRestored: Bool = false
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
    
    /// Returns true if the environment provides a live, custom Supabase project URL and key.
    private var isLiveSupabaseConfigured: Bool {
        AppConfig.isSupabaseConfigured
    }
    
    // MARK: - Session Restoration
    
    func checkExistingSession() async {
        defer {
            self.isSessionRestored = true
        }
        
        // 1. Restore cached auth token into network manager
        if let token = keychain.get(key: "supabase_auth_token") {
            supabaseManager.updateAuthToken(token)
        }
        
        // 2. Proactively refresh token with Supabase if refresh token exists
        if isLiveSupabaseConfigured, let refreshToken = keychain.get(key: "supabase_refresh_token") {
            await refreshSession(refreshToken: refreshToken)
        }
        
        // 3. Restore saved user entity from local SwiftData persistence
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
    
    private func refreshSession(refreshToken: String) async {
        guard isLiveSupabaseConfigured,
              let refreshUrl = URL(string: "\(AppConfig.supabaseUrl)/auth/v1/token?grant_type=refresh_token") else { return }
        
        do {
            var request = URLRequest(url: refreshUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
            
            let body: [String: Any] = ["refresh_token": refreshToken]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let newToken = json["access_token"] as? String {
                        supabaseManager.updateAuthToken(newToken)
                    }
                    if let newRefreshToken = json["refresh_token"] as? String {
                        keychain.save(key: "supabase_refresh_token", value: newRefreshToken)
                    }
                }
            }
        } catch {
            // Retain existing cached session if offline
        }
    }
    
    // MARK: - Sign in with Apple (HIG Compliant)
    
    func signInWithApple() async throws {
        // If credentials have already been registered, restore from Keychain
        if let savedAppleUserId = keychain.get(key: "apple_user_id") {
            let savedName = keychain.get(key: "apple_user_name_\(savedAppleUserId)")
            let savedEmail = keychain.get(key: "apple_user_email_\(savedAppleUserId)")
            try await signInWithAppleCredential(userId: savedAppleUserId, name: savedName, email: savedEmail, idToken: nil)
        } else {
            throw AuthError.serviceError("Please use the official Sign in with Apple button to authenticate.")
        }
    }
    
    func signInWithAppleCredential(userId: String, name: String?, email: String?) async throws {
        try await signInWithAppleCredential(userId: userId, name: name, email: email, idToken: nil)
    }
    
    func signInWithAppleCredential(userId: String, name: String?, email: String?, idToken: String?) async throws {
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
        
        var resolvedUserId = userId
        
        // Exchange Apple identity token with Supabase GoTrue if configured
        if isLiveSupabaseConfigured,
           let idToken = idToken, !idToken.isEmpty,
           let appleAuthUrl = URL(string: "\(AppConfig.supabaseUrl)/auth/v1/token?grant_type=id_token") {
            do {
                var request = URLRequest(url: appleAuthUrl)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
                
                let body: [String: Any] = [
                    "provider": "apple",
                    "id_token": idToken
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let token = json["access_token"] as? String {
                        supabaseManager.updateAuthToken(token)
                    }
                    if let refreshToken = json["refresh_token"] as? String {
                        keychain.save(key: "supabase_refresh_token", value: refreshToken)
                    }
                    if let userObj = json["user"] as? [String: Any], let sId = userObj["id"] as? String {
                        resolvedUserId = sId
                    }
                }
            } catch {
                // Retain local sign-in if remote Supabase Apple provider exchange encounters transient errors
            }
        }
        
        let user = User(
            id: resolvedUserId,
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
        
        // 1. Live Supabase Backend Sign In
        if isLiveSupabaseConfigured {
            guard let authUrl = URL(string: "\(AppConfig.supabaseUrl)/auth/v1/token?grant_type=password") else {
                let configErr = AuthError.serviceError("Invalid Supabase project URL configuration.")
                self.authError = configErr.localizedDescription
                throw configErr
            }
            
            do {
                var request = URLRequest(url: authUrl)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
                
                let body: [String: Any] = ["email": trimmedEmail, "password": password]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    let netErr = AuthError.networkError("Invalid server response.")
                    self.authError = netErr.localizedDescription
                    throw netErr
                }
                
                if (200...299).contains(http.statusCode) {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let token = json["access_token"] as? String
                        supabaseManager.updateAuthToken(token)
                        if let refreshToken = json["refresh_token"] as? String {
                            keychain.save(key: "supabase_refresh_token", value: refreshToken)
                        }
                        
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
                    } else {
                        let parseErr = AuthError.serviceError("Failed to parse server authentication response.")
                        self.authError = parseErr.localizedDescription
                        throw parseErr
                    }
                } else {
                    // Extract detailed Supabase error message (e.g. Email not confirmed, Invalid login credentials)
                    let errorMsg = extractErrorMessage(from: data) ?? "Incorrect email or password. Please check your credentials and try again."
                    let err = AuthError.serviceError(errorMsg)
                    self.authError = err.localizedDescription
                    throw err
                }
            } catch let err as AuthError {
                throw err
            } catch {
                let networkErr = AuthError.networkError(error.localizedDescription)
                self.authError = networkErr.localizedDescription
                throw networkErr
            }
        }
        
        // 2. Local-First Mode (Offline / Unconfigured backend)
        // Strictly require an existing locally registered account. NEVER bypass or mint a new account!
        if let existingUser = try? await userRepository.fetchCurrentUser(),
           let savedEmail = existingUser.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           savedEmail == trimmedEmail {
            self.currentUser = existingUser
            self.isAuthenticated = true
            return
        }
        
        let notFoundErr = AuthError.invalidCredentials
        self.authError = notFoundErr.localizedDescription
        throw notFoundErr
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
        
        // 1. Live Supabase Backend Registration Call
        if isLiveSupabaseConfigured {
            guard let signupUrl = URL(string: "\(AppConfig.supabaseUrl)/auth/v1/signup") else {
                let configErr = AuthError.serviceError("Invalid Supabase project URL configuration.")
                self.authError = configErr.localizedDescription
                throw configErr
            }
            
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
                guard let http = response as? HTTPURLResponse else {
                    let netErr = AuthError.networkError("Invalid server response.")
                    self.authError = netErr.localizedDescription
                    throw netErr
                }
                
                if (200...299).contains(http.statusCode) {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let token = json["access_token"] as? String
                        let refreshToken = json["refresh_token"] as? String
                        
                        if let token = token {
                            supabaseManager.updateAuthToken(token)
                        }
                        if let refreshToken = refreshToken {
                            keychain.save(key: "supabase_refresh_token", value: refreshToken)
                        }
                        
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
                        
                        if token != nil {
                            // Supabase project with "Confirm email: OFF" -> immediate authentication
                            self.currentUser = user
                            self.isAuthenticated = true
                            try await userRepository.saveUser(user)
                            return
                        } else {
                            // Supabase project with "Confirm email: ON" -> verification email dispatched
                            self.currentUser = nil
                            self.isAuthenticated = false
                            return
                        }
                    }
                } else {
                    let errorMsg = extractErrorMessage(from: data) ?? "Failed to create account. Email may already be in use."
                    let err = AuthError.serviceError(errorMsg)
                    self.authError = err.localizedDescription
                    throw err
                }
            } catch let err as AuthError {
                throw err
            } catch {
                let networkErr = AuthError.networkError(error.localizedDescription)
                self.authError = networkErr.localizedDescription
                throw networkErr
            }
        }
        
        // 2. Local-First Mode (Offline / Direct App Store Review without server dependency)
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
        
        keychain.delete(key: "supabase_refresh_token")
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
        
        // 1. Invoke Supabase PostgreSQL RPC to delete user record safely from auth.users (cascades to profiles, sessions, projects)
        if isLiveSupabaseConfigured, let token = supabaseManager.currentAuthToken, let rpcUrl = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/rpc/delete_user_account") {
            var request = URLRequest(url: rpcUrl)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            _ = try? await URLSession.shared.data(for: request)
        }
        
        // 2. Purge Keychain tokens and credentials
        keychain.clearAll()
        keychain.delete(key: "supabase_refresh_token")
        supabaseManager.updateAuthToken(nil)
        
        // 3. Purge user records from SwiftData local storage
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
        var rawMsg: String? = nil
        if let msg = json["msg"] as? String { rawMsg = msg }
        else if let desc = json["error_description"] as? String { rawMsg = desc }
        else if let message = json["message"] as? String { rawMsg = message }
        else if let error = json["error"] as? String { rawMsg = error }
        
        guard let raw = rawMsg else { return nil }
        let lower = raw.lowercased()
        if lower.contains("email not confirmed") {
            return "Please verify your email address before signing in. Check your inbox for the confirmation link."
        }
        if lower.contains("invalid login credentials") || lower.contains("invalid_grant") || lower.contains("user not found") {
            return "Incorrect email or password. Please check your credentials and try again, or create a new account."
        }
        if lower.contains("user already registered") || lower.contains("already registered") {
            return "An account with this email address already exists. Please sign in instead."
        }
        if lower.contains("rate limit") || lower.contains("too many requests") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if lower.contains("password should be at least") {
            return "Password must be at least 6 characters long."
        }
        return "Incorrect email or password. Please check your credentials and try again."
    }
}
