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
                    VStack(spacing: AppSpacing.xs) {
                        ZStack {
                            Circle()
                                .fill(activeColor.opacity(0.12))
                                .frame(width: 88, height: 88)
                                .overlay(
                                    Circle()
                                        .strokeBorder(activeColor.opacity(0.35), lineWidth: 1.5)
                                )
                            
                            Image(systemName: selectedAvatar)
                                .font(.system(size: 38, weight: .medium))
                                .foregroundColor(activeColor)
                        }
                        .padding(.top, AppSpacing.xs)
                    }
                    
                    // Display Name Field Card
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Display Name")
                            .standardSectionHeader()
                        
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
                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                .fill(AppColors.secondaryGroupedBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
                        )
                    }
                    
                    // Avatar Symbol Selector Card
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Choose Avatar Icon")
                            .standardSectionHeader()
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(ProfileViewModel.availableAvatarSymbols, id: \.self) { symbol in
                                let isSelected = selectedAvatar == symbol
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedAvatar = symbol
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                            .fill(isSelected ? activeColor.opacity(0.15) : AppColors.secondaryGroupedBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                                    .strokeBorder(isSelected ? activeColor : AppColors.borderSubtle, lineWidth: isSelected ? 1.5 : 0.5)
                                            )
                                        
                                        Image(systemName: symbol)
                                            .font(.system(size: 20))
                                            .foregroundColor(isSelected ? activeColor : AppColors.primaryText)
                                    }
                                    .frame(height: 50)
                                }
                                .accessibilityLabel("Avatar icon \(symbol)")
                            }
                        }
                    }
                    
                    // Accent Color Palette
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Accent Color")
                            .standardSectionHeader()
                        
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
                                            .frame(width: 36, height: 36)
                                        
                                        if isSelected {
                                            Circle()
                                                .strokeBorder(Color.white, lineWidth: 2.5)
                                                .frame(width: 36, height: 36)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .accessibilityLabel("Color \(item.name)")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.sm)
            }
            .background(AppColors.groupedBackground.ignoresSafeArea())
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
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(AppRadius.sheet)
    }
    
    private var activeColor: Color {
        ProfileViewModel.availableColors.first { $0.hex == selectedColorHex }?.color ?? Color.assembleBrandPrimary
    }
}

#Preview("Edit Profile Sheet") {
    EditProfileSheet(viewModel: ProfileViewModel())
}
