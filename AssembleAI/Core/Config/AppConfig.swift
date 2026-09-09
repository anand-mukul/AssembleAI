//
//  AppConfig.swift
//  AssembleAI
//

import Foundation

/// Centralized configuration provider for API endpoints, backend options, and runtime environments.
enum AppConfig {
    nonisolated static let appName = "AssembleAI"
    nonisolated static let appVersion = "1.0.0"
    nonisolated static let buildNumber = "1"
    
    /// Sanitizes configuration strings read from xcconfig/Info.plist/environment
    private nonisolated static func sanitizeConfigValue(_ value: String?) -> String? {
        guard var trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        // Strip wrapping quotes if user entered them in xcconfig
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            trimmed = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Resolve $(SLASH) if xcconfig macro remained unexpanded
        trimmed = trimmed.replacingOccurrences(of: "$(SLASH)", with: "/")
        return trimmed.isEmpty ? nil : trimmed
    }
    
    /// Supabase Project URL
    nonisolated static var supabaseUrl: String {
        let rawUrl: String? = {
            if let envUrl = sanitizeConfigValue(ProcessInfo.processInfo.environment["SUPABASE_URL"]), !envUrl.isEmpty, !envUrl.contains("$") {
                return envUrl
            }
            if let plistUrl = sanitizeConfigValue(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String), !plistUrl.isEmpty, !plistUrl.contains("$") {
                return plistUrl
            }
            return nil  // No fallback — credentials must come from Config.xcconfig
        }()
        
        guard let url = rawUrl,
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
            if let envKey = sanitizeConfigValue(ProcessInfo.processInfo.environment[key]), !envKey.isEmpty, !envKey.contains("NOT_FOUND"), !envKey.contains("$") {
                return envKey
            }
            if let plistKey = sanitizeConfigValue(Bundle.main.object(forInfoDictionaryKey: key) as? String), !plistKey.isEmpty, !plistKey.contains("$"), !plistKey.contains("NOT_FOUND") {
                return plistKey
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
    
    /// Optional research telemetry webhook URL (e.g. Google Apps Script, Airtable, PostHog, or custom endpoint).
    nonisolated static var researchTelemetryWebhookURL: String? {
        if let envUrl = sanitizeConfigValue(ProcessInfo.processInfo.environment["RESEARCH_WEBHOOK_URL"]), !envUrl.isEmpty, !envUrl.contains("$") {
            return envUrl
        }
        if let plistUrl = sanitizeConfigValue(Bundle.main.object(forInfoDictionaryKey: "RESEARCH_WEBHOOK_URL") as? String), !plistUrl.isEmpty, !plistUrl.contains("$") {
            return plistUrl
        }
        if let stored = UserDefaults.standard.string(forKey: "research_webhook_url"),
           let sanitizedStored = sanitizeConfigValue(stored) {
            return sanitizedStored
        }
        // No default webhook — set RESEARCH_WEBHOOK_URL in Config.xcconfig or UserDefaults
        return nil
    }
}
