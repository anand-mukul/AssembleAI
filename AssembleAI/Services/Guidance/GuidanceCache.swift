//
//  GuidanceCache.swift
//  AssembleAI
//

import Foundation

/// In-memory cache for model-generated guidance responses to prevent redundant LLM invocations.
actor GuidanceCache {
    static let shared = GuidanceCache()
    
    private var cache: [String: GuidanceResponse] = [:]
    
    /// Retrieves a cached response if present.
    func get(key: String) -> GuidanceResponse? {
        return cache[key]
    }
    
    /// Stores a response in the in-memory cache.
    func set(key: String, response: GuidanceResponse) {
        cache[key] = response
    }
    
    /// Clears all cached responses.
    func clear() {
        cache.removeAll()
    }
    
    /// Generates a composite cache key.
    static func makeKey(stepID: UUID, issueType: StateIssueType, level: GuidanceLevel) -> String {
        "\(stepID.uuidString)_\(issueType.rawValue)_\(level.rawValue)"
    }
}
