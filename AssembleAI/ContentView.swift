//
//  ContentView.swift
//  AssembleAI
//

import SwiftUI

/// Main entry view redirecting to MainContainerView.
struct ContentView: View {
    var body: some View {
        MainContainerView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppRouter())
        .environmentObject(CloudKitAuthService())
}
