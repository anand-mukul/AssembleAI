//
//  WorkspaceCalibrationService.swift
//  AssembleAI
//

import Foundation
import CoreGraphics
import CoreVideo
import Vision
import UIKit

/// Quality of ambient illumination on the assembly workbench.
nonisolated enum WorkspaceLightingQuality: String, Sendable, Equatable, Codable {
    case optimal = "Optimal"
    case dim = "Low Light"
    case glare = "High Glare"
    
    var displayName: String {
        switch self {
        case .optimal: return "optimal"
        case .dim: return "a bit dim"
        case .glare: return "prone to glare"
        }
    }
}

/// Comprehensive physical workspace map constructed by AssembleAI prior to active guidance.
nonisolated struct WorkspaceMap: Sendable, Equatable {
    let domain: AssemblyDomain
    let breadboardDetected: Bool
    let breadboardVariant: BreadboardGeometry.Variant
    let breadboardCalibration: BreadboardCalibration?
    let existingComponents: [ObservedComponent]
    let lightingQuality: WorkspaceLightingQuality
    let estimatedWorkingArea: CGRect
    let timestamp: Date
    
    init(
        domain: AssemblyDomain = .electronics,
        breadboardDetected: Bool,
        breadboardVariant: BreadboardGeometry.Variant = .halfSize,
        breadboardCalibration: BreadboardCalibration? = nil,
        existingComponents: [ObservedComponent] = [],
        lightingQuality: WorkspaceLightingQuality = .optimal,
        estimatedWorkingArea: CGRect = CGRect(x: 0.15, y: 0.15, width: 0.70, height: 0.70),
        timestamp: Date = Date()
    ) {
        self.domain = domain
        self.breadboardDetected = breadboardDetected
        self.breadboardVariant = breadboardVariant
        self.breadboardCalibration = breadboardCalibration
        self.existingComponents = existingComponents
        self.lightingQuality = lightingQuality
        self.estimatedWorkingArea = estimatedWorkingArea
        self.timestamp = timestamp
    }
    
    var summaryAnnouncement: String {
        let compCount = existingComponents.count
        let compDesc = compCount == 0 ? "Workspace is clear and ready." : "I cataloged \(compCount) component\(compCount == 1 ? "" : "s") on the bench."
        
        switch domain {
        case .electronics:
            let boardName = breadboardVariant == .fullSize ? "full-size 830-point breadboard" : "half-size 400-point breadboard"
            return "I've mapped your \(boardName). Lighting is \(lightingQuality.displayName). \(compDesc)"
        case .physical:
            return "I've mapped your assembly workbench. Lighting is \(lightingQuality.displayName). \(compDesc)"
        case .hybrid:
            return "I've mapped your integrated workspace. Lighting is \(lightingQuality.displayName). \(compDesc)"
        }
    }
}

/// Protocol for calibrating and mapping the physical workbench before step execution.
protocol WorkspaceCalibrationServicing: Sendable {
    func calibrateWorkspace(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        domain: AssemblyDomain
    ) async -> WorkspaceMap
}

extension WorkspaceCalibrationServicing {
    func calibrateWorkspace(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) async -> WorkspaceMap {
        await calibrateWorkspace(from: pixelBuffer, orientation: orientation, domain: .electronics)
    }
}

/// Production workspace calibration service mapping breadboard pose, components, and lighting.
final class WorkspaceCalibrationService: WorkspaceCalibrationServicing, @unchecked Sendable {
    
    private let homographyService: BreadboardHomographyService
    private let spatialDetector: ComponentSpatialDetector
    private let visionService: VisionService
    
    init(
        homographyService: BreadboardHomographyService = BreadboardHomographyService(),
        spatialDetector: ComponentSpatialDetector? = nil,
        visionService: VisionService? = nil
    ) {
        self.homographyService = homographyService
        self.spatialDetector = spatialDetector ?? ComponentSpatialDetector(homographyService: homographyService)
        self.visionService = visionService ?? VisionService()
    }
    
    func calibrateWorkspace(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up,
        domain: AssemblyDomain = .electronics
    ) async -> WorkspaceMap {
        // 1. Detect domain-specific physical anchor (breadboard for electronics, planar surface for physical)
        let calibration: BreadboardCalibration?
        let detected: Bool
        let variant: BreadboardGeometry.Variant
        
        if domain == .electronics {
            calibration = await homographyService.detectCalibration(in: pixelBuffer, orientation: orientation)
            detected = calibration != nil
            variant = calibration?.geometry.variant ?? .halfSize
        } else {
            // Physical / Hybrid domains: no breadboard constraint
            calibration = nil
            detected = false
            variant = .halfSize
        }
        
        // 2. Assess lighting quality from frame luminance
        let lighting = estimateLightingQuality(in: pixelBuffer)
        
        // 3. Run Vision pass to catalog pre-existing components or hardware parts
        var catalogedComponents: [ObservedComponent] = []
        var detectedWorkingBounds: CGRect? = nil
        
        if let observation = try? await visionService.analyze(frame: pixelBuffer, orientation: orientation) {
            // For electronics, use calibrated breadboard or default centered; for physical domains, do not force breadboard homography (H-3)
            let activeCalib = (domain == .electronics) ? (calibration ?? BreadboardCalibration.defaultCentered()) : calibration
            let spatialComps = spatialDetector.detectComponents(in: observation, calibration: activeCalib)
            catalogedComponents = spatialComps.map { comp in
                ObservedComponent(
                    id: comp.id,
                    identifier: comp.partId,
                    name: comp.name,
                    confidence: comp.confidence,
                    boundingBox: comp.cameraBoundingBox
                )
            }
            
            // For physical/hybrid domains, derive working bounds from largest detected object/region
            if domain != .electronics, !observation.regions.isEmpty {
                var unionRect = observation.regions[0].boundingBox
                for r in observation.regions.dropFirst() {
                    unionRect = unionRect.union(r.boundingBox)
                }
                detectedWorkingBounds = unionRect
            }
        }
        
        // 4. Calculate working area bounds
        let workingArea: CGRect
        if let calib = calibration {
            let minX = min(calib.topLeft.x, calib.bottomLeft.x)
            let maxX = max(calib.topRight.x, calib.bottomRight.x)
            let minY = min(calib.topLeft.y, calib.topRight.y)
            let maxY = max(calib.bottomLeft.y, calib.bottomRight.y)
            workingArea = CGRect(x: minX, y: minY, width: max(0.2, maxX - minX), height: max(0.2, maxY - minY))
        } else if let bounds = detectedWorkingBounds {
            workingArea = bounds.insetBy(dx: -0.05, dy: -0.05)
        } else {
            workingArea = CGRect(x: 0.15, y: 0.15, width: 0.70, height: 0.70)
        }
        
        return WorkspaceMap(
            domain: domain,
            breadboardDetected: detected,
            breadboardVariant: variant,
            breadboardCalibration: calibration,
            existingComponents: catalogedComponents,
            lightingQuality: lighting,
            estimatedWorkingArea: workingArea,
            timestamp: Date()
        )
    }
    
    // MARK: - Ambient Luminance Assessment
    
    private func estimateLightingQuality(in pixelBuffer: CVPixelBuffer) -> WorkspaceLightingQuality {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return .optimal
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // Sample 100 points across the frame for fast O(1) lighting check
        var totalLuma: Double = 0.0
        var sampleCount: Int = 0
        let stepX = max(1, width / 10)
        let stepY = max(1, height / 10)
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        for y in stride(from: stepY, to: height - stepY, by: stepY) {
            for x in stride(from: stepX, to: width - stepX, by: stepX) {
                let offset = y * bytesPerRow + x * 4
                // BGRA format standard in iOS camera preview
                let b = Double(buffer[offset])
                let g = Double(buffer[offset + 1])
                let r = Double(buffer[offset + 2])
                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                totalLuma += luma
                sampleCount += 1
            }
        }
        
        guard sampleCount > 0 else { return .optimal }
        let averageLuma = totalLuma / Double(sampleCount)
        
        if averageLuma < 50.0 {
            return .dim
        } else if averageLuma > 220.0 {
            return .glare
        } else {
            return .optimal
        }
    }
}
