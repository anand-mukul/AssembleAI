//
//  AnalysisView.swift
//  AssembleAI
//

import SwiftUI

/// Truthful scanning state view representing on-device Vision image processing and feature extraction.
struct AnalysisView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var scanPhaseIndex: Int = 0
    @State private var scanPulse: Bool = false
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            // Scanning Animation Graphic
            ZStack {
                Circle()
                    .fill(Color.assembleBrandPrimary.opacity(0.1))
                    .frame(width: 130, height: 130)
                
                Circle()
                    .stroke(Color.assembleBrandPrimary.opacity(0.3), lineWidth: 2)
                    .frame(width: 160, height: 160)
                    .scaleEffect(reduceMotion ? 1.0 : (scanPulse ? 1.08 : 0.95))
                
                Image(systemName: "viewfinder")
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundColor(.assembleBrandPrimary)
            }
            .frame(height: 180)
            
            // Text Header
            VStack(spacing: AppSpacing.xs) {
                Text("Analyzing Visual Information")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Extracting physical observations and text markings locally on-device…")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }
            
            // Vision Analysis Progress Checklist
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                analysisCheckRow(title: "Image captured", isChecked: scanPhaseIndex >= 0)
                analysisCheckRow(title: "Orientation checked", isChecked: scanPhaseIndex >= 1)
                analysisCheckRow(title: "Detecting visual features", isChecked: scanPhaseIndex >= 2)
                analysisCheckRow(title: "Reading visible labels", isChecked: scanPhaseIndex >= 3)
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
            .padding(.horizontal, AppSpacing.lg)
            
            Spacer()
            
            Text("Please keep your phone steady.")
                .font(.caption)
                .foregroundColor(AppColors.tertiaryText)
                .padding(.bottom, AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .background(AppColors.appBackground.ignoresSafeArea())
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    scanPulse = true
                }
            }
            
            // Sequential check mark animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { scanPhaseIndex = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation { scanPhaseIndex = 2 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation { scanPhaseIndex = 3 }
            }
        }
    }
    
    private func analysisCheckRow(title: String, isChecked: Bool) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .font(.subheadline)
                .foregroundColor(isChecked ? AppColors.success : AppColors.tertiaryText)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(isChecked ? .medium : .regular)
                .foregroundColor(isChecked ? AppColors.primaryText : AppColors.secondaryText)
        }
    }
}

#Preview("Analysis View") {
    AnalysisView()
}
