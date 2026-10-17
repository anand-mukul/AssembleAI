//
//  SupabaseManager.swift
//  AssembleAI
//

import Foundation
import Combine

/// Centralized manager for Supabase API requests, authentication headers, and network status.
@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var currentAuthToken: String? = nil
    @Published private(set) var currentUserId: String? = nil
    
    private let urlSession: URLSession
    private let keychain = KeychainManager.shared
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15.0
        configuration.timeoutIntervalForResource = 30.0
        configuration.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: configuration)
        
        // Restore saved auth token from iOS Keychain
        if let savedToken = keychain.get(key: "supabase_auth_token") {
            self.currentAuthToken = savedToken
            self.currentUserId = keychain.get(key: "supabase_user_id")
            self.isConnected = true
        }
    }
    
    /// Updates and securely saves active authorization bearer token.
    func updateAuthToken(_ token: String?, userId: String? = nil) {
        self.currentAuthToken = token
        self.currentUserId = userId ?? self.currentUserId
        
        if let token = token {
            keychain.save(key: "supabase_auth_token", value: token)
            if let uid = self.currentUserId {
                keychain.save(key: "supabase_user_id", value: uid)
            }
            self.isConnected = true
        } else {
            keychain.delete(key: "supabase_auth_token")
            keychain.delete(key: "supabase_user_id")
            self.currentUserId = nil
            self.isConnected = false
        }
    }
    
    func prepareRequest(url: URL, method: String = "GET", authenticated: Bool = true) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        if authenticated {
            if let token = currentAuthToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            }
        } else {
            request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    /// Inspects the JWT exp claim to check if the active access token is expired or within 60s of expiration.
    func isTokenExpired(token: String?) -> Bool {
        guard let token = token, !token.isEmpty else { return true }
        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else { return false }
        
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        guard let payloadData = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return false
        }
        
        return Date().timeIntervalSince1970 >= (exp - 60)
    }
    
    /// Proactively refreshes the session if the access token has expired.
    func refreshTokenIfNeeded() async {
        guard isTokenExpired(token: currentAuthToken),
              AppConfig.isSupabaseConfigured,
              let refreshToken = keychain.get(key: "supabase_refresh_token"),
              let refreshUrl = URL(string: "\(AppConfig.supabaseUrl)/auth/v1/token?grant_type=refresh_token") else {
            return
        }
        
        do {
            var request = URLRequest(url: refreshUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
            let body: [String: Any] = ["refresh_token": refreshToken]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let newToken = json["access_token"] as? String {
                    let userObj = json["user"] as? [String: Any]
                    let userId = userObj?["id"] as? String
                    updateAuthToken(newToken, userId: userId)
                }
                if let newRefreshToken = json["refresh_token"] as? String {
                    keychain.save(key: "supabase_refresh_token", value: newRefreshToken)
                }
            }
        } catch {
            // Retain existing session offline
        }
    }
}
