//
//  ScanPlaceholderView.swift
//  AssembleAI
//

import SwiftUI

/// Simple, elegant placeholder for the Scan tab destination.
struct ScanPlaceholderView: View {
    @EnvironmentObject private var router: AppRouter
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.assembleBrandPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "viewfinder")
                    .font(.system(size: 40, weight: .ultraLight))
                    .foregroundColor(.assembleBrandPrimary)
            }
            
            VStack(spacing: AppSpacing.xs) {
                Text("Camera Inspection")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Align physical components within the camera viewfinder to observe and verify assembly state.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }
            
            PrimaryButton(title: "Launch Camera Inspection", iconName: "camera.fill") {
                let defaultStep = AssemblyStep(
                    projectId: UUID(),
                    stepOrder: 1,
                    title: "Attach 10K Resistor to R1 Pin Header",
                    instruction: "Insert resistor leads into R1 slots and verify orientation."
                )
                router.navigateToCamera(step: defaultStep)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Scan Placeholder View") {
    NavigationStack {
        ScanPlaceholderView()
            .environmentObject(AppRouter())
    }
}
