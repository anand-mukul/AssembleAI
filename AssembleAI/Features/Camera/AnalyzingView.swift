//
//  AnalyzingView.swift
//  AssembleAI
//

import SwiftUI
import UIKit

/// Visual inspection analysis screen evaluating physical step state using `VerificationServiceProtocol`.
struct AnalyzingView: View {
    @EnvironmentObject private var router: AppRouter
    
    let step: AssemblyStep
    var capturedImage: UIImage? = nil
    var verificationService: VerificationServiceProtocol = MockVerificationService()
    
    @State private var progress: Double = 0.0
    @State private var analysisPhaseText: String = "Capturing spatial frame..."
    @State private var result: VerificationResult? = nil
    @State private var isAnalyzing: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: 40)
                
                // Visual Inspection Indicator Graphic
                ZStack {
                    Circle()
                        .fill((result?.isCorrect == false ? AppColors.error : Color.assembleBrandPrimary).opacity(0.12))
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .stroke((result?.isCorrect == false ? AppColors.error : Color.assembleBrandPrimary).opacity(0.3), lineWidth: 3)
                        .frame(width: 170, height: 170)
                    
                    if isAnalyzing {
                        Image(systemName: "sparkles.viewfinder")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(.assembleBrandPrimary)
                    } else if let res = result {
                        Image(systemName: res.isCorrect ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(res.isCorrect ? AppColors.success : AppColors.error)
                    }
                }
                
                // Step Information Header
                VStack(spacing: AppSpacing.xs) {
                    if isAnalyzing {
                        Text("Analyzing Assembly State")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                    } else if let res = result {
                        HStack(spacing: AppSpacing.xs) {
                            BadgeView(
                                text: res.isCorrect ? "STEP CORRECT" : "STEP INCORRECT",
                                color: res.isCorrect ? AppColors.success : AppColors.error
                            )
                            BadgeView(
                                text: "\(Int(res.confidence * 100))% CONFIDENCE",
                                color: .indigo
                            )
                        }
                    }
                    
                    Text(step.title)
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                    
                    if isAnalyzing {
                        Text(analysisPhaseText)
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                // Progress Bar during analysis
                if isAnalyzing {
                    VStack(spacing: AppSpacing.xs) {
                        ProgressView(value: progress, total: 1.0)
                            .tint(.assembleBrandPrimary)
                            .padding(.horizontal, AppSpacing.xl)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    .padding(.top, AppSpacing.md)
                }
                
                // Verification Result Card Card
                if let res = result {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DETECTED STATE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.secondaryText)
                            Text(res.detectedDescription)
                                .font(.subheadline)
                                .foregroundColor(AppColors.primaryText)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EXPECTED CONTRACT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.secondaryText)
                            Text(res.expectedDescription)
                                .font(.subheadline)
                                .foregroundColor(AppColors.primaryText)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ANALYSIS EXPLANATION")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.secondaryText)
                            Text(res.explanation)
                                .font(.subheadline)
                                .foregroundColor(res.isCorrect ? AppColors.secondaryText : AppColors.error)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppColors.secondaryGroupedBackground)
                            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(res.isCorrect ? AppColors.border.opacity(0.4) : AppColors.error.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal, AppSpacing.sm)
                }
                
                Spacer(minLength: 40)
                
                // Bottom Actions
                if !isAnalyzing {
                    VStack(spacing: AppSpacing.md) {
                        PrimaryButton(
                            title: result?.isCorrect == true ? "Proceed to Next Step" : "Retry Inspection",
                            iconName: result?.isCorrect == true ? "arrow.right.circle.fill" : "arrow.clockwise"
                        ) {
                            router.transitionToHome()
                        }
                        
                        SecondaryButton(title: "Return to Workspace", iconName: "house.fill") {
                            router.transitionToHome()
                        }
                    }
                    .padding(.bottom, AppSpacing.lg)
                } else {
                    Button("Cancel Analysis") {
                        router.pop()
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            performVerification()
        }
    }
    
    private func performVerification() {
        Task {
            // Animate initial progress UI
            withAnimation {
                progress = 0.4
                analysisPhaseText = "Evaluating component alignment..."
            }
            
            // Execute decoupled verification service query
            do {
                let verificationResult = try await verificationService.verifyStep(step, image: capturedImage)
                
                withAnimation {
                    progress = 1.0
                    self.result = verificationResult
                    self.isAnalyzing = false
                }
            } catch {
                withAnimation {
                    progress = 1.0
                    self.result = VerificationResult(
                        status: .incorrect,
                        confidence: 0.0,
                        detectedDescription: "Analysis failed",
                        expectedDescription: step.title,
                        explanation: "An error occurred during visual analysis."
                    )
                    self.isAnalyzing = false
                }
            }
        }
    }
}

#Preview("Analyzing View - Correct (Step 1)") {
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

#Preview("Analyzing View - Incorrect (Step 2)") {
    AnalyzingView(
        step: AssemblyStep(
            projectId: UUID(),
            stepOrder: 2,
            title: "Attach 100uF Capacitor to C2 Header",
            instruction: "Insert capacitor leads observing polarity."
        )
    )
    .environmentObject(AppRouter())
}
