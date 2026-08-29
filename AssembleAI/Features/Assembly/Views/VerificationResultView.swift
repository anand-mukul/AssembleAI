//
//  VerificationResultView.swift
//  AssembleAI
//

import SwiftUI
import UIKit

/// Verification outcome screen presenting pass/fail/uncertain analysis results with contextual "Why?" explanations.
struct VerificationResultView: View {
    let result: VerificationResult
    var currentStep: AssemblyStep? = nil
    let onContinue: () -> Void
    let onShowErrorGuidance: () -> Void
    let onRetry: () -> Void
    
    @State private var iconScale: CGFloat = 0.8
    @State private var showWhySheet: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: 40)
                
                // Result Hero Graphic
                ZStack {
                    Circle()
                        .fill(heroColor.opacity(0.12))
                        .frame(width: 130, height: 130)
                    
                    Circle()
                        .stroke(heroColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: heroIcon)
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(heroColor)
                        .scaleEffect(iconScale)
                }
                .frame(height: 180)
                
                // Title & Subtitle
                VStack(spacing: AppSpacing.xs) {
                    Text(heroTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack(spacing: AppSpacing.xs) {
                        BadgeView(
                            text: badgeText,
                            color: heroColor
                        )
                        BadgeView(
                            text: "\(Int(result.confidence * 100))% CONFIDENCE",
                            color: .indigo
                        )
                    }
                }
                
                // Assessment Card
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("ASSESSMENT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.tertiaryText)
                        .tracking(1.0)
                    
                    Text(result.explanation)
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.secondaryGroupedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppColors.border.opacity(0.3), lineWidth: 1)
                )
                
                // Uncertain State Suggestions Card
                if result.status == .uncertain {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("TIPS FOR BETTER SCANNING")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.warning)
                            .tracking(1.0)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Move closer to the component area")
                            Text("• Ensure your workspace has bright, even lighting")
                            Text("• Keep the breadboard centered inside the viewfinder frame")
                        }
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.warning.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppColors.warning.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // If incorrect: show quick expected vs detected summary
                if result.status == .incorrect {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("DETECTED STATE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.error)
                            .tracking(1.0)
                        
                        Text(result.detectedDescription)
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.error.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppColors.error.opacity(0.2), lineWidth: 1)
                    )
                }
                
                Spacer(minLength: 32)
                
                // Bottom CTAs
                if result.status == .correct {
                    PrimaryButton(title: "Continue", iconName: "arrow.right") {
                        onContinue()
                    }
                    .padding(.bottom, AppSpacing.xl)
                } else if result.status == .uncertain {
                    PrimaryButton(title: "Scan Again", iconName: "camera") {
                        onRetry()
                    }
                    .padding(.bottom, AppSpacing.xl)
                } else {
                    VStack(spacing: AppSpacing.mdSm) {
                        PrimaryButton(title: "Show Me How to Fix", iconName: "wrench.and.screwdriver") {
                            onShowErrorGuidance()
                        }
                        
                        Button(action: {
                            showWhySheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "questionmark.circle")
                                Text("Why is this wrong?")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.assembleBrandPrimary)
                        }
                        .padding(.vertical, 4)
                        
                        SecondaryButton(title: "Try Again", iconName: "arrow.clockwise") {
                            onRetry()
                        }
                    }
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .sheet(isPresented: $showWhySheet) {
            WhyExplanationSheet(
                step: currentStep ?? AssemblyStep(projectId: UUID(), stepOrder: 2, title: "Attach Component", instruction: "Follow instructions"),
                issue: StateIssue(type: result.detectedDescription.contains("5V") ? .wrongConnection : .wrongPosition, title: heroTitle, explanation: result.explanation)
            )
        }
        .onAppear {
            let type: UINotificationFeedbackGenerator.FeedbackType
            switch result.status {
            case .correct: type = .success
            case .incorrect: type = .warning
            case .uncertain: type = .warning
            }
            UINotificationFeedbackGenerator().notificationOccurred(type)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                iconScale = 1.0
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Outcome State Helpers
    
    private var heroColor: Color {
        switch result.status {
        case .correct: return AppColors.success
        case .incorrect: return AppColors.error
        case .uncertain: return AppColors.warning
        }
    }
    
    private var heroIcon: String {
        switch result.status {
        case .correct: return "checkmark.seal.fill"
        case .incorrect: return "exclamationmark.triangle.fill"
        case .uncertain: return "questionmark.circle.fill"
        }
    }
    
    private var heroTitle: String {
        switch result.status {
        case .correct: return "Looks good"
        case .incorrect: return "Almost there"
        case .uncertain: return "Need a clearer view"
        }
    }
    
    private var badgeText: String {
        switch result.status {
        case .correct: return "STEP VERIFIED"
        case .incorrect: return "ATTENTION NEEDED"
        case .uncertain: return "UNCERTAIN EVIDENCE"
        }
    }
}

#Preview("Verification Result - Incorrect with Why Button") {
    VerificationResultView(
        result: VerificationResult(
            status: .incorrect,
            confidence: 0.48,
            detectedDescription: "Resistor detected bridging Row 10 to Row 14",
            expectedDescription: "220Ω Resistor placed bridging Row 10 to Row 15",
            explanation: "The resistor lead is inserted into Row 14 instead of Row 15. Shift the right lead one slot over."
        ),
        onContinue: {},
        onShowErrorGuidance: {},
        onRetry: {}
    )
}
