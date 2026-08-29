//
//  AnalyzingView.swift
//  AssembleAI
//

import SwiftUI

/// Visual inspection analysis screen simulating spatial state-aware task verification.
struct AnalyzingView: View {
    @EnvironmentObject private var router: AppRouter
    let step: AssemblyStep
    
    @State private var progress: Double = 0.0
    @State private var analysisPhaseText: String = "Capturing spatial frame..."
    @State private var isCompleted: Bool = false
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Scanning Visual Graphic
            ZStack {
                Circle()
                    .fill(Color.assembleBrandPrimary.opacity(0.12))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .stroke(Color.assembleBrandPrimary.opacity(0.3), lineWidth: 3)
                    .frame(width: 170, height: 170)
                    .scaleEffect(isCompleted ? 1.05 : 1.0)
                
                Image(systemName: isCompleted ? "checkmark.seal.fill" : "sparkles.viewfinder")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(isCompleted ? AppColors.success : .assembleBrandPrimary)
            }
            .padding(.bottom, AppSpacing.md)
            
            // Step Information & Progress Readout
            VStack(spacing: AppSpacing.xs) {
                Text(isCompleted ? "Step Verified" : "Analyzing Assembly State")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(step.title)
                    .font(.headline)
                    .foregroundColor(.assembleBrandPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
                
                Text(analysisPhaseText)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.top, AppSpacing.xs)
            }
            
            // Progress Bar
            VStack(spacing: AppSpacing.xs) {
                ProgressView(value: progress, total: 1.0)
                    .tint(.assembleBrandPrimary)
                    .padding(.horizontal, AppSpacing.xl)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.tertiaryText)
            }
            
            Spacer()
            
            if isCompleted {
                PrimaryButton(title: "Done / Return to Workspace", iconName: "checkmark.circle.fill") {
                    router.transitionToHome()
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            } else {
                Button("Cancel Analysis") {
                    router.pop()
                }
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryText)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startAnalysisSimulation()
        }
    }
    
    private func startAnalysisSimulation() {
        Task {
            // Phase 1: Frame Capture
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation {
                progress = 0.35
                analysisPhaseText = "Evaluating component alignment..."
            }
            
            // Phase 2: State Verification
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation {
                progress = 0.75
                analysisPhaseText = "Verifying physical step status..."
            }
            
            // Phase 3: Completion
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation {
                progress = 1.0
                analysisPhaseText = "Step successfully verified!"
                isCompleted = true
            }
        }
    }
}

#Preview("Analyzing View") {
    AnalyzingView(
        step: AssemblyStep(
            projectId: UUID(),
            stepOrder: 1,
            title: "Attach 10K Resistor to R1 Pin Header",
            instruction: "Insert resistor leads into R1 slots and verify orientation."
        )
    )
    .environmentObject(AppRouter())
}
