//
//  PersistenceController.swift
//  AssembleAI
//

import Foundation
import SwiftData
import os

/// Manages the SwiftData ModelContainer for local-first persistence.
@MainActor
final class PersistenceController {
    static let shared = PersistenceController()
    
    let container: ModelContainer
    
    init(inMemory: Bool = false) {
        let schema = Schema([
            LocalUser.self,
            LocalProject.self,
            LocalAssemblyStep.self,
            LocalComponent.self,
            LocalAssemblySession.self,
            LocalAttempt.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            let logger = Logger(subsystem: "com.mukul.assembleai", category: "Persistence")
            logger.critical("Failed to initialize primary SwiftData ModelContainer: \(error.localizedDescription)")
            
            // Fallback recovery: attempt in-memory store so the app can launch safely without crashing
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [fallbackConfig])
                logger.warning("Initialized in-memory ModelContainer recovery fallback.")
            } catch {
                fatalError("Catastrophic failure to initialize in-memory SwiftData container: \(error.localizedDescription)")
            }
        }
    }
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
}
