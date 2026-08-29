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
            self.isConnected = true
        }
    }
    
    /// Updates and securely saves active authorization bearer token.
    func updateAuthToken(_ token: String?) {
        self.currentAuthToken = token
        if let token = token {
            keychain.save(key: "supabase_auth_token", value: token)
            self.isConnected = true
        } else {
            keychain.delete(key: "supabase_auth_token")
            self.isConnected = false
        }
    }
    
    /// Prepares URLRequest with Supabase Anon Key and Bearer Auth Headers adhering to HTTPS standards.
    func prepareRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        if let token = currentAuthToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
}
