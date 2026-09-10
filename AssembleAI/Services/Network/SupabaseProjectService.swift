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
    
    @MainActor
    init() {
        self.supabaseManager = SupabaseManager.shared
    }
    
    enum ServiceError: Error {
        case invalidURL
        case networkFailure(String)
        case decodingError(String)
        case serverError(Int)
    }
    
    // MARK: - Admin Status
    
    /// Checks whether the currently authenticated user has administrator / app owner privileges.
    func checkIsAdmin() async -> Bool {
        guard let userId = await supabaseManager.currentUserId else { return false }
        guard var components = URLComponents(string: "\(AppConfig.supabaseUrl)/rest/v1/profiles") else { return false }
        components.queryItems = [
            URLQueryItem(name: "select", value: "is_admin"),
            URLQueryItem(name: "id", value: "eq.\(userId)"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components.url else { return false }
        let request = await supabaseManager.prepareRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return false }
            struct AdminCheck: Decodable {
                let isAdmin: Bool?
                enum CodingKeys: String, CodingKey { case isAdmin = "is_admin" }
            }
            let records = try JSONDecoder().decode([AdminCheck].self, from: data)
            return records.first?.isAdmin ?? false
        } catch {
            return false
        }
    }
    
    // MARK: - Projects
    
    /// Fetches all public and user-accessible projects from Supabase.
    func fetchProjects() async throws -> [Project] {
        guard var components = URLComponents(string: "\(AppConfig.supabaseUrl)/rest/v1/projects") else {
            throw ServiceError.invalidURL
        }
        
        // Supabase RLS automatically filters: is_public = true OR owner_id = auth.uid()
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
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
    
    // MARK: - Components
    
    /// Fetches all components for a project from Supabase.
    func fetchComponents(projectId: UUID) async throws -> [Component] {
        guard var components = URLComponents(string: "\(AppConfig.supabaseUrl)/rest/v1/components") else { throw ServiceError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "project_id", value: "eq.\(projectId.uuidString)"),
            URLQueryItem(name: "order", value: "created_at.asc")
        ]
        guard let url = components.url else { throw ServiceError.invalidURL }
        
        let request = await supabaseManager.prepareRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ServiceError.networkFailure("Invalid response") }
        guard httpResponse.statusCode == 200 else { throw ServiceError.serverError(httpResponse.statusCode) }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Component].self, from: data)
    }
    
    /// Upserts a Component record into Supabase PostgreSQL.
    func saveComponent(_ component: Component) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/components") else { throw ServiceError.invalidURL }
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(component)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Full Assembly Projects (Relational Assembly)
    
    /// Fetches full `AssemblyProject` domain models including their child steps and components from Supabase.
    func fetchFullAssemblyProjects() async throws -> [AssemblyProject] {
        let baseProjects = try await fetchProjects()
        var fullProjects: [AssemblyProject] = []
        let bundledMap = Dictionary(BundledProjectRepository.bundledProjects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        
        for base in baseProjects {
            let steps = (try? await fetchAssemblySteps(projectId: base.id)) ?? []
            let rawComponents = (try? await fetchComponents(projectId: base.id)) ?? []
            let bundled = bundledMap[base.id] ?? BundledProjectRepository.bundledProjects.first(where: {
                $0.title.localizedCaseInsensitiveCompare(base.title) == .orderedSame
            })
            
            let domainSteps = steps.map { step in
                let matchingBundledStep = bundled?.steps.first(where: { $0.stepOrder == step.stepOrder })
                return ProjectStepSummary(
                    id: step.id,
                    stepOrder: step.stepOrder,
                    title: step.title,
                    instruction: step.instruction,
                    expectedDurationMinutes: matchingBundledStep?.expectedDurationMinutes ?? 2,
                    visualContract: step.visualContract ?? matchingBundledStep?.visualContract,
                    commonMistakes: matchingBundledStep?.commonMistakes ?? []
                )
            }
            
            let domainComponents = rawComponents.map { comp in
                let matchingBundledComp = bundled?.components.first(where: { $0.name.lowercased() == comp.name.lowercased() })
                return ComponentRequirement(
                    id: comp.id,
                    name: comp.name,
                    detail: comp.description.isEmpty ? (matchingBundledComp?.detail ?? comp.name) : comp.description,
                    isRequired: matchingBundledComp?.isRequired ?? true,
                    partId: matchingBundledComp?.partId ?? "part_\(comp.name.lowercased().replacingOccurrences(of: " ", with: "_"))",
                    componentType: matchingBundledComp?.componentType,
                    physicalAttributes: matchingBundledComp?.physicalAttributes,
                    quantity: matchingBundledComp?.quantity ?? 1
                )
            }
            
            let rawSteps = domainSteps.isEmpty ? (bundled?.steps ?? []) : domainSteps
            // Strict step deduplication by stepOrder to prevent duplicate or merged steps
            let resolvedSteps = Dictionary(rawSteps.map { ($0.stepOrder, $0) }, uniquingKeysWith: { first, _ in first })
                .values
                .sorted { $0.stepOrder < $1.stepOrder }
            let resolvedComponents = domainComponents.isEmpty ? (bundled?.components ?? []) : domainComponents
            
            let project = AssemblyProject(
                id: base.id,
                title: base.title,
                subtitle: base.description,
                category: base.category ?? (bundled?.category ?? "General Assembly"),
                difficulty: Difficulty(rawValue: base.difficulty) ?? .beginner,
                estimatedMinutes: base.estimatedMinutes,
                totalSteps: resolvedSteps.count,
                completedSteps: 0,
                imageName: base.thumbnailPath ?? (bundled?.imageName ?? "wrench.and.screwdriver.fill"),
                isActive: false,
                nextAction: bundled?.nextAction,
                description: base.description,
                components: resolvedComponents,
                steps: resolvedSteps
            )
            fullProjects.append(project)
        }
        
        return fullProjects
    }
    
    /// Saves a full `AssemblyProject` into Supabase by saving the project, its components, and its steps.
    func saveFullAssemblyProject(_ project: AssemblyProject) async throws {
        let ownerId = (await supabaseManager.currentUserId).flatMap { UUID(uuidString: $0) } ?? project.id
        let baseProject = Project(
            id: project.id,
            ownerId: ownerId,
            title: project.title,
            description: project.description,
            difficulty: project.difficulty.rawValue,
            estimatedMinutes: project.estimatedMinutes,
            thumbnailPath: project.imageName,
            createdAt: Date(),
            updatedAt: Date(),
            syncState: .synced
        )
        
        try await saveProject(baseProject)
        
        // Save components
        for comp in project.components {
            let componentRecord = Component(
                id: comp.id,
                projectId: project.id,
                name: comp.name,
                type: comp.componentType?.rawValue ?? "hardware",
                description: comp.detail,
                metadata: "{}"
            )
            try await saveComponent(componentRecord)
        }
        
        // Save steps
        for step in project.steps {
            let stepRecord = AssemblyStep(
                id: step.id,
                projectId: project.id,
                stepOrder: step.stepOrder,
                title: step.title,
                instruction: step.instruction,
                visualContract: step.visualContract
            )
            try await saveAssemblyStep(stepRecord)
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
