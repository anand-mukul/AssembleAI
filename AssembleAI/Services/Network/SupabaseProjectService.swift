//
//  SupabaseProjectService.swift
//  AssembleAI
//

import Foundation

/// Background service interacting with Supabase REST PostgREST database endpoint for `Project`, `AssemblyStep`, `Component`, and `AssemblySession` records.
actor SupabaseProjectService {
    private let supabaseManager: SupabaseManager
    
    @MainActor
    init(supabaseManager: SupabaseManager) {
        self.supabaseManager = supabaseManager
    }
    
    // MARK: - Projects
    
    /// Fetches all projects for the authenticated user from Supabase.
    func fetchProjects() async throws -> [Project] {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/projects?select=*&order=updated_at.desc") else {
            return []
        }
        
        let request = await supabaseManager.prepareRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([Project].self, from: data)
        } catch {
            return []
        }
    }
    
    /// Upserts a Project record into Supabase PostgreSQL.
    func saveProject(_ project: Project) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/projects") else { return }
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(project)
        
        _ = try? await URLSession.shared.data(for: request)
    }
    
    /// Deletes a Project record from Supabase PostgreSQL.
    func deleteProject(id: UUID) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/projects?id=eq.\(id.uuidString)") else { return }
        
        let request = await supabaseManager.prepareRequest(url: url, method: "DELETE")
        _ = try? await URLSession.shared.data(for: request)
    }
    
    // MARK: - Assembly Steps
    
    /// Fetches assembly steps for a project from Supabase.
    func fetchAssemblySteps(projectId: UUID) async throws -> [AssemblyStep] {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/assembly_steps?project_id=eq.\(projectId.uuidString)&order=step_order.asc") else {
            return []
        }
        
        let request = await supabaseManager.prepareRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([AssemblyStep].self, from: data)
        } catch {
            return []
        }
    }
    
    /// Upserts an AssemblyStep record into Supabase PostgreSQL.
    func saveAssemblyStep(_ step: AssemblyStep) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/assembly_steps") else { return }
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(step)
        
        _ = try? await URLSession.shared.data(for: request)
    }
    
    // MARK: - Assembly Sessions
    
    /// Fetches assembly sessions from Supabase.
    func fetchSessions() async throws -> [AssemblySession] {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/assembly_sessions?select=*&order=started_at.desc") else {
            return []
        }
        
        let request = await supabaseManager.prepareRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([AssemblySession].self, from: data)
        } catch {
            return []
        }
    }
    
    /// Upserts an AssemblySession record into Supabase PostgreSQL.
    func saveSession(_ session: AssemblySession) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/assembly_sessions") else { return }
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(session)
        
        _ = try? await URLSession.shared.data(for: request)
    }
}
