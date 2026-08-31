//
//  ProjectPackageLoader.swift
//  AssembleAI
//

import Foundation

/// Errors thrown during project package loading and validation.
enum ProjectPackageError: LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String, Error)
    case invalidSchema(String)
    case emptySteps(String)
    case duplicateStepOrder(String, [Int])
    case missingBOMReference(String, String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Project package file not found: \(path)"
        case .decodingFailed(let path, let error):
            return "Failed to decode project package at \(path): \(error.localizedDescription)"
        case .invalidSchema(let reason):
            return "Invalid project schema: \(reason)"
        case .emptySteps(let projectTitle):
            return "Project '\(projectTitle)' has no assembly steps defined."
        case .duplicateStepOrder(let projectTitle, let orders):
            return "Project '\(projectTitle)' has duplicate step orders: \(orders)"
        case .missingBOMReference(let stepTitle, let partId):
            return "Step '\(stepTitle)' references part '\(partId)' not found in BOM."
        }
    }
}

/// Loads and decodes `AssemblyProject` instances from JSON package files.
///
/// JSON packages are the portable distribution format for AssembleAI projects.
/// They are self-contained files containing the project manifest, bill of materials,
/// step sequence with visual contracts, and common mistake remediation graphs.
struct ProjectPackageLoader {
    
    /// Shared JSON decoder configured for AssembleAI project packages.
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    /// Shared JSON encoder for serializing project packages.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    
    // MARK: - Loading from Bundle
    
    /// Loads a project from a JSON file in the main application bundle.
    /// - Parameter filename: The JSON file name without extension (e.g., "led_circuit").
    /// - Returns: A decoded and validated `AssemblyProject`.
    static func loadFromBundle(filename: String) throws -> AssemblyProject {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw ProjectPackageError.fileNotFound("Bundle:\(filename).json")
        }
        return try loadFromURL(url)
    }
    
    /// Loads all project JSON files from a specific bundle directory.
    /// - Parameter directory: The bundle subdirectory containing project JSON files (e.g., "Projects").
    /// - Returns: Array of decoded projects, skipping any that fail validation.
    static func loadAllFromBundle(directory: String = "Projects") -> [AssemblyProject] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: directory) else {
            return []
        }
        
        return urls.compactMap { url in
            try? loadFromURL(url)
        }
    }
    
    // MARK: - Loading from Documents Directory
    
    /// Loads a project from the app's documents directory.
    /// - Parameter filename: The JSON file name (with or without extension).
    /// - Returns: A decoded and validated `AssemblyProject`.
    static func loadFromDocuments(filename: String) throws -> AssemblyProject {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let normalizedFilename = filename.hasSuffix(".json") ? filename : "\(filename).json"
        let fileURL = documentsURL.appendingPathComponent("Projects").appendingPathComponent(normalizedFilename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ProjectPackageError.fileNotFound(fileURL.path)
        }
        
        return try loadFromURL(fileURL)
    }
    
    /// Loads all project JSON files from the documents/Projects directory.
    static func loadAllFromDocuments() -> [AssemblyProject] {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let projectsDir = documentsURL.appendingPathComponent("Projects")
        
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        
        return contents
            .filter { $0.pathExtension == "json" }
            .compactMap { try? loadFromURL($0) }
    }
    
    // MARK: - Loading from URL
    
    /// Loads and validates a project from a specific file URL.
    static func loadFromURL(_ url: URL) throws -> AssemblyProject {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ProjectPackageError.fileNotFound(url.path)
        }
        
        return try loadFromData(data, source: url.lastPathComponent)
    }
    
    // MARK: - Loading from Raw Data
    
    /// Decodes and validates a project from raw JSON data.
    /// - Parameters:
    ///   - data: Raw JSON bytes.
    ///   - source: A human-readable source label for error messages.
    /// - Returns: A decoded and validated `AssemblyProject`.
    static func loadFromData(_ data: Data, source: String = "data") throws -> AssemblyProject {
        let project: AssemblyProject
        do {
            project = try decoder.decode(AssemblyProject.self, from: data)
        } catch {
            throw ProjectPackageError.decodingFailed(source, error)
        }
        
        try ProjectPackageValidator.validate(project)
        return project
    }
    
    // MARK: - Serialization
    
    /// Encodes a project to JSON data for export or local storage.
    static func encode(_ project: AssemblyProject) throws -> Data {
        try encoder.encode(project)
    }
    
    /// Saves a project as a JSON file in the documents/Projects directory.
    /// - Returns: The file URL where the project was saved.
    @discardableResult
    static func saveToDocuments(_ project: AssemblyProject, filename: String? = nil) throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let projectsDir = documentsURL.appendingPathComponent("Projects")
        
        // Ensure directory exists
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        
        let name = filename ?? project.id.uuidString
        let normalizedName = name.hasSuffix(".json") ? name : "\(name).json"
        let fileURL = projectsDir.appendingPathComponent(normalizedName)
        
        let data = try encode(project)
        try data.write(to: fileURL, options: .atomic)
        
        return fileURL
    }
}
