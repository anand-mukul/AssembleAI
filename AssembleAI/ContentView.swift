//
//  ContentView.swift
//  AssembleAI
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainContainerView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppRouter())
        .environmentObject(SupabaseAuthService())
        .modelContainer(for: LocalProject.self, inMemory: true)
}
