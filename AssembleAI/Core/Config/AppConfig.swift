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
    
    /// Reads parsed key-value pairs from the bundled Config.xcconfig file (if present in Resources)
    private nonisolated static let bundledXcconfig: [String: String] = {
        let possibleUrls = [
            Bundle.main.url(forResource: "Config", withExtension: "xcconfig"),
            Bundle.main.bundleURL.appendingPathComponent("Config.xcconfig"),
            Bundle.main.url(forResource: "Config.xcconfig", withExtension: nil)
        ]
        
        for case let url? in possibleUrls {
            if let content = try? String(contentsOf: url, encoding: .utf8), !content.isEmpty {
                var dict: [String: String] = [:]
                for line in content.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") || trimmed.isEmpty { continue }
                    let parts = trimmed.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                    if parts.count == 2 {
                        let key = parts[0]
                        var val = parts[1]
                        // Strip trailing inline comment if present (e.g. "value // comment", but not "https://...")
                        if let commentIdx = val.range(of: "//") {
                            let prefix = val[..<commentIdx.lowerBound]
                            if !prefix.hasSuffix(":") {
                                val = String(prefix).trimmingCharacters(in: .whitespaces)
                            }
                        }
                        if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                            val = String(val.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                        }
                        val = val.replacingOccurrences(of: "$(SLASH)", with: "/")
                        dict[key] = val
                    }
                }
                if !dict.isEmpty {
                    return dict
                }
            }
        }
        return [:]
    }()
    
    /// Supabase Project URL
    nonisolated static var supabaseUrl: String {
        let rawUrl: String? = {
            if let envUrl = sanitizeConfigValue(ProcessInfo.processInfo.environment["SUPABASE_URL"]), !envUrl.isEmpty, !envUrl.contains("$") {
                return envUrl
            }
            if let plistUrl = sanitizeConfigValue(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String), !plistUrl.isEmpty, !plistUrl.contains("$") {
                return plistUrl
            }
            if let storedUrl = sanitizeConfigValue(UserDefaults.standard.string(forKey: "supabase_project_url")), !storedUrl.isEmpty, !storedUrl.contains("$") {
                return storedUrl
            }
            if let bundledUrl = sanitizeConfigValue(bundledXcconfig["SUPABASE_URL"]), !bundledUrl.isEmpty, !bundledUrl.contains("$") {
                return bundledUrl
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
            if let storedKey = sanitizeConfigValue(UserDefaults.standard.string(forKey: "supabase_anon_key")), !storedKey.isEmpty, !storedKey.contains("$"), !storedKey.contains("NOT_FOUND") {
                return storedKey
            }
            if let bundledKey = sanitizeConfigValue(bundledXcconfig[key]), !bundledKey.isEmpty, !bundledKey.contains("$"), !bundledKey.contains("NOT_FOUND") {
                return bundledKey
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
        if let bundledUrl = sanitizeConfigValue(bundledXcconfig["RESEARCH_WEBHOOK_URL"]), !bundledUrl.isEmpty, !bundledUrl.contains("$") {
            return bundledUrl
        }
        // No default webhook — set RESEARCH_WEBHOOK_URL in Config.xcconfig or UserDefaults
        return nil
    }
}
