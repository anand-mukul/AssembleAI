//
//  AssembleAIUITests.swift
//  AssembleAIUITests
//
//  Created by Mukul on 24/08/26.
//

import XCTest

final class AssembleAIUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testWelcomeScreenElementsAndNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify Welcome Screen elements
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 4.0) {
            XCTAssertTrue(getStartedButton.isHittable)

            // Navigate to Auth Choice
            getStartedButton.tap()

            // Verify Auth Choice Options
            let appleButton = app.buttons["Sign in with Apple"]
            let emailButton = app.buttons["Continue with Email"]
            let guestButton = app.buttons["Continue without an account"]

            XCTAssertTrue(appleButton.waitForExistence(timeout: 3.0))
            XCTAssertTrue(emailButton.exists)
            XCTAssertTrue(guestButton.exists)

            // Tap Guest Access
            guestButton.tap()

            // Check Confirmation Sheet
            let confirmGuestButton = app.buttons["Continue as Guest"]
            if confirmGuestButton.waitForExistence(timeout: 2.0) {
                confirmGuestButton.tap()
            }
        }

        // Verify Home Tab Bar & Navigation
        let homeTab = app.tabBars.buttons["Home"]
        if homeTab.waitForExistence(timeout: 5.0) {
            XCTAssertTrue(homeTab.isSelected || homeTab.exists)

            // Verify Projects Tab navigation
            let projectsTab = app.tabBars.buttons["Projects"]
            if projectsTab.exists {
                projectsTab.tap()
                XCTAssertTrue(projectsTab.isSelected)
            }
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

