//
//  NotificationsSettingsView.swift
//  AssembleAI
//

import SwiftUI
import UserNotifications

/// Notifications configuration screen managing assembly session alerts, daily building streak reminders, and sound FX.
struct NotificationsSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var systemPermissionStatus: String = "Checking…"
    
    var body: some View {
        ZStack {
            GradientAtmosphereBackground(intensity: .subtle)
            
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Permission Status Card
                    HStack(spacing: AppSpacing.md) {
                        GradientIconBadge(
                            iconName: "bell.badge.fill",
                            size: 42,
                            iconSize: 18,
                            colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd]
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iOS Notification Status")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primaryText)
                            Text(systemPermissionStatus)
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Button("Manage") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.assembleBrandPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.assembleBrandPrimary.opacity(0.12))
                        )
                    }
                    .appCard()
                    
                    // Notification Preferences
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Notification Preferences")
                            .sectionHeaderStyle()
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            Toggle(isOn: $viewModel.remindersEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Assembly Reminders")
                                        .font(.body)
                                        .foregroundColor(AppColors.primaryText)
                                    Text("Nudges to resume incomplete assembly projects.")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                }
                            }
                            .padding(AppSpacing.md)
                            
                            Divider().opacity(0.3).padding(.horizontal, AppSpacing.md)
                            
                            Toggle(isOn: $viewModel.streakRemindersEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Daily Building Streak")
                                        .font(.body)
                                        .foregroundColor(AppColors.primaryText)
                                    Text("Daily prompt to learn electronics assembly.")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                }
                            }
                            .padding(AppSpacing.md)
                        }
                        .appCard(padding: 0)
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkPermissionStatus()
        }
        .onChange(of: viewModel.remindersEnabled) { _, isEnabled in
            handleNotificationToggleChange(enabled: isEnabled)
        }
        .onChange(of: viewModel.streakRemindersEnabled) { _, isEnabled in
            handleNotificationToggleChange(enabled: isEnabled)
        }
    }
    
    private func handleNotificationToggleChange(enabled: Bool) {
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    self.checkPermissionStatus()
                    if granted {
                        self.scheduleDailyStreakReminder()
                    }
                }
            }
        } else if !viewModel.remindersEnabled && !viewModel.streakRemindersEnabled {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    private func scheduleDailyStreakReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time to Build with AssembleAI"
        content.body = "Keep your electronics assembly streak alive. Pick up your next project step!"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "com.mukul.assembleai.daily_streak", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    self.systemPermissionStatus = "Enabled in iOS Settings"
                case .denied:
                    self.systemPermissionStatus = "Disabled in iOS Settings"
                case .notDetermined:
                    self.systemPermissionStatus = "Not Requested Yet"
                case .provisional:
                    self.systemPermissionStatus = "Provisional Delivery"
                default:
                    self.systemPermissionStatus = "Enabled"
                }
            }
        }
    }
}

#Preview("Notifications Settings") {
    NavigationStack {
        NotificationsSettingsView(viewModel: ProfileViewModel())
    }
}
