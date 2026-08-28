//
//  AppConfig.swift
//  AssembleAI
//

import Foundation

/// Application Environment Configuration manager for Apple CloudKit container identification.
enum AppConfig {
    static var cloudKitContainerIdentifier: String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CLOUDKIT_CONTAINER_ID") as? String, !value.isEmpty {
            return value
        }
        return ProcessInfo.processInfo.environment["CLOUDKIT_CONTAINER_ID"]
    }
}
