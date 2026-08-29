//
//  GuidanceOverlay.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Visual style classification for camera guidance overlays.
nonisolated enum GuidanceStyle: String, Codable, Hashable, Equatable, Sendable {
    case target
    case move
    case warning
    case success
}

/// Structured visual guidance specification rendered over the live camera preview.
nonisolated struct GuidanceOverlay: Identifiable, Hashable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let message: String
    let targetRegion: CGRect?
    let sourceRegion: CGRect?
    let destinationRegion: CGRect?
    let style: GuidanceStyle
    
    init(
        id: UUID = UUID(),
        title: String,
        message: String,
        targetRegion: CGRect? = nil,
        sourceRegion: CGRect? = nil,
        destinationRegion: CGRect? = nil,
        style: GuidanceStyle
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.targetRegion = targetRegion
        self.sourceRegion = sourceRegion
        self.destinationRegion = destinationRegion
        self.style = style
    }
    
    var hasCoordinates: Bool {
        targetRegion != nil || (sourceRegion != nil && destinationRegion != nil)
    }
}
