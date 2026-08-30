//
//  PersistenceController.swift
//  AssembleAI
//

import Foundation
import SwiftData

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
            print("⚠️ SwiftData on-disk store initialization failed: \(error). Falling back to in-memory store.")
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Failed to initialize fallback SwiftData ModelContainer: \(error)")
            }
        }
    }
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
}
