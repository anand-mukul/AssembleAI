//
//  ProfileViewModelTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

@MainActor
final class ProfileViewModelTests: XCTestCase {
    
    private var authService: SupabaseAuthService!
    private var viewModel: ProfileViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        authService = SupabaseAuthService()
        await authService.continueAsGuest()
        viewModel = ProfileViewModel(authService: authService)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        authService = nil
        try await super.tearDown()
    }
    
    // MARK: - Test 1: Initial State & User Binding
    func testInitialState() async {
        XCTAssertNotNil(viewModel.user)
        XCTAssertTrue(viewModel.user?.isGuest == true)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isDeletingAccount)
        XCTAssertFalse(viewModel.showDeleteAccountConfirmation)
        XCTAssertNil(viewModel.deletionError)
    }
    
    // MARK: - Test 2: App Settings Storage Properties
    func testAppSettingsStorageProperties() {
        // Toggle values and verify setters
        viewModel.showCameraGrid = true
        XCTAssertTrue(viewModel.showCameraGrid)
        viewModel.showCameraGrid = false
        XCTAssertFalse(viewModel.showCameraGrid)
        
        viewModel.reticlePulsing = false
        XCTAssertFalse(viewModel.reticlePulsing)
        viewModel.reticlePulsing = true
        XCTAssertTrue(viewModel.reticlePulsing)
        
        viewModel.hapticsEnabled = false
        XCTAssertFalse(viewModel.hapticsEnabled)
        viewModel.hapticsEnabled = true
        XCTAssertTrue(viewModel.hapticsEnabled)
        
        viewModel.autoTorch = true
        XCTAssertTrue(viewModel.autoTorch)
        
        viewModel.verificationMode = "vision"
        XCTAssertEqual(viewModel.verificationMode, "vision")
        
        viewModel.guidanceLevelRaw = GuidanceLevel.detailed.rawValue
        XCTAssertEqual(viewModel.guidanceLevelRaw, GuidanceLevel.detailed.rawValue)
    }
    
    // MARK: - Test 3: Account Deletion Flow (Guideline 5.1.1(v))
    func testAccountDeletionFlow() async {
        XCTAssertTrue(await authService.isAuthenticated)
        
        viewModel.showDeleteAccountConfirmation = true
        XCTAssertTrue(viewModel.showDeleteAccountConfirmation)
        
        await viewModel.deleteAccount()
        
        XCTAssertFalse(viewModel.isDeletingAccount)
        XCTAssertFalse(viewModel.showDeleteAccountConfirmation)
        XCTAssertNil(viewModel.deletionError)
        XCTAssertFalse(await authService.isAuthenticated)
        XCTAssertNil(await authService.currentUser)
    }
    
    // MARK: - Test 4: Sign Out Flow
    func testSignOutFlow() async {
        XCTAssertTrue(await authService.isAuthenticated)
        
        await viewModel.signOut()
        
        XCTAssertFalse(await authService.isAuthenticated)
        XCTAssertNil(await authService.currentUser)
    }
    
    // MARK: - Test 5: Research Telemetry & Strategy Configuration
    func testResearchTelemetryAndStrategyConfiguration() async {
        // Test visual history strategy preference
        viewModel.visualHistoryStrategyRaw = VisualHistoryStrategy.lastNFrames.rawValue
        XCTAssertEqual(viewModel.visualHistoryStrategyRaw, "lastNFrames")
        viewModel.lastNFramesValue = 8
        XCTAssertEqual(viewModel.lastNFramesValue, 8)
        
        // Test stats loading
        await viewModel.loadResearchStats()
        XCTAssertGreaterThanOrEqual(viewModel.researchSessionCount, 0)
        XCTAssertGreaterThanOrEqual(viewModel.researchEventsCount, 0)
        
        // Test export trigger
        viewModel.exportSummaryCSV()
        // Wait a brief moment for Task execution
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.isExportingTelemetry)
    }
}
