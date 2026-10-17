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
    
    // MARK: - Safe Endpoint Construction
    
    private func endpointComponents(path: String) throws -> URLComponents {
        guard AppConfig.isSupabaseConfigured else {
            throw ServiceError.invalidURL
        }
        let trimmedBase = AppConfig.supabaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        guard let components = URLComponents(string: "\(trimmedBase)\(cleanPath)"),
              components.scheme == "https" else {
            throw ServiceError.invalidURL
        }
        return components
    }
    
    private func endpointURL(path: String) throws -> URL {
        guard AppConfig.isSupabaseConfigured else {
            throw ServiceError.invalidURL
        }
        let trimmedBase = AppConfig.supabaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: "\(trimmedBase)\(cleanPath)"),
              url.scheme == "https" else {
            throw ServiceError.invalidURL
        }
        return url
    }
    
    // MARK: - Admin Status
    
    /// Checks whether the currently authenticated user has administrator / app owner privileges.
    func checkIsAdmin() async -> Bool {
        guard AppConfig.isSupabaseConfigured else { return false }
        guard let userId = await supabaseManager.currentUserId else { return false }
        guard var components = try? endpointComponents(path: "/rest/v1/profiles") else { return false }
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
        var components = try endpointComponents(path: "/rest/v1/projects")
        
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
            let dtos = try decoder.decode([ProjectDTO].self, from: data)
            return dtos.map { $0.toDomain() }
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
        let url = try endpointURL(path: "/rest/v1/projects")
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let dto = ProjectDTO(from: project)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(dto)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Deletes a Project record from Supabase PostgreSQL.
    func deleteProject(id: UUID) async throws {
        var components = try endpointComponents(path: "/rest/v1/projects")
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
        var components = try endpointComponents(path: "/rest/v1/assembly_steps")
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
        let dtos = try decoder.decode([AssemblyStepDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }
    
    /// Upserts an AssemblyStep record into Supabase PostgreSQL.
    func saveAssemblyStep(_ step: AssemblyStep) async throws {
        let url = try endpointURL(path: "/rest/v1/assembly_steps")
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let dto = AssemblyStepDTO(from: step)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(dto)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Components
    
    /// Fetches all components for a project from Supabase.
    func fetchComponents(projectId: UUID) async throws -> [Component] {
        var components = try endpointComponents(path: "/rest/v1/components")
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
        let dtos = try decoder.decode([ComponentDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }
    
    /// Upserts a Component record into Supabase PostgreSQL.
    func saveComponent(_ component: Component) async throws {
        let url = try endpointURL(path: "/rest/v1/components")
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let dto = ComponentDTO(from: component)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(dto)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Full Assembly Projects (Relational Assembly)
    
    /// Fetches full `AssemblyProject` domain models including their child steps and components from Supabase.
    func fetchFullAssemblyProjects() async throws -> [AssemblyProject] {
        guard AppConfig.isSupabaseConfigured else {
            return BundledProjectRepository.bundledProjects
        }
        let baseProjects = try await fetchProjects()
        var fullProjects: [AssemblyProject] = []
        let bundledProjects = BundledProjectRepository.bundledProjects + ProjectPackageLoader.loadAllFromDocuments()
        let bundledMap = Dictionary(bundledProjects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        
        for base in baseProjects {
            let steps = (try? await fetchAssemblySteps(projectId: base.id)) ?? []
            let rawComponents = (try? await fetchComponents(projectId: base.id)) ?? []
            let bundled = bundledMap[base.id] ?? bundledProjects.first(where: {
                $0.title.localizedCaseInsensitiveCompare(base.title) == .orderedSame ||
                base.title.localizedCaseInsensitiveContains($0.title) ||
                $0.title.localizedCaseInsensitiveContains(base.title)
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
                    commonMistakes: step.commonMistakes.isEmpty ? (matchingBundledStep?.commonMistakes ?? []) : step.commonMistakes
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
        let ownerId = (await supabaseManager.currentUserId).flatMap { UUID(uuidString: $0) }
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
                visualContract: step.visualContract,
                commonMistakes: step.commonMistakes
            )
            try await saveAssemblyStep(stepRecord)
        }
    }
    
    // MARK: - Assembly Sessions
    
    /// Fetches assembly sessions from Supabase.
    func fetchSessions(since: Date? = nil) async throws -> [AssemblySession] {
        guard AppConfig.isSupabaseConfigured else { return [] }
        guard let userId = await supabaseManager.currentUserId else {
            return [] // Not authenticated
        }
        var components = try endpointComponents(path: "/rest/v1/assembly_sessions")
        var queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "updated_at.desc")
        ]
        if let sinceDate = since {
            let iso = ISO8601DateFormatter().string(from: sinceDate)
            queryItems.append(URLQueryItem(name: "updated_at", value: "gte.\(iso)"))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw ServiceError.invalidURL }
        
        let request = await supabaseManager.prepareRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ServiceError.networkFailure("Invalid response") }
        guard httpResponse.statusCode == 200 else { throw ServiceError.serverError(httpResponse.statusCode) }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dtos = try decoder.decode([AssemblySessionDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }
    
    /// Upserts an AssemblySession record into Supabase PostgreSQL.
    func saveSession(_ session: AssemblySession) async throws {
        let url = try endpointURL(path: "/rest/v1/assembly_sessions")
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        var adjustedSession = session
        // If session userId is missing and user is logged in, attach current user ID
        if adjustedSession.userId == nil, let currentUid = await supabaseManager.currentUserId, let parsedUid = UUID(uuidString: currentUid) {
            adjustedSession.userId = parsedUid
        }
        
        let dto = AssemblySessionDTO(from: adjustedSession)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(dto)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Batch upserts assembly session records into Supabase PostgreSQL.
    func saveSessions(_ sessions: [AssemblySession]) async throws -> [AssemblySession] {
        guard !sessions.isEmpty else { return [] }
        let url = try endpointURL(path: "/rest/v1/assembly_sessions")
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        
        let currentUid = await supabaseManager.currentUserId.flatMap { UUID(uuidString: $0) }
        let dtos = sessions.map { session -> AssemblySessionDTO in
            var adj = session
            if adj.userId == nil, let uid = currentUid {
                adj.userId = uid
            }
            return AssemblySessionDTO(from: adj)
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(dtos)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ServiceError.serverError(code)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let returnedDTOs = try? decoder.decode([AssemblySessionDTO].self, from: data), !returnedDTOs.isEmpty {
            return returnedDTOs.map { $0.toDomain() }
        }
        return sessions
    }
    
    /// Deletes an assembly session record from Supabase PostgreSQL.
    func deleteSession(id: UUID) async throws {
        var components = try endpointComponents(path: "/rest/v1/assembly_sessions")
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        guard let url = components.url else { throw ServiceError.invalidURL }
        
        let request = await supabaseManager.prepareRequest(url: url, method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - User Profiles
    
    /// Fetches the user profile from Supabase PostgREST `public.profiles`.
    func fetchProfile(userId: String) async throws -> ProfileDTO? {
        var components = try endpointComponents(path: "/rest/v1/profiles")
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(userId)"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components.url else { throw ServiceError.invalidURL }
        
        let request = await supabaseManager.prepareRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profiles = try decoder.decode([ProfileDTO].self, from: data)
        return profiles.first
    }
    
    /// Updates or upserts a user profile record in Supabase PostgREST `public.profiles`.
    func updateProfile(userId: String, profile: ProfileDTO) async throws {
        var components = try endpointComponents(path: "/rest/v1/profiles")
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(userId)")]
        guard let url = components.url else { throw ServiceError.invalidURL }
        
        var request = await supabaseManager.prepareRequest(url: url, method: "PATCH")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(profile)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Attempts (Step-level Verification Telemetry)
    
    /// Records an assembly verification attempt in Supabase PostgREST `public.attempts`.
    func saveAttempt(_ attempt: Attempt) async throws {
        let url = try endpointURL(path: "/rest/v1/attempts")
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let dto = AttemptDTO(domain: attempt)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(dto)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Fetches all verification attempts for an assembly session.
    func fetchAttempts(sessionId: UUID) async throws -> [Attempt] {
        var components = try endpointComponents(path: "/rest/v1/attempts")
        components.queryItems = [
            URLQueryItem(name: "session_id", value: "eq.\(sessionId.uuidString.lowercased())"),
            URLQueryItem(name: "order", value: "attempt_number.asc")
        ]
        guard let url = components.url else { throw ServiceError.invalidURL }
        
        let request = await supabaseManager.prepareRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dtos = try decoder.decode([AttemptDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }
    
    // MARK: - Research Telemetry Sessions
    
    /// Inserts an empirical evaluation research session payload into Supabase PostgREST `public.research_sessions`.
    func saveResearchSession(_ session: ResearchSessionDTO) async throws {
        let url = try endpointURL(path: "/rest/v1/research_sessions")
        
        var request = await supabaseManager.prepareRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(session)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
}

