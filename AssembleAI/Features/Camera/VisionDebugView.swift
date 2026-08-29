//
//  VisionDebugView.swift
//  AssembleAI
//

import SwiftUI
import UIKit

/// Development-only debug screen rendering structured `VisualObservation`, Expected State vs Observed State, and `StateComparison` evaluation.
struct VisionDebugView: View {
    let image: UIImage?
    let observation: VisualObservation
    let onContinue: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                HStack {
                    BadgeView(text: "OPTICAL INSPECTION HUD", color: .assembleBrandPrimary)
                    Spacer()
                    Text("\(Int(observation.processingTimeMs)) ms")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.top, AppSpacing.sm)
                
                Text("Visual Observation")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                // Image Preview
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(AppColors.border.opacity(0.4), lineWidth: 1)
                        )
                }
                
                // Metadata Summary
                HStack(spacing: AppSpacing.md) {
                    metadataTile(title: "DIMENSIONS", value: "\(Int(observation.imageSize.width)) × \(Int(observation.imageSize.height))")
                    metadataTile(title: "TEXT MARKS", value: "\(observation.detectedText.count)")
                    metadataTile(title: "REGIONS", value: "\(observation.regions.count)")
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.secondaryGroupedBackground)
                )
                
                // Recognized Text List
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("DETECTED TEXT MARKINGS (\(observation.detectedText.count))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                    
                    if observation.detectedText.isEmpty {
                        Text("No component text markings detected in frame.")
                            .font(.caption)
                            .foregroundColor(AppColors.tertiaryText)
                    } else {
                        ForEach(observation.detectedText) { text in
                            HStack {
                                Text("\"\(text.text)\"")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.primaryText)
                                Spacer()
                                Text("\(Int(text.confidence * 100))% conf")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.secondaryGroupedBackground)
                )
                
                // State Comparison Section
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("STATE COMPARISON ENGINE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                    
                    StateComparisonCard(
                        expectedText: "220Ω Resistor (Row 10 → Row 15)",
                        observedText: observation.hasText ? observation.detectedText.map(\.text).joined(separator: ", ") : "No explicit text markers",
                        issueTitle: observation.hasText ? nil : "Insufficient evidence",
                        issueType: observation.hasText ? nil : .insufficientVisualEvidence
                    )
                }
                
                PrimaryButton(title: "Continue to Verification", iconName: "arrow.right") {
                    onContinue()
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
    }
    
    private func metadataTile(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Vision Debug View") {
    VisionDebugView(
        image: nil,
        observation: VisualObservation(
            imageSize: CGSize(width: 3024, height: 4032),
            detectedText: [
                DetectedText(text: "220 OHM", confidence: 0.94, boundingBox: .zero),
                DetectedText(text: "R1 HEADER", confidence: 0.91, boundingBox: .zero)
            ],
            regions: [
                DetectedRegion(label: "Breadboard Slot #1", confidence: 0.88, boundingBox: .zero)
            ],
            processingTimeMs: 142.5
        ),
        onContinue: {}
    )
}
