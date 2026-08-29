//
//  HistoryPlaceholderView.swift
//  AssembleAI
//

import SwiftUI

/// Simple, elegant placeholder for the History tab destination.
struct HistoryPlaceholderView: View {
    var body: some View {
        VStack(spacing: AppSpacing.mdLg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppColors.secondaryBackground)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundColor(AppColors.secondaryText)
            }
            
            VStack(spacing: AppSpacing.xs) {
                Text("Assembly History")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Your completed assembly sessions and verification logs will appear here.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("History Placeholder View") {
    NavigationStack {
        HistoryPlaceholderView()
    }
}
