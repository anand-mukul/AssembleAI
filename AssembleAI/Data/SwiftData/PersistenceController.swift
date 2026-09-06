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
            // Catastrophic failure to access local database.
            // Do NOT fall back to an in-memory store as this causes silent data loss.
            fatalError("Failed to initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
}
