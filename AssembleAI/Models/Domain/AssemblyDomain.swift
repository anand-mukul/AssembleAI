//
//  AssemblyDomain.swift
//  AssembleAI
//

import Foundation
import SwiftUI

/// The physical domain category of an assembly project.
/// Drives which verification strategies and visual contract schemas are applicable.
nonisolated enum AssemblyDomain: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    /// Electronics breadboard assembly (Arduino, Raspberry Pi, maker kits).
    /// Uses pin-coordinate visual contracts, color-band decoding, and rail polarity checks.
    case electronics = "Electronics"
    
    /// Physical/mechanical assembly (furniture, shelving, structural kits).
    /// Uses spatial orientation contracts, fastener counts, and alignment tolerances.
    case physical = "Physical"
    
    /// Mixed-domain projects combining electronics and mechanical assembly.
    case hybrid = "Hybrid"
    
    /// Display-friendly label for UI presentation.
    var displayName: String { rawValue }
    
    /// SF Symbol name representing this domain in navigation and cards.
    var iconName: String {
        switch self {
        case .electronics: return "cpu"
        case .physical: return "wrench.and.screwdriver"
        case .hybrid: return "square.stack.3d.up"
        }
    }
    
    /// Semantic tint color for Apple HIG icon squircle badges.
    @MainActor
    var badgeColor: Color {
        switch self {
        case .electronics: return AppColors.badgeBlue
        case .physical: return AppColors.badgeOrange
        case .hybrid: return AppColors.badgePurple
        }
    }
}
