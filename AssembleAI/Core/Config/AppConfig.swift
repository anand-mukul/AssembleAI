//
//  AppConfig.swift
//  AssembleAI
//

import Foundation

/// Centralized configuration provider for API endpoints, backend options, and runtime environments.
enum AppConfig {
    static let appName = "AssembleAI"
    static let appVersion = "1.0.0"
    
    /// Supabase Project URL (Replace with your free Supabase Project URL)
    nonisolated static var supabaseUrl: String {
        return ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://xyzexample.supabase.co"
    }
    
    /// Supabase Anon API Key (Replace with your free Supabase Anon Key)
    nonisolated static var supabaseAnonKey: String {
        return ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy_anon_key"
    }
}
