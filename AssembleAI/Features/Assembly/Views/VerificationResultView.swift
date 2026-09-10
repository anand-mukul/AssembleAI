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
    @State private var showDetailsSheet: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                // Result Hero Graphic
                ZStack {
                    Circle()
                        .fill(heroColor.opacity(0.10))
                        .frame(width: 96, height: 96)
                    
                    Circle()
                        .stroke(heroColor.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 116, height: 116)
                    
                    Image(systemName: heroIcon)
                        .font(.system(size: 46, weight: .light))
                        .foregroundColor(heroColor)
                        .scaleEffect(iconScale)
                }
                .frame(height: 124)
                .padding(.top, AppSpacing.sm)
                
                // Title & Subtitle
                VStack(spacing: AppSpacing.xs) {
                    Text(heroTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack(spacing: AppSpacing.xs) {
                        BadgeView(
                            text: badgeText,
                            color: heroColor
                        )
                        Button {
                            showDetailsSheet = true
                        } label: {
                            HStack(spacing: 3) {
                                BadgeView(
                                    text: "\(Int(result.confidence * 100))% Confidence",
                                    color: .assembleBrandPrimary
                                )
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundColor(.assembleBrandPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Assessment Card
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Assessment")
                        .standardSectionHeader()
                    
                    Text(result.explanation)
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
                
                // Uncertain State Suggestions Card
                if result.status == .uncertain {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Tips for Better Scanning")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.warning)
                            .textCase(.uppercase)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                                    .font(.caption)
                                    .foregroundColor(AppColors.warning)
                                Text("Move closer to the component area")
                            }
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "sun.max.fill")
                                    .font(.caption)
                                    .foregroundColor(AppColors.warning)
                                Text("Ensure your workspace has bright, even lighting")
                            }
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "viewfinder")
                                    .font(.caption)
                                    .foregroundColor(AppColors.warning)
                                Text("Keep the workpiece centered inside the frame")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard(backgroundColor: AppColors.warning.opacity(0.08), borderColor: AppColors.warning.opacity(0.3))
                }
                
                // If incorrect: show quick expected vs detected summary
                if result.status == .incorrect {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Detected State")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.error)
                            .textCase(.uppercase)
                        
                        Text(result.detectedDescription)
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard(backgroundColor: AppColors.error.opacity(0.06), borderColor: AppColors.error.opacity(0.2))
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionView
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .sheet(isPresented: $showWhySheet) {
            WhyExplanationSheet(
                step: currentStep ?? AssemblyStep(projectId: UUID(), stepOrder: 1, title: "Assembly Step", instruction: "Follow instructions"),
                issue: result.primaryIssue ?? StateIssue(type: .wrongPosition, title: heroTitle, explanation: result.explanation)
            )
        }
        .sheet(isPresented: $showDetailsSheet) {
            VerificationDetailsSheet(
                result: result,
                stepTitle: currentStep?.title ?? "Assembly Step"
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
    
    // MARK: - Sticky Bottom Actions
    
    private var bottomActionView: some View {
        VStack(spacing: AppSpacing.sm) {
            if result.status == .correct {
                PrimaryButton(title: "Continue", iconName: "arrow.right") {
                    onContinue()
                }
            } else if result.status == .uncertain {
                PrimaryButton(title: "Scan Again", iconName: "camera") {
                    onRetry()
                }
            } else {
                VStack(spacing: AppSpacing.sm) {
                    PrimaryButton(title: "Show Me How to Fix", iconName: "wrench.and.screwdriver") {
                        onShowErrorGuidance()
                    }
                    
                    HStack(spacing: AppSpacing.sm) {
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
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        
                        SecondaryButton(title: "Try Again", iconName: "arrow.clockwise") {
                            onRetry()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(AppColors.separator),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
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
        case .correct: return "Step Verified"
        case .incorrect: return "Attention Needed"
        case .uncertain: return "Uncertain Evidence"
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
