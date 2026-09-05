//
//  AppConfig.swift
//  AssembleAI
//

import Foundation

/// Centralized configuration provider for API endpoints, backend options, and runtime environments.
enum AppConfig {
    static let appName = "AssembleAI"
    static let appVersion = "1.0.0"
    static let buildNumber = "1"
    
    /// Supabase Project URL
    nonisolated static var supabaseUrl: String {
        let rawUrl: String? = {
            if let envUrl = ProcessInfo.processInfo.environment["SUPABASE_URL"], !envUrl.isEmpty {
                return envUrl
            }
            if let plistUrl = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String, !plistUrl.isEmpty, !plistUrl.contains("$") {
                return plistUrl
            }
            return nil
        }()
        
        guard let url = rawUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !url.isEmpty,
              url.hasPrefix("https://"),
              !url.contains("SUPABASE_URL_NOT_FOUND") else {
            return "SUPABASE_URL_NOT_FOUND"
        }
        
        // Strip trailing slash if present for consistent endpoint concatenation
        return url.hasSuffix("/") ? String(url.dropLast()) : url
    } 
    
    /// Supabase Anon / Publishable API Key
    nonisolated static var supabaseAnonKey: String {
        let candidateKeys = ["SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY"]
        for key in candidateKeys {
            if let envKey = ProcessInfo.processInfo.environment[key], !envKey.isEmpty, !envKey.contains("NOT_FOUND") {
                return envKey.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let plistKey = Bundle.main.object(forInfoDictionaryKey: key) as? String, !plistKey.isEmpty, !plistKey.contains("$"), !plistKey.contains("NOT_FOUND") {
                return plistKey.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "SUPABASE_KEY_NOT_FOUND"
    }
    
    /// Returns true if valid live Supabase credentials are wired into the environment
    nonisolated static var isSupabaseConfigured: Bool {
        let url = supabaseUrl
        let key = supabaseAnonKey
        return url.hasPrefix("https://") &&
               !url.contains("NOT_FOUND") &&
               !url.contains("xyzexample") &&
               key.count > 20 &&
               !key.contains("NOT_FOUND") &&
               !key.contains("dummy_anon_key")
    }
}
