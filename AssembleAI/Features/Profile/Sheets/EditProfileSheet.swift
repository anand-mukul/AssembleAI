//
//  EditProfileSheet.swift
//  AssembleAI
//

import SwiftUI

/// Native modal sheet allowing users to customize their display name, avatar SF Symbol, and theme tint color.
struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    
    @State private var tempName: String = ""
    @State private var selectedAvatar: String = "person.crop.circle.fill"
    @State private var selectedColorHex: String = "#0A84FF"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Avatar Live Preview
                    VStack(spacing: AppSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(activeColor.opacity(0.15))
                                .frame(width: 96, height: 96)
                                .overlay(
                                    Circle()
                                        .strokeBorder(activeColor.opacity(0.4), lineWidth: 2)
                                )
                            
                            Image(systemName: selectedAvatar)
                                .font(.system(size: 44, weight: .medium))
                                .foregroundColor(activeColor)
                        }
                        .padding(.top, AppSpacing.sm)
                        
                        Text("AVATAR PREVIEW")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.secondaryText)
                            .tracking(1.0)
                    }
                    
                    // Display Name Field Card
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("DISPLAY NAME")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.secondaryText)
                            .tracking(1.0)
                        
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "pencil")
                                .foregroundColor(AppColors.tertiaryText)
                            
                            TextField("Enter your name", text: $tempName)
                                .font(.body)
                                .foregroundColor(AppColors.primaryText)
                                .autocorrectionDisabled()
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppColors.secondaryGroupedBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AppColors.border.opacity(0.4), lineWidth: 1)
                        )
                    }
                    
                    // Avatar Symbol Selector Card
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("CHOOSE AVATAR ICON")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.secondaryText)
                            .tracking(1.0)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(ProfileViewModel.availableAvatarSymbols, id: \.self) { symbol in
                                let isSelected = selectedAvatar == symbol
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedAvatar = symbol
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(isSelected ? activeColor.opacity(0.18) : AppColors.secondaryGroupedBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .strokeBorder(isSelected ? activeColor : AppColors.border.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                                            )
                                        
                                        Image(systemName: symbol)
                                            .font(.system(size: 22))
                                            .foregroundColor(isSelected ? activeColor : AppColors.primaryText)
                                    }
                                    .frame(height: 54)
                                }
                                .accessibilityLabel("Avatar icon \(symbol)")
                            }
                        }
                    }
                    
                    // Accent Color Palette
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("ACCENT COLOR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.secondaryText)
                            .tracking(1.0)
                        
                        HStack(spacing: AppSpacing.md) {
                            ForEach(ProfileViewModel.availableColors, id: \.hex) { item in
                                let isSelected = selectedColorHex == item.hex
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedColorHex = item.hex
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 40, height: 40)
                                        
                                        if isSelected {
                                            Circle()
                                                .strokeBorder(Color.white, lineWidth: 3)
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .accessibilityLabel("Color \(item.name)")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.md)
            }
            .background(AppColors.appBackground.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveProfile(
                            newName: tempName,
                            newAvatar: selectedAvatar,
                            newColorHex: selectedColorHex
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(activeColor)
                }
            }
            .onAppear {
                self.tempName = viewModel.displayName
                self.selectedAvatar = viewModel.avatarSymbol
                self.selectedColorHex = viewModel.avatarColorHex
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(28)
    }
    
    private var activeColor: Color {
        ProfileViewModel.availableColors.first { $0.hex == selectedColorHex }?.color ?? Color.assembleBrandPrimary
    }
}

#Preview("Edit Profile Sheet") {
    EditProfileSheet(viewModel: ProfileViewModel())
}
