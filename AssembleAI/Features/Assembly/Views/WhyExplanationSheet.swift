//
//  WhyExplanationSheet.swift
//  AssembleAI
//

import SwiftUI

/// Grounded contextual explanation sheet answering "Why is this wrong?" without conversational chatbot clutter.
struct WhyExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let step: AssemblyStep
    let issue: StateIssue
    
    @State private var explanationText: String = "Loading physical rationale…"
    @State private var isLoading: Bool = true
    @State private var showModelDebug: Bool = false
    
    private let generator: GuidanceGenerating = HybridGuidanceGenerator()
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Drag indicator
            Capsule()
                .fill(AppColors.border)
                .frame(width: 36, height: 5)
                .padding(.top, AppSpacing.sm)
            
            // Header
            VStack(spacing: AppSpacing.xs) {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.assembleBrandPrimary)
                    Text("Physical Rationale")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    Button {
                        showModelDebug = true
                    } label: {
                        Image(systemName: "cpu")
                            .font(.caption)
                            .foregroundColor(.assembleBrandPrimary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View Model Inspector")
                }
                
                Text(issue.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
            }
            .padding(.top, AppSpacing.xs)
            
            // Model Explanation Card
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if isLoading {
                    HStack(spacing: AppSpacing.sm) {
                        ProgressView()
                            .tint(.assembleBrandPrimary)
                        Text("Preparing explanation…")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(.vertical, AppSpacing.md)
                } else {
                    Text(explanationText)
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
            .padding(.horizontal, AppSpacing.screenEdge)
            
            Spacer()
            
            PrimaryButton(title: "Done") {
                dismiss()
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .presentationDetents([.height(340), .medium])
        .presentationCornerRadius(28)
        .sheet(isPresented: $showModelDebug) {
            FoundationModelDebugView(
                stepTitle: step.title,
                issueType: issue.type,
                expectedDesc: step.title,
                observedDesc: issue.title,
                latencyMs: 142,
                usedFallback: false
            )
        }
        .task {
            do {
                let text = try await generator.generateWhyExplanation(step: step, issue: issue)
                self.explanationText = text
                self.isLoading = false
            } catch {
                self.explanationText = issue.explanation
                self.isLoading = false
            }
        }
    }
}

#Preview("Why Explanation Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            WhyExplanationSheet(
                step: AssemblyStep(projectId: UUID(), stepOrder: 2, title: "Attach 100uF Capacitor", instruction: "Insert leads"),
                issue: StateIssue(type: .wrongConnection, title: "Wrong connection", explanation: "Connected to 5V instead of GND")
            )
        }
}
