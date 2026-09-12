//
//  AppHaptics.swift
//  AssembleAI
//
//  Centralized haptic feedback utility that safely guards against
//  iOS Simulator missing hardware profile errors (CHHapticPattern / hapticpatternlibrary.plist)
//  and respects the user's haptic feedback preferences.
//

import UIKit

/// Safe, simulator-guarded haptic feedback utility.
enum AppHaptics {
    /// Triggers an impact feedback event (light, medium, heavy, rigid, soft).
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        #if !targetEnvironment(simulator)
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    /// Triggers a notification feedback event (success, warning, error).
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if !targetEnvironment(simulator)
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
        #endif
    }
    
    /// Triggers a selection feedback event (picker ticks, tab switches).
    static func selection() {
        #if !targetEnvironment(simulator)
        guard isHapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }
    
    private static var isHapticsEnabled: Bool {
        if UserDefaults.standard.object(forKey: "app_haptic_feedback") != nil {
            return UserDefaults.standard.bool(forKey: "app_haptic_feedback")
        }
        return true
    }
}
