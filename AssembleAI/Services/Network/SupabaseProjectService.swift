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
    
    enum ServiceError: Error {
        case invalidURL
        case networkFailure(String)
        case decodingError(String)
        case serverError(Int)
    }
    
    // MARK: - Projects
    
    /// Fetches all projects for the authenticated user from Supabase.
    func fetchProjects() async throws -> [Project] {
        guard let ownerId = await supabaseManager.currentUserId else {
            return [] // Not authenticated
        }
        guard var components = URLComponents(string: "\(AppConfig.supabaseUrl)/rest/v1/projects") else {
            throw ServiceError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "owner_id", value: "eq.\(ownerId)"),
            URLQueryItem(name: "order", value: "updated_at.desc")
        ]
        
        guard let url = components.url else { throw ServiceError.invalidURL }
        let request = await supabaseManager.prepareRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw ServiceError.networkFailure("Invalid response") }
            guard httpResponse.statusCode == 200 else { throw ServiceError.serverError(httpResponse.statusCode) }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([Project].self, from: data)
        } catch let error as DecodingError {
            throw ServiceError.decodingError(error.localizedDescription)
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.networkFailure(error.localizedDescription)
        }
    }
    
    /// Upserts a Project record into Supabase PostgreSQL.
    func saveProject(_ project: Project) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/projects") else { throw ServiceError.invalidURL }
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(project)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Deletes a Project record from Supabase PostgreSQL.
    func deleteProject(id: UUID) async throws {
        guard var components = URLComponents(string: "\(AppConfig.supabaseUrl)/rest/v1/projects") else { throw ServiceError.invalidURL }
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        guard let url = components.url else { throw ServiceError.invalidURL }
        
        let request = await supabaseManager.prepareRequest(url: url, method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Assembly Steps
    
    /// Fetches assembly steps for a project from Supabase.
    func fetchAssemblySteps(projectId: UUID) async throws -> [AssemblyStep] {
        guard var components = URLComponents(string: "\(AppConfig.supabaseUrl)/rest/v1/assembly_steps") else { throw ServiceError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "project_id", value: "eq.\(projectId.uuidString)"),
            URLQueryItem(name: "order", value: "step_order.asc")
        ]
        guard let url = components.url else { throw ServiceError.invalidURL }
        
        let request = await supabaseManager.prepareRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ServiceError.networkFailure("Invalid response") }
        guard httpResponse.statusCode == 200 else { throw ServiceError.serverError(httpResponse.statusCode) }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([AssemblyStep].self, from: data)
    }
    
    /// Upserts an AssemblyStep record into Supabase PostgreSQL.
    func saveAssemblyStep(_ step: AssemblyStep) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/assembly_steps") else { throw ServiceError.invalidURL }
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(step)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Assembly Sessions
    
    /// Fetches assembly sessions from Supabase.
    func fetchSessions() async throws -> [AssemblySession] {
        guard let userId = await supabaseManager.currentUserId else {
            return [] // Not authenticated
        }
        guard var components = URLComponents(string: "\(AppConfig.supabaseUrl)/rest/v1/assembly_sessions") else { throw ServiceError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "started_at.desc")
        ]
        guard let url = components.url else { throw ServiceError.invalidURL }
        
        let request = await supabaseManager.prepareRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ServiceError.networkFailure("Invalid response") }
        guard httpResponse.statusCode == 200 else { throw ServiceError.serverError(httpResponse.statusCode) }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([AssemblySession].self, from: data)
    }
    
    /// Upserts an AssemblySession record into Supabase PostgreSQL.
    func saveSession(_ session: AssemblySession) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/assembly_sessions") else { throw ServiceError.invalidURL }
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(session)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
}
