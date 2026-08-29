//
//  AssemblyCompletedView.swift
//  AssembleAI
//

import SwiftUI
import UIKit

/// Final assembly project completion view featuring hero seal icon, session metrics, and summary sheet launcher.
struct AssemblyCompletedView: View {
    let project: AssemblyProject
    let session: AssemblySession
    let onDone: () -> Void
    
    @State private var showSummarySheet = false
    @State private var sealAppeared = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: 40)
                
                // Hero Seal Graphic
                ZStack {
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.12))
                        .frame(width: 130, height: 130)
                    
                    Circle()
                        .stroke(Color.assembleBrandPrimary.opacity(0.3), lineWidth: 2)
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 68, weight: .light))
                        .foregroundColor(.assembleBrandPrimary)
                        .scaleEffect(sealAppeared ? 1.0 : 0.7)
                }
                .frame(height: 180)
                
                // Title
                VStack(spacing: AppSpacing.xs) {
                    Text("Assembly Complete")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(project.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.assembleBrandPrimary)
                    
                    Text("\(project.totalSteps) / \(project.totalSteps) steps verified")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                // Stats Card Grid
                HStack(spacing: AppSpacing.md) {
                    statTile(title: "TIME", value: session.timeElapsedText, icon: "clock")
                    statTile(title: "ATTEMPTS", value: "\(session.attempts)", icon: "viewfinder")
                    statTile(title: "CORRECTIONS", value: "\(session.errors)", icon: "wrench.and.screwdriver")
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppColors.secondaryGroupedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColors.border.opacity(0.3), lineWidth: 1)
                )
                
                // Great Work Callout
                VStack(spacing: 4) {
                    Text("Great work.")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                    Text("All physical components have been verified locally on-device.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }
                .padding(.vertical, AppSpacing.sm)
                
                Spacer(minLength: 32)
                
                // Bottom CTAs
                VStack(spacing: AppSpacing.mdSm) {
                    SecondaryButton(title: "View Summary", iconName: "chart.bar.doc.horizontal") {
                        showSummarySheet = true
                    }
                    
                    PrimaryButton(title: "Done", iconName: "checkmark") {
                        onDone()
                    }
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .sheet(isPresented: $showSummarySheet) {
            AssemblySummaryView(project: project, session: session, onDone: {
                showSummarySheet = false
            })
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                sealAppeared = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Assembly complete for \(project.title). \(project.totalSteps) steps verified. Time \(session.timeElapsedText).")
    }
    
    private func statTile(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.assembleBrandPrimary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
            
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Assembly Completed View") {
    AssemblyCompletedView(
        project: MockProjectData.sampleProjects[0],
        session: AssemblySession(projectId: UUID(), attempts: 10, errors: 2),
        onDone: {}
    )
}
