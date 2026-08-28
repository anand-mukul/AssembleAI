//
//  AssembleAIApp.swift
//  AssembleAI
//

import SwiftUI
import SwiftData

@main
struct AssembleAIApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var authService = CloudKitAuthService()
    @StateObject private var mockAuthService = MockAuthenticationService()

    var body: some Scene {
        WindowGroup {
            MainContainerView()
                .environmentObject(router)
                .environmentObject(authService)
                .environmentObject(mockAuthService)
                .modelContainer(PersistenceController.shared.container)
                .tint(AppColors.brandPrimary)
        }
    }
}
