//
//  ProjectPackageValidator.swift
//  AssembleAI
//

import Foundation

/// Validates the structural and semantic integrity of an `AssemblyProject` package.
///
/// Validation rules:
/// 1. Project must have a non-empty title.
/// 2. Project must have at least one step defined.
/// 3. Step orders must be sequential with no duplicates.
/// 4. If visual contracts reference component part IDs, those IDs must exist in the project BOM.
/// 5. Schema version must be a recognized format.
struct ProjectPackageValidator {
    
    /// Validates a project package, throwing on the first structural violation.
    static func validate(_ project: AssemblyProject) throws {
        // Rule 1: Non-empty title
        guard !project.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ProjectPackageError.invalidSchema("Project title cannot be empty.")
        }
        
        // Rule 2: At least one step
        guard !project.steps.isEmpty else {
            throw ProjectPackageError.emptySteps(project.title)
        }
        
        // Rule 3: No duplicate step orders
        let stepOrders = project.steps.map(\.stepOrder)
        let uniqueOrders = Set(stepOrders)
        if uniqueOrders.count != stepOrders.count {
            let duplicates = stepOrders.filter { order in
                stepOrders.filter { $0 == order }.count > 1
            }
            throw ProjectPackageError.duplicateStepOrder(project.title, Array(Set(duplicates)).sorted())
        }
        
        // Rule 4: Visual contract BOM references
        let bomPartIds = Set(project.components.compactMap(\.partId))
        for step in project.steps {
            guard let contract = step.visualContract else { continue }
            
            for requiredId in contract.requiredComponentIds {
                // Skip validation if BOM has no part IDs (legacy projects)
                guard !bomPartIds.isEmpty else { break }
                
                if !bomPartIds.contains(requiredId) {
                    throw ProjectPackageError.missingBOMReference(step.title, requiredId)
                }
            }
        }
        
        // Rule 5: Schema version format (semantic versioning)
        let versionPattern = #"^\d+\.\d+\.\d+$"#
        let versionRange = project.schemaVersion.range(of: versionPattern, options: .regularExpression)
        if versionRange == nil {
            throw ProjectPackageError.invalidSchema(
                "Schema version '\(project.schemaVersion)' does not follow semantic versioning (e.g., '1.0.0')."
            )
        }
    }
    
    /// Performs a non-throwing validation, returning all discovered issues.
    static func diagnose(_ project: AssemblyProject) -> [String] {
        var issues: [String] = []
        
        if project.title.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append("Project title is empty.")
        }
        
        if project.steps.isEmpty {
            issues.append("Project has no assembly steps.")
        }
        
        let stepOrders = project.steps.map(\.stepOrder)
        let uniqueOrders = Set(stepOrders)
        if uniqueOrders.count != stepOrders.count {
            issues.append("Duplicate step orders detected.")
        }
        
        // Check step order continuity
        let sorted = stepOrders.sorted()
        if let first = sorted.first, first != 1 {
            issues.append("Step ordering should start at 1, but starts at \(first).")
        }
        
        for (i, order) in sorted.enumerated() {
            if i > 0 && order != sorted[i - 1] + 1 {
                issues.append("Gap in step ordering between step \(sorted[i - 1]) and step \(order).")
            }
        }
        
        // Validate totalSteps consistency
        if project.totalSteps != project.steps.count {
            issues.append("totalSteps (\(project.totalSteps)) does not match actual steps count (\(project.steps.count)).")
        }
        
        // Validate BOM cross-references
        let bomPartIds = Set(project.components.compactMap(\.partId))
        if !bomPartIds.isEmpty {
            for step in project.steps {
                guard let contract = step.visualContract else { continue }
                for requiredId in contract.requiredComponentIds {
                    if !bomPartIds.contains(requiredId) {
                        issues.append("Step '\(step.title)' references undefined part '\(requiredId)'.")
                    }
                }
            }
        }
        
        return issues
    }
}
