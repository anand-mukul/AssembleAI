//
//  MultimodalAppleIntelligenceTests.swift
//  AssembleAITests
//
//  Comprehensive test suite for AssembleAI 2.0 Multimodal Apple Intelligence.
//
//  SIMULATOR vs DEVICE:
//  ─────────────────────────────────────────────────────────────────────────────
//  All tests run in Xcode Simulator using mock actors.
//  Tests marked [DEVICE-ONLY] require a physical iPhone 16 Pro/Max (iOS 26+)
//  because they exercise:
//    • FoundationModels on-device LLM (requires Neural Engine / ANE)
//    • ARKit sceneDepth / smoothedSceneDepth (requires LiDAR scanner)
//  ─────────────────────────────────────────────────────────────────────────────

import XCTest
import CoreGraphics
import CoreVideo
import simd
@testable import AssembleAI

// MARK: - Helpers

private func makeBGRAPixelBuffer(width: Int = 320, height: Int = 240) -> CVPixelBuffer? {
    var buf: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                        kCVPixelFormatType_32BGRA, nil, &buf)
    return buf
}

private func makeDepthFloat32Buffer(width: Int = 160, height: Int = 120,
                                     filledWith value: Float32 = 0.40) -> CVPixelBuffer? {
    var buf: CVPixelBuffer?
    let attrs: [CFString: Any] = [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary]
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                     kCVPixelFormatType_DepthFloat32,
                                     attrs as CFDictionary, &buf)
    guard status == kCVReturnSuccess, let depth = buf else { return nil }

    CVPixelBufferLockBaseAddress(depth, [])
    if let base = CVPixelBufferGetBaseAddress(depth) {
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depth)
        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
            for x in 0..<width { row[x] = value }
        }
    }
    CVPixelBufferUnlockBaseAddress(depth, [])
    return depth
}

private func makeSampleStep(title: String = "Insert 220Ω Resistor",
                              instruction: String = "Place resistor from pin D10 to D14") -> AssemblyStep {
    AssemblyStep(
        id: UUID(),
        projectId: UUID(),
        stepOrder: 1,
        title: title,
        instruction: instruction,
        visualContract: VisualContract(
            requiredComponents: [ExpectedComponent(identifier: "part_res_220", name: "220Ω Resistor")]
        )
    )
}

// MARK: - Test Suite

final class MultimodalAppleIntelligenceTests: XCTestCase {

    // MARK: - Test 1: Mock Verifier — Scripted Pass Assessment [SIMULATOR ✓]
    func testMockVerifierScriptedPassAssessment() async {
        let mock = MockMultimodalVisionVerifier()

        let passingAssessment = MultimodalAssemblyAssessment(
            isStepComplete: true,
            detectedComponents: [
                MultimodalDetectedPart(
                    partName: "220Ω Resistor",
                    category: "Resistor",
                    colorBandsOrMarkings: ["red", "red", "brown"],
                    observedLocation: "Row 10-15",
                    confidence: 0.93
                )
            ],
            alignmentStatus: "Nominal",
            identifiedMistakes: [],
            confidenceScore: 0.93,
            executionLatencyMs: 12.0,
            isMultimodalEngineActive: false
        )
        await mock.setScriptedAssessments([passingAssessment])

        guard let buffer = makeBGRAPixelBuffer() else {
            XCTFail("Failed to create pixel buffer")
            return
        }

        let result = await mock.verify(frame: buffer, step: makeSampleStep(), domain: .electronics)

        XCTAssertTrue(result.isStepComplete)
        XCTAssertGreaterThanOrEqual(result.confidenceScore, 0.90)
        XCTAssertFalse(result.detectedComponents.isEmpty)
        XCTAssertEqual(result.detectedComponents.first?.partName, "220Ω Resistor")
        XCTAssertEqual(result.detectedComponents.first?.colorBandsOrMarkings, ["red", "red", "brown"])
        let callCount = await mock.verifyCallCount
        XCTAssertEqual(callCount, 1)
    }

    // MARK: - Test 2: Mock Verifier — Scripted Fail Assessment [SIMULATOR ✓]
    func testMockVerifierScriptedFailAssessment() async {
        let mock = MockMultimodalVisionVerifier()

        let failAssessment = MultimodalAssemblyAssessment(
            isStepComplete: false,
            detectedComponents: [
                MultimodalDetectedPart(
                    partName: "LED (Red)",
                    category: "LED",
                    colorBandsOrMarkings: [],
                    observedLocation: "Row 10",
                    confidence: 0.88
                )
            ],
            alignmentStatus: "Wrong component — LED detected instead of Resistor",
            identifiedMistakes: ["Capacitor placed in resistor slot"],
            suggestedCorrection: "Remove the LED and insert the 220Ω resistor with Red-Red-Brown bands",
            confidenceScore: 0.88,
            executionLatencyMs: 18.0,
            isMultimodalEngineActive: false
        )
        await mock.setScriptedAssessments([failAssessment])

        guard let buffer = makeBGRAPixelBuffer() else {
            XCTFail("Buffer allocation failed")
            return
        }

        let result = await mock.verify(frame: buffer, step: makeSampleStep(), domain: .electronics)

        XCTAssertFalse(result.isStepComplete)
        XCTAssertFalse(result.identifiedMistakes.isEmpty)
        XCTAssertNotNil(result.suggestedCorrection)
        XCTAssertFalse(result.alignmentStatus.contains("Nominal"))
    }

    // MARK: - Test 3: Mock Verifier — Session Reset [SIMULATOR ✓]
    func testMockVerifierSessionReset() async {
        let mock = MockMultimodalVisionVerifier()
        guard let buffer = makeBGRAPixelBuffer() else { return }

        _ = await mock.verify(frame: buffer, step: makeSampleStep(), domain: .electronics)
        let countBeforeReset = await mock.verifyCallCount
        XCTAssertEqual(countBeforeReset, 1)

        await mock.resetSession()
        let resetCount = await mock.resetCallCount
        XCTAssertEqual(resetCount, 1)

        // After reset, scripted queue cleared — returns default
        _ = await mock.verify(frame: buffer, step: makeSampleStep(), domain: .electronics)
        let countAfterReset = await mock.verifyCallCount
        XCTAssertEqual(countAfterReset, 2)
    }

    // MARK: - Test 4: Mock Verifier — Universal Domain Coverage [SIMULATOR ✓]
    func testMockVerifierUniversalDomainCoverage() async {
        let mock = MockMultimodalVisionVerifier()
        guard let buffer = makeBGRAPixelBuffer() else { return }

        let domains: [AssemblyDomain] = [.electronics, .furniture, .automotive, .robotics, .aerospace]
        for domain in domains {
            let step = makeSampleStep(
                title: "Domain Step",
                instruction: "Generic assembly instruction for \(domain.rawValue)"
            )
            let result = await mock.verify(frame: buffer, step: step, domain: domain)
            XCTAssertNotNil(result, "Mock should return assessment for domain \(domain.rawValue)")
        }

        let totalCalls = await mock.verifyCallCount
        XCTAssertEqual(totalCalls, domains.count)
    }

    // MARK: - Test 5: LiDAR Mock — Depth Assessment [SIMULATOR ✓]
    func testLiDARMockDepthAssessment() async {
        let mockLidar = MockLiDARSpatialMeshCoordinator(lidarSupported: true)

        guard let depth = makeDepthFloat32Buffer(filledWith: 0.40) else {
            XCTFail("Failed to allocate depth buffer")
            return
        }

        let assessment = await mockLidar.assessDepth(in: depth)

        XCTAssertTrue(assessment.isLiDARAvailable)
        XCTAssertNotNil(assessment.averageDepthMeters)
        XCTAssertEqual(assessment.averageDepthMeters ?? 0, 0.40, accuracy: 0.05)
        XCTAssertGreaterThan(assessment.detectedMeshAnchorCount, 0)
        let count = await mockLidar.assessDepthCallCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - Test 6: LiDAR Mock — 3D Unprojection at Center [SIMULATOR ✓]
    func testLiDARMockUnprojectionAtCenter() async {
        let mockLidar = MockLiDARSpatialMeshCoordinator(lidarSupported: true)

        guard let depth = makeDepthFloat32Buffer(filledWith: 0.40) else {
            XCTFail("Failed to allocate depth buffer")
            return
        }

        let point = await mockLidar.unprojectTo3D(
            normalizedPoint: CGPoint(x: 0.5, y: 0.5),
            depthBuffer: depth
        )

        XCTAssertNotNil(point)
        XCTAssertEqual(point?.z ?? 0, 0.40, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(point?.confidence ?? 0, 0.90)
    }

    // MARK: - Test 7: LiDAR Mock — Unsupported Device Simulation [SIMULATOR ✓]
    func testLiDARMockUnsupportedDeviceFallback() async {
        let mockLidar = MockLiDARSpatialMeshCoordinator(lidarSupported: false)
        let isSupported = await mockLidar.isLiDARSupported
        XCTAssertFalse(isSupported, "Non-Pro device simulation should report LiDAR as unsupported")
    }

    // MARK: - Test 8: LiDAR Mock — Nil Point (Occluded / Out-of-range) [SIMULATOR ✓]
    func testLiDARMockOccludedPointReturnsNil() async {
        let mockLidar = MockLiDARSpatialMeshCoordinator(lidarSupported: true)
        await mockLidar.stubbedPoint = nil // Simulate occluded or invalid depth

        guard let depth = makeDepthFloat32Buffer(filledWith: 0.40) else { return }
        let point = await mockLidar.unprojectTo3D(
            normalizedPoint: CGPoint(x: 0.5, y: 0.5),
            depthBuffer: depth
        )
        XCTAssertNil(point, "Occluded depth should return nil from unprojection")
    }

    // MARK: - Test 9: Real LiDAR Depth Unprojection Logic [SIMULATOR ✓ — logic only]
    //   This tests the depth-buffer math without ARKit hardware.
    //   On a physical iPhone 16 Pro running iOS 26+, this validates actual sceneDepth output.
    func testRealLiDARDepthBufferMathLogic() async {
        let coordinator = LiDARSpatialMeshCoordinator.shared

        guard let depth = makeDepthFloat32Buffer(width: 160, height: 120, filledWith: 0.40) else {
            XCTFail("Failed to allocate depth buffer")
            return
        }

        // Test math: center pixel at (0.5, 0.5) in a 160x120 DepthFloat32 buffer
        // filled uniformly with 0.40 metres should unproject to Z ≈ 0.40m
        let point = await coordinator.unprojectTo3D(
            normalizedPoint: CGPoint(x: 0.5, y: 0.5),
            depthBuffer: depth
        )

        XCTAssertNotNil(point, "Depth math unprojection should succeed on any device/simulator")
        if let pt = point {
            XCTAssertEqual(pt.z, 0.40, accuracy: 0.01,
                           "Center pixel Z should be ≈ 0.40m (the filled value)")
            XCTAssertEqual(pt.x, 0.0, accuracy: 0.05,
                           "Center pixel X offset should be ~zero (principal point)")
            XCTAssertEqual(pt.y, 0.0, accuracy: 0.05,
                           "Center pixel Y offset should be ~zero (principal point)")
            XCTAssertGreaterThanOrEqual(pt.confidence, 0.90)
        }

        // Depth assessment
        let meshAssessment = await coordinator.assessDepth(in: depth)
        XCTAssertNotNil(meshAssessment.averageDepthMeters)
        XCTAssertEqual(meshAssessment.averageDepthMeters ?? 0, 0.40, accuracy: 0.05)
    }

    // MARK: - Test 10: Universal Physical Anchor — Grid & Polarity [SIMULATOR ✓]
    func testUniversalPhysicalAnchorGridAndPolarityInference() {
        // Contract with > 35 rows (Full Breadboard)
        let fullBreadboardContract = VisualContract(
            requiredComponents: [ExpectedComponent(identifier: "ic_atmega", name: "ATmega328P")],
            pinPlacements: [
                ComponentPinPlacement(
                    componentId: "ic_atmega",
                    coordinate: PinCoordinate(column: "E", row: 42)
                )
            ],
            expectedConnections: [
                ExpectedConnection(fromNode: "Anode", toNode: "D13")
            ],
            orientationConstraints: [
                OrientationConstraint(
                    componentId: "led_red",
                    targetOrientation: .anodeCathode(anodeHole: "D13", cathodeHole: "GND")
                )
            ]
        )

        let anchors = fullBreadboardContract.universalAnchors
        XCTAssertFalse(anchors.isEmpty)

        // Verify Full Breadboard inference (63-row full board)
        let gridAnchor = anchors.compactMap { anchor -> GridAnchorDefinition? in
            if case .grid(let def) = anchor { return def }
            return nil
        }.first
        XCTAssertNotNil(gridAnchor)
        XCTAssertEqual(gridAnchor?.rows, 63)
        XCTAssertEqual(gridAnchor?.identifier, "breadboard_full")

        // Verify polarity sensitivity derived from orientation constraints
        let connectorAnchor = anchors.compactMap { anchor -> ConnectorAnchorDefinition? in
            if case .connector(let def) = anchor { return def }
            return nil
        }.first
        XCTAssertNotNil(connectorAnchor)
        XCTAssertTrue(connectorAnchor?.polaritySensitive == true)
    }

    // MARK: - Test 11: MultimodalDetectedPart — Data Model Integrity [SIMULATOR ✓]
    func testMultimodalDetectedPartDataModelIntegrity() {
        let part = MultimodalDetectedPart(
            partName: "ATmega328P",
            category: "Microcontroller",
            colorBandsOrMarkings: ["black", "ATMEGA328P-PU"],
            observedLocation: "IC Socket U1",
            orientationDegrees: 90.0,
            confidence: 0.97
        )

        XCTAssertEqual(part.partName, "ATmega328P")
        XCTAssertEqual(part.category, "Microcontroller")
        XCTAssertEqual(part.colorBandsOrMarkings.count, 2)
        XCTAssertEqual(part.observedLocation, "IC Socket U1")
        XCTAssertEqual(part.orientationDegrees, 90.0)
        XCTAssertEqual(part.confidence, 0.97, accuracy: 0.001)
    }

    // MARK: - Test 12: MultimodalAssemblyAssessment — Fallback Static [SIMULATOR ✓]
    func testMultimodalAssemblyAssessmentFallbackStatic() {
        let fallback = MultimodalAssemblyAssessment.fallbackPass
        XCTAssertTrue(fallback.isStepComplete)
        XCTAssertEqual(fallback.alignmentStatus, "Fallback Pass")
        XCTAssertFalse(fallback.isMultimodalEngineActive)
        XCTAssertGreaterThanOrEqual(fallback.confidenceScore, 0.75)
    }

    // MARK: - Test 13: Spatial3DPoint — Distance Calculation in Mm [SIMULATOR ✓]
    func testSpatial3DPointMillimeterDistanceCalculation() {
        let origin = Spatial3DPoint(x: 0, y: 0, z: 0.40)
        let point = Spatial3DPoint(x: 0.165, y: 0, z: 0.40) // 165mm right = breadboard width

        let distanceMm = origin.distanceMm(to: point)
        XCTAssertEqual(distanceMm, 165.0, accuracy: 0.5,
                       "165mm breadboard width distance should be accurately calculated")
    }

    // MARK: - Test 14: SpatialMeshAssessment — Fallback Static [SIMULATOR ✓]
    func testSpatialMeshAssessmentFallbackStatic() {
        let fallback = SpatialMeshAssessment.fallback
        XCTAssertFalse(fallback.isLiDARAvailable)
        XCTAssertNotNil(fallback.averageDepthMeters)
        XCTAssertNotNil(fallback.surfacePlaneNormal)
        XCTAssertEqual(fallback.averageDepthMeters ?? 0, 0.40, accuracy: 0.01)
    }

    // MARK: - Test 15: AppleIntelligenceService Capabilities [SIMULATOR ✓]
    //   NOTE [DEVICE-ONLY]: `neuralEngineTOPS` will be 0 on Simulator.
    //   On physical iPhone 16+, it will report > 35 TOPS.
    func testAppleIntelligenceServiceCapabilities() async {
        let service = AppleIntelligenceService.shared
        let caps = await service.getCapabilities()

        XCTAssertFalse(caps.deviceModel.isEmpty,
                       "Device model must never be empty (Simulator or physical)")
        XCTAssertFalse(caps.osVersion.isEmpty,
                       "OS version must never be empty")
        XCTAssertNotNil(caps.summary,
                        "Capabilities summary must be non-nil")

        // neuralEngineTOPS > 0 only on real hardware
        #if targetEnvironment(simulator)
        // Simulator: TOPS will be 0 — acceptable
        XCTAssertGreaterThanOrEqual(caps.neuralEngineTOPS, 0)
        #else
        XCTAssertGreaterThan(caps.neuralEngineTOPS, 0,
                             "[DEVICE-ONLY] Physical device must report Neural Engine TOPS")
        #endif
    }
}
