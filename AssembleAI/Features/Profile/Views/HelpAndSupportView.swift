//
//  HelpAndSupportView.swift
//  AssembleAI
//

import SwiftUI

/// Comprehensive reference manual, physical assembly diagrams, hardware cheat sheets, and FAQ.
struct HelpAndSupportView: View {
    @State private var expandedSection: Int? = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Header Hero
                VStack(spacing: AppSpacing.xs) {
                    ZStack {
                        Circle()
                            .fill(Color.assembleBrandPrimary.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "book.pages.fill")
                            .font(.title2)
                            .foregroundColor(.assembleBrandPrimary)
                    }
                    
                    Text("Hardware Assembly Reference")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("Standard conventions, pinouts, and troubleshooting guidance.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.top, AppSpacing.sm)
                
                // Section 1: Breadboard Mechanics
                referenceCard(
                    title: "BREADBOARD ARCHITECTURE",
                    icon: "square.grid.3x3.topleft.filled",
                    color: .blue
                ) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("• Tie-Point Rows (A–E, F–J): Connected horizontally across each row number. Inserting two leads into the same numbered row (e.g. 10A and 10B) connects them electrically.")
                            .font(.caption)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("• Power Rails (+ and -): Run vertically down the side columns. Red (+) is positive voltage (5V/3.3V), Blue/Black (-) is ground (GND).")
                            .font(.caption)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                
                // Section 2: Component Polarity
                referenceCard(
                    title: "COMPONENT POLARITY RULES",
                    icon: "bolt.horizontal.fill",
                    color: .orange
                ) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        polarityRow(component: "LED", rule: "Long lead = Anode (+) / Short lead = Cathode (-)")
                        polarityRow(component: "Capacitor", rule: "Electrolytic: White stripe indicates negative (-) lead")
                        polarityRow(component: "Resistor", rule: "Non-polarized: Can be placed in either orientation")
                        polarityRow(component: "Diode", rule: "Silver band indicates cathode (-) negative terminal")
                    }
                }
                
                // Section 3: Vision Scanning Tips
                referenceCard(
                    title: "CAMERA SCANNING TIPS",
                    icon: "viewfinder",
                    color: .purple
                ) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("1. Adequate Lighting: Ensure the workspace is well-lit without harsh glare or deep cast shadows.")
                            .font(.caption)
                            .foregroundColor(AppColors.primaryText)
                        Text("2. Perpendicular Angle: Hold your phone 15–20 cm directly above the board.")
                            .font(.caption)
                            .foregroundColor(AppColors.primaryText)
                        Text("3. Keep Steady: Hold the device still for 1 second during scan.")
                            .font(.caption)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                
                // Section 4: FAQ
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("FREQUENTLY ASKED QUESTIONS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 4)
                        .tracking(1.0)
                    
                    VStack(spacing: AppSpacing.sm) {
                        faqItem(
                            index: 0,
                            question: "Does AssembleAI require an internet connection?",
                            answer: "No. All core computer vision recognition and physical state verification run 100% on-device using Apple Vision framework. Foundation Models also run locally on supported hardware."
                        )
                        
                        faqItem(
                            index: 1,
                            question: "How does AssembleAI verify my circuit?",
                            answer: "AssembleAI compares visual observations (detected OCR component markings, pin connections, coordinates) against a formal state contract specification for each step."
                        )
                        
                        faqItem(
                            index: 2,
                            question: "What if the scanner marks my step uncertain?",
                            answer: "Uncertain status means visual evidence was below threshold (e.g. low light, fingers occluding components). Move closer, ensure good lighting, and tap Scan Again."
                        )
                    }
                }
                
                // App Version Footer
                VStack(spacing: 2) {
                    Text("AssembleAI v\(AppConfig.appVersion) (Build \(AppConfig.buildNumber))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                    Text("Apple Vision + SwiftData + Foundation Models")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(AppColors.tertiaryText)
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.md)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Assembly Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func referenceCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.secondaryText)
                    .tracking(1.0)
            }
            
            content()
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColors.border.opacity(0.35), lineWidth: 1)
        )
    }
    
    private func polarityRow(component: String, rule: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(component)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
            Text(rule)
                .font(.caption)
                .foregroundColor(AppColors.secondaryText)
        }
    }
    
    private func faqItem(index: Int, question: String, answer: String) -> some View {
        let isExpanded = expandedSection == index
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expandedSection = isExpanded ? nil : index
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineSpacing(3)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppColors.border.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview("Help & Support View") {
    NavigationStack {
        HelpAndSupportView()
    }
}
