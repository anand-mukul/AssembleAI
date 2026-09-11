import SwiftUI

/// Pre-assembly preparation screen ensuring workspace, components, and camera readiness before inspection starts.
struct AssemblyIntroView: View {
    let project: AssemblyProject
    let onBegin: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(project.title.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundColor(.assembleBrandPrimary)
                        .tracking(0.5)
                    
                    Text("Ready to build?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack(spacing: AppSpacing.sm) {
                        Label("\(project.totalSteps) guided steps", systemImage: "list.bullet")
                        Text("·")
                            .foregroundColor(AppColors.tertiaryText)
                        Label("~\(project.estimatedMinutes) minutes", systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                }
                .padding(.top, AppSpacing.sm)
                
                // Preparation Checklist Card
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("PREPARATION CHECK")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 0) {
                        checklistRow(
                            title: "Components ready",
                            subtitle: "All required hardware is on hand",
                            icon: "checkmark",
                            tint: AppColors.badgeGreen
                        )
                        
                        Divider()
                            .padding(.leading, 58)
                        
                        checklistRow(
                            title: "Camera available",
                            subtitle: "Camera access is operational",
                            icon: "camera.fill",
                            tint: AppColors.badgeBlue
                        )
                        
                        Divider()
                            .padding(.leading, 58)
                        
                        checklistRow(
                            title: "Workspace visible",
                            subtitle: "Assembly area is clean and well-lit",
                            icon: "lightbulb.fill",
                            tint: AppColors.badgeOrange
                        )
                    }
                    .appCard(padding: 0)
                }
                
                // Before We Begin Tip Card
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("BEFORE WE BEGIN")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 4)
                    
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.assembleBrandPrimary)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Optimal Scanning")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("Make sure your components are visible and your workspace has enough light. The visual assistant will guide you step by step.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.secondaryText)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .appCard()
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            topNavigationBar
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionDock
        }
    }
    
    // MARK: - Top Navigation Bar
    
    private var topNavigationBar: some View {
        HStack {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onBack()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.body)
                }
                .foregroundColor(AppColors.primaryText)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Back to project details")
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.borderSubtle)
                .frame(height: 0.5)
        }
    }
    
    // MARK: - Bottom Action Dock
    
    private var bottomActionDock: some View {
        VStack(spacing: 0) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onBegin()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Begin")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(AppColors.premiumButtonForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppColors.premiumButtonBackground)
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .touchTarget()
            .accessibilityLabel("Begin assembly session")
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.borderSubtle)
                .frame(height: 0.5)
        }
    }
    
    // MARK: - Checklist Item Row
    
    private func checklistRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: AppSpacing.md) {
            SemanticIconBadge(systemName: icon, tintColor: tint)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(AppColors.primaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.badgeGreen)
                .padding(6)
                .background(
                    Circle()
                        .fill(AppColors.badgeGreen.opacity(0.12))
                )
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Assembly Intro View") {
    AssemblyIntroView(
        project: PreviewProjectFixture.previewProject,
        onBegin: {},
        onBack: {}
    )
}
