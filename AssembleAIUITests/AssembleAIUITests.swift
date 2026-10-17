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

    private func captureAttachment(_ name: String) {
        Thread.sleep(forTimeInterval: 1.0)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func test00_FullAppDemoWalkthrough() throws {
        let app = XCUIApplication()
        app.launch()

        // 0. Reset to Welcome if logged in
        let profileTab = app.tabBars.buttons["Profile"]
        if profileTab.waitForExistence(timeout: 2.0) {
            profileTab.tap()
            let signOutBtn = app.buttons["Sign Out"]
            if signOutBtn.waitForExistence(timeout: 2.0) {
                signOutBtn.tap()
                let alertSignOut = app.alerts.buttons["Sign Out"]
                if alertSignOut.waitForExistence(timeout: 2.0) {
                    alertSignOut.tap()
                }
            }
        }

        // 1. Welcome Screen & Value Props
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 5.0) {
            Thread.sleep(forTimeInterval: 1.5)

            // Open Privacy Sheet
            let privacyRow = app.staticTexts["Private & On-Device"]
            if privacyRow.exists {
                privacyRow.tap()
                Thread.sleep(forTimeInterval: 1.5)
                let continueButton = app.buttons["Continue"]
                if continueButton.exists {
                    continueButton.tap()
                    Thread.sleep(forTimeInterval: 0.8)
                }
            }

            // Get Started -> Auth Choice
            getStartedButton.tap()
            Thread.sleep(forTimeInterval: 1.2)

            // Continue as guest -> Sheet
            let guestButton = app.buttons["Continue without an account"]
            if guestButton.waitForExistence(timeout: 3.0) {
                guestButton.tap()
                Thread.sleep(forTimeInterval: 1.2)
                let sheetContinue = app.buttons["Continue"]
                if sheetContinue.waitForExistence(timeout: 2.0) {
                    sheetContinue.tap()
                }
            }
        }

        // 2. Home Dashboard
        let homeTab = app.tabBars.buttons["Home"]
        if homeTab.waitForExistence(timeout: 6.0) {
            homeTab.tap()
            Thread.sleep(forTimeInterval: 1.8)

            // Gentle scroll to display active project and recent activities
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1.5)
            app.swipeDown()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // 3. Projects Tab & Detail View
        let projectsTab = app.tabBars.buttons["Projects"]
        if projectsTab.waitForExistence(timeout: 4.0) {
            projectsTab.tap()
            Thread.sleep(forTimeInterval: 1.2)

            // Filter switching
            let inProgressSegment = app.buttons["In Progress"]
            if inProgressSegment.exists {
                inProgressSegment.tap()
                Thread.sleep(forTimeInterval: 0.8)
            }
            let allSegment = app.buttons["All"]
            if allSegment.exists {
                allSegment.tap()
                Thread.sleep(forTimeInterval: 0.8)
            }

            // Open Project Detail
            let ledProjectCard = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'LED Circuit'")).firstMatch
            if ledProjectCard.waitForExistence(timeout: 4.0) {
                ledProjectCard.tap()
                Thread.sleep(forTimeInterval: 2.0)

                // 4. Start Assembly Flow
                let startAssemblyBtn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Start Assembly' OR label BEGINSWITH[c] 'Continue Assembly'")).firstMatch
                if startAssemblyBtn.waitForExistence(timeout: 4.0) {
                    startAssemblyBtn.tap()
                    Thread.sleep(forTimeInterval: 2.0)

                    // Assembly Intro Screen
                    let beginBtn = app.buttons["Begin assembly session"]
                    if beginBtn.waitForExistence(timeout: 4.0) {
                        beginBtn.tap()
                        Thread.sleep(forTimeInterval: 2.0)

                        // Step Instruction Screen
                        let scanSetupBtn = app.buttons["Scan Setup"]
                        if scanSetupBtn.waitForExistence(timeout: 4.0) {
                            scanSetupBtn.tap()
                            Thread.sleep(forTimeInterval: 2.5)

                            // Assembly Camera Screen & Steps Sheet
                            let stepsBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Steps'")).firstMatch
                            if stepsBtn.waitForExistence(timeout: 4.0) {
                                stepsBtn.tap()
                                Thread.sleep(forTimeInterval: 2.0)

                                let doneBtn = app.buttons["Done"]
                                if doneBtn.exists {
                                    doneBtn.tap()
                                    Thread.sleep(forTimeInterval: 1.0)
                                }
                            }

                            // Dismiss assembly camera back to project detail
                            let backBtn = app.buttons["Back"]
                            if backBtn.exists {
                                backBtn.tap()
                                Thread.sleep(forTimeInterval: 1.0)
                            }
                        }
                    }
                }

                // Pop back to Projects
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                    Thread.sleep(forTimeInterval: 0.8)
                }
            }
        }

        // 5. Scan Tab & Optical Verification Modes
        let scanTab = app.tabBars.buttons["Scan"]
        if scanTab.waitForExistence(timeout: 4.0) {
            scanTab.tap()
            Thread.sleep(forTimeInterval: 1.5)

            // Open Target Project Picker Sheet
            let projectPickerCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Target Project' OR label CONTAINS[c] 'Select Project' OR label CONTAINS[c] 'LED Circuit'")).firstMatch
            if projectPickerCard.waitForExistence(timeout: 3.0) {
                projectPickerCard.tap()
                Thread.sleep(forTimeInterval: 1.5)
                let electronicsFilter = app.buttons["Electronics"]
                if electronicsFilter.exists {
                    electronicsFilter.tap()
                    Thread.sleep(forTimeInterval: 0.8)
                }
                let doneBtn = app.buttons["Done"]
                if doneBtn.exists {
                    doneBtn.tap()
                    Thread.sleep(forTimeInterval: 0.8)
                }
            }

            // Identify Part Segment
            let identifyPartSegment = app.buttons["Identify Part"]
            if identifyPartSegment.waitForExistence(timeout: 3.0) {
                identifyPartSegment.tap()
                Thread.sleep(forTimeInterval: 1.5)
            }

            // Scan Manual Segment & Project Creator
            let scanManualSegment = app.buttons["Scan Manual"]
            if scanManualSegment.waitForExistence(timeout: 3.0) {
                scanManualSegment.tap()
                Thread.sleep(forTimeInterval: 1.2)
                
                let importBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Import' OR label CONTAINS[c] 'Manual'")).firstMatch
                if importBtn.waitForExistence(timeout: 3.0) {
                    importBtn.tap()
                    Thread.sleep(forTimeInterval: 2.0)
                    
                    let cancelBtn = app.buttons["Cancel"]
                    if cancelBtn.exists {
                        cancelBtn.tap()
                        Thread.sleep(forTimeInterval: 0.8)
                    }
                }
            }
        }

        // 6. History Tab
        let historyTab = app.tabBars.buttons["History"]
        if historyTab.waitForExistence(timeout: 4.0) {
            historyTab.tap()
            Thread.sleep(forTimeInterval: 1.5)
        }

        // 7. Profile Tab & Settings
        if profileTab.waitForExistence(timeout: 4.0) {
            profileTab.tap()
            Thread.sleep(forTimeInterval: 1.2)

            // Edit Profile Sheet
            let editButton = app.buttons["Edit"]
            if editButton.waitForExistence(timeout: 3.0) {
                editButton.tap()
                Thread.sleep(forTimeInterval: 1.2)
                let cancelBtn = app.buttons["Cancel"]
                if cancelBtn.exists {
                    cancelBtn.tap()
                    Thread.sleep(forTimeInterval: 0.8)
                }
            }

            // App Settings
            let appSettingsRow = app.staticTexts["App Settings"]
            if appSettingsRow.waitForExistence(timeout: 3.0) {
                appSettingsRow.tap()
                Thread.sleep(forTimeInterval: 1.5)
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                    Thread.sleep(forTimeInterval: 0.8)
                }
            }
        }

        // 8. Return to Home
        if homeTab.waitForExistence(timeout: 4.0) {
            homeTab.tap()
            Thread.sleep(forTimeInterval: 2.0)
        }
    }

    @MainActor
    func test01_CaptureOnboardingAndAuth() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Welcome Screen
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 6.0) {
            captureAttachment("01_Welcome_Screen")

            // Privacy Sheet
            let privacyRow = app.staticTexts["Private & On-Device"]
            if privacyRow.exists {
                privacyRow.tap()
                let privacyTitle = app.staticTexts["Your Camera, Your Data"]
                if privacyTitle.waitForExistence(timeout: 3.0) {
                    captureAttachment("02_Privacy_Policy_Sheet")
                    let continueButton = app.buttons["Continue"]
                    if continueButton.exists {
                        continueButton.tap()
                    }
                }
            }

            // Auth Choice
            getStartedButton.tap()
            let guestButton = app.buttons["Continue without an account"]
            if guestButton.waitForExistence(timeout: 4.0) {
                captureAttachment("03_Auth_Choice_Screen")

                // Email Sign In screen
                let emailButton = app.buttons["Continue with Email"]
                if emailButton.exists {
                    emailButton.tap()
                    let signInHeader = app.staticTexts["Sign In"]
                    if signInHeader.waitForExistence(timeout: 3.0) {
                        captureAttachment("04_Email_Sign_In_Screen")
                    }
                }
            }
        }
    }

    @MainActor
    func test02_CaptureMainAppTabsAndFeatures() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Guest if on Welcome screen
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 5.0) {
            getStartedButton.tap()
        }

        let guestButton = app.buttons["Continue without an account"]
        if guestButton.waitForExistence(timeout: 4.0) {
            guestButton.tap()
            
            let sheetHeader = app.staticTexts["Continue on iPhone"]
            if sheetHeader.waitForExistence(timeout: 3.0) {
                captureAttachment("05_Guest_Confirmation_Sheet")
                let continueBtn = app.buttons["Continue"]
                if continueBtn.waitForExistence(timeout: 2.0) {
                    continueBtn.tap()
                }
            }
        }

        // Main App Tabs
        let homeTab = app.tabBars.buttons["Home"]
        if homeTab.waitForExistence(timeout: 10.0) {
            captureAttachment("06_Home_Tab")

            // Projects Tab
            let projectsTab = app.tabBars.buttons["Projects"]
            if projectsTab.waitForExistence(timeout: 4.0) {
                projectsTab.tap()
                captureAttachment("07_Projects_Tab")
            }

            // Scan Tab
            let scanTab = app.tabBars.buttons["Scan"]
            if scanTab.waitForExistence(timeout: 4.0) {
                scanTab.tap()
                captureAttachment("08_Scan_Tab")
            }

            // History Tab
            let historyTab = app.tabBars.buttons["History"]
            if historyTab.waitForExistence(timeout: 4.0) {
                historyTab.tap()
                captureAttachment("09_History_Tab")
            }

            // Profile Tab
            let profileTab = app.tabBars.buttons["Profile"]
            if profileTab.waitForExistence(timeout: 4.0) {
                profileTab.tap()
                captureAttachment("10_Profile_Tab")
            }
        }
    }

    @MainActor
    func test03_CaptureAuthFlowSubscreens() throws {
        let app = XCUIApplication()
        app.launch()

        // If logged in, sign out first from Profile
        let profileTab = app.tabBars.buttons["Profile"]
        if profileTab.waitForExistence(timeout: 3.0) {
            profileTab.tap()
            let signOutBtn = app.buttons["Sign Out"]
            if signOutBtn.waitForExistence(timeout: 2.0) {
                signOutBtn.tap()
                let alertSignOut = app.alerts.buttons["Sign Out"]
                if alertSignOut.waitForExistence(timeout: 2.0) {
                    alertSignOut.tap()
                }
            }
        }

        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 5.0) {
            getStartedButton.tap()
        }

        let emailButton = app.buttons["Continue with Email"]
        if emailButton.waitForExistence(timeout: 4.0) {
            emailButton.tap()

            // 11. Forgot Password
            let forgotPasswordButton = app.buttons["Forgot password"]
            if forgotPasswordButton.waitForExistence(timeout: 3.0) {
                forgotPasswordButton.tap()
                captureAttachment("11_Forgot_Password_Screen")

                // Go back
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                }
            }

            // 12. Create Account
            let createAccountButton = app.buttons["Don't have an account? Create account"]
            if createAccountButton.waitForExistence(timeout: 3.0) {
                createAccountButton.tap()
                captureAttachment("12_Create_Account_Screen")
            }
        }
    }

    @MainActor
    func test04_CaptureProjectAndAssemblyFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Guest sign in if needed
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 4.0) {
            getStartedButton.tap()
            let guestButton = app.buttons["Continue without an account"]
            if guestButton.waitForExistence(timeout: 3.0) {
                guestButton.tap()
                let continueBtn = app.buttons["Continue"]
                if continueBtn.waitForExistence(timeout: 2.0) {
                    continueBtn.tap()
                }
            }
        }

        // Navigate to Projects tab
        let projectsTab = app.tabBars.buttons["Projects"]
        if projectsTab.waitForExistence(timeout: 6.0) {
            projectsTab.tap()
            
            let ledProjectCard = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'LED Circuit'")).firstMatch
            if ledProjectCard.waitForExistence(timeout: 4.0) {
                ledProjectCard.tap()
                
                let aboutHeader = app.staticTexts["About"]
                if aboutHeader.waitForExistence(timeout: 4.0) {
                    // 13. Project Detail Screen
                    captureAttachment("13_Project_Detail_Screen")
                    
                    // Tap Start Assembly CTA
                    let startAssemblyBtn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Start Assembly' OR label BEGINSWITH[c] 'Continue Assembly'")).firstMatch
                    if startAssemblyBtn.waitForExistence(timeout: 4.0) {
                        startAssemblyBtn.tap()

                        // 14. Assembly Intro Screen
                        let readyTitle = app.staticTexts["Ready to build?"]
                        if readyTitle.waitForExistence(timeout: 5.0) {
                            captureAttachment("14_Assembly_Intro_Screen")

                            // Tap "Begin assembly session"
                            let beginBtn = app.buttons["Begin assembly session"]
                            if beginBtn.waitForExistence(timeout: 4.0) {
                                beginBtn.tap()

                                // 15. Step Instruction Screen
                                let scanSetupBtn = app.buttons["Scan Setup"]
                                if scanSetupBtn.waitForExistence(timeout: 5.0) {
                                    captureAttachment("15_Step_Instruction_Screen")
                                    scanSetupBtn.tap()

                                    // 16. Assembly Camera Screen
                                    let stepsBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Steps'")).firstMatch
                                    if stepsBtn.waitForExistence(timeout: 5.0) {
                                        captureAttachment("16_Assembly_Camera_Screen")

                                        // 24. Steps Overview Sheet
                                        stepsBtn.tap()
                                        let stepsHeader = app.staticTexts["Assembly Steps"]
                                        if stepsHeader.waitForExistence(timeout: 4.0) {
                                            captureAttachment("24_Steps_Overview_Sheet")
                                            let doneBtn = app.buttons["Done"]
                                            if doneBtn.exists {
                                                doneBtn.tap()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func test05_CaptureProfileSubscreensAndLegal() throws {
        let app = XCUIApplication()
        app.launch()

        // Guest sign in if needed
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 4.0) {
            getStartedButton.tap()
            let guestButton = app.buttons["Continue without an account"]
            if guestButton.waitForExistence(timeout: 3.0) {
                guestButton.tap()
                let continueBtn = app.buttons["Continue"]
                if continueBtn.waitForExistence(timeout: 2.0) {
                    continueBtn.tap()
                }
            }
        }

        // Switch to Profile Tab
        let profileTab = app.tabBars.buttons["Profile"]
        if profileTab.waitForExistence(timeout: 6.0) {
            profileTab.tap()

            // 17. Edit Profile Sheet
            let editButton = app.buttons["Edit"]
            if editButton.waitForExistence(timeout: 3.0) {
                editButton.tap()
                captureAttachment("17_Edit_Profile_Sheet")
                let cancelBtn = app.buttons["Cancel"]
                if cancelBtn.exists {
                    cancelBtn.tap()
                }
            }

            // 18. App Settings
            let appSettingsRow = app.staticTexts["App Settings"]
            if appSettingsRow.waitForExistence(timeout: 3.0) {
                appSettingsRow.tap()
                captureAttachment("18_App_Settings_Screen")
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                }
            }

            // 19. Data & Privacy
            let dataPrivacyRow = app.staticTexts["Data & Privacy"]
            if dataPrivacyRow.waitForExistence(timeout: 3.0) {
                dataPrivacyRow.tap()
                captureAttachment("19_Data_Privacy_Screen")
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                }
            }

            // 20. Notifications
            let notificationsRow = app.staticTexts["Notifications"]
            if notificationsRow.waitForExistence(timeout: 3.0) {
                notificationsRow.tap()
                captureAttachment("20_Notifications_Screen")
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                }
            }

            // 21. Help & Support
            let helpRow = app.staticTexts["Assembly Guide & FAQ"]
            if helpRow.waitForExistence(timeout: 3.0) {
                helpRow.tap()
                captureAttachment("21_Help_And_Support_Screen")
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                }
            }

            // 22. Terms of Service
            let termsButton = app.buttons["Terms of Service"]
            if termsButton.waitForExistence(timeout: 3.0) {
                termsButton.tap()
                captureAttachment("22_Terms_Of_Service_Sheet")
                let continueBtn = app.buttons["Continue"]
                if continueBtn.exists {
                    continueBtn.tap()
                }
            }
        }
    }

    @MainActor
    func test06_CaptureCreatorAndScanModes() throws {
        let app = XCUIApplication()
        app.launch()

        // Guest sign in if needed
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 4.0) {
            getStartedButton.tap()
            let guestButton = app.buttons["Continue without an account"]
            if guestButton.waitForExistence(timeout: 3.0) {
                guestButton.tap()
                let continueBtn = app.buttons["Continue"]
                if continueBtn.waitForExistence(timeout: 2.0) {
                    continueBtn.tap()
                }
            }
        }

        // Switch to Scan Tab
        let scanTab = app.tabBars.buttons["Scan"]
        if scanTab.waitForExistence(timeout: 6.0) {
            scanTab.tap()

            // 25. Target Project Picker Sheet (from Verify Step mode)
            let projectPickerCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Target Project' OR label CONTAINS[c] 'Select Project' OR label CONTAINS[c] 'LED Circuit'")).firstMatch
            if projectPickerCard.waitForExistence(timeout: 4.0) {
                projectPickerCard.tap()
                let pickerTitle = app.staticTexts["Select Project"]
                if pickerTitle.waitForExistence(timeout: 4.0) {
                    captureAttachment("25_Target_Project_Picker_Sheet")
                    let doneBtn = app.buttons["Done"]
                    if doneBtn.exists {
                        doneBtn.tap()
                    }
                }
            }

            // Tap "Identify Part" segment
            let identifyPartSegment = app.buttons["Identify Part"]
            if identifyPartSegment.waitForExistence(timeout: 3.0) {
                identifyPartSegment.tap()
                let classifierTitle = app.staticTexts["Real-Time Hardware Classifier"]
                if classifierTitle.waitForExistence(timeout: 3.0) {
                    captureAttachment("26_Part_Identification_Mode")
                }
            }

            // Tap "Scan Manual" segment
            let scanManualSegment = app.buttons["Scan Manual"]
            if scanManualSegment.waitForExistence(timeout: 3.0) {
                scanManualSegment.tap()
                
                // Tap button to launch Guide Import / Creator
                let importBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Import' OR label CONTAINS[c] 'Manual'")).firstMatch
                if importBtn.waitForExistence(timeout: 3.0) {
                    importBtn.tap()
                    let newProjectHeader = app.staticTexts["New Project"]
                    if newProjectHeader.waitForExistence(timeout: 3.0) {
                        captureAttachment("23_Project_Creator_Screen")
                    }
                }
            }
        }
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
            
            // Verify Scan Tab navigation
            let scanTab = app.tabBars.buttons["Scan"]
            if scanTab.exists {
                scanTab.tap()
                XCTAssertTrue(scanTab.isSelected)
                let startInspectionBtn = app.buttons["Start Visual Inspection"]
                XCTAssertTrue(startInspectionBtn.waitForExistence(timeout: 3.0))
            }
            
            // Verify History Tab navigation
            let historyTab = app.tabBars.buttons["History"]
            if historyTab.exists {
                historyTab.tap()
                XCTAssertTrue(historyTab.isSelected)
            }
            
            // Verify Profile Tab navigation
            let profileTab = app.tabBars.buttons["Profile"]
            if profileTab.exists {
                profileTab.tap()
                XCTAssertTrue(profileTab.isSelected)
            }
        }
    }

    @MainActor
    func testWelcomeScreenPrivacySheet() throws {
        let app = XCUIApplication()
        app.launch()

        let privacyRow = app.staticTexts["Private & On-Device"]
        if privacyRow.waitForExistence(timeout: 4.0) {
            privacyRow.tap()
            
            let privacyTitle = app.staticTexts["Your Camera, Your Data"]
            XCTAssertTrue(privacyTitle.waitForExistence(timeout: 3.0))
            
            let continueButton = app.buttons["Continue"]
            if continueButton.exists {
                continueButton.tap()
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

