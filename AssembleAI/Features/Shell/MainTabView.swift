//
//  MainTabView.swift
//  AssembleAI
//

import SwiftUI

/// Main application shell tab bar container featuring 5 native iOS tab destinations.
struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var selectedTab: Int = 0
    @State private var homePath = NavigationPath()
    @State private var projectsPath = NavigationPath()
    @State private var scanPath = NavigationPath()
    @State private var historyPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Home
            NavigationStack(path: $homePath) {
                HomeView(
                    onSelectProjectsTab: {
                        selectedTab = 1
                    },
                    onSelectProject: { project in
                        homePath.append(AppRouteDetail(project: project))
                    }
                )
                .navigationDestination(for: AppRouteDetail.self) { detail in
                    ProjectDetailView(
                        project: detail.project,
                        onStartAssembly: { project in
                            homePath.append(AppRouteAssembly(project: project))
                        }
                    )
                }
                .navigationDestination(for: AppRouteAssembly.self) { assembly in
                    AssemblyContainerView(project: assembly.project)
                }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            // Tab 1: Projects
            NavigationStack(path: $projectsPath) {
                ProjectsView(
                    onSelectProject: { project in
                        projectsPath.append(AppRouteDetail(project: project))
                    }
                )
                .navigationDestination(for: AppRouteDetail.self) { detail in
                    ProjectDetailView(
                        project: detail.project,
                        onStartAssembly: { project in
                            projectsPath.append(AppRouteAssembly(project: project))
                        }
                    )
                }
                .navigationDestination(for: AppRouteAssembly.self) { assembly in
                    AssemblyContainerView(project: assembly.project)
                }
            }
            .tabItem {
                Label("Projects", systemImage: "folder.fill")
            }
            .tag(1)
            
            // Tab 2: Scan
            NavigationStack(path: $scanPath) {
                ScanPlaceholderView()
            }
            .tabItem {
                Label("Scan", systemImage: "viewfinder")
            }
            .tag(2)
            
            // Tab 3: History
            NavigationStack(path: $historyPath) {
                HistoryPlaceholderView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(3)
            
            // Tab 4: Profile
            NavigationStack(path: $profilePath) {
                ProfilePlaceholderView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(4)
        }
        .tint(.assembleBrandPrimary)
    }
}

// MARK: - Local Navigation Hashable Wrappers

struct AppRouteDetail: Hashable {
    let project: AssemblyProject
}

struct AppRouteAssembly: Hashable {
    let project: AssemblyProject
}

#Preview("Main Tab View") {
    MainTabView()
        .environmentObject(AppRouter())
        .environmentObject(SupabaseAuthService())
}
