//
//  AppConfig.swift
//  AssembleAI
//

import Foundation

/// Application Environment Configuration manager for Apple CloudKit container identification.
enum AppConfig {
    static var isCloudKitEnabled: Bool {
        boolValue(for: "ENABLE_CLOUDKIT")
    }
    
    static var cloudKitContainerIdentifier: String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CLOUDKIT_CONTAINER_ID") as? String, !value.isEmpty {
            return value
        }
        return ProcessInfo.processInfo.environment["CLOUDKIT_CONTAINER_ID"]
    }
    
    private static func boolValue(for key: String) -> Bool {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return ["1", "true", "yes"].contains(value.lowercased())
        }
        
        if let value = ProcessInfo.processInfo.environment[key] {
            return ["1", "true", "yes"].contains(value.lowercased())
        }
        
        return false
    }
}
