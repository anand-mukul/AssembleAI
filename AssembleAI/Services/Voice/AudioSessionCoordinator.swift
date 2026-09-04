//
//  AudioSessionCoordinator.swift
//  AssembleAI
//

import Foundation
import AVFoundation
import Combine

/// Centralized manager for iOS `AVAudioSession` configuration and hardware route coordination.
///
/// Guarantees that simultaneous live camera streaming, background Voice Activity Detection (VAD),
/// speech recognition, and spoken text-to-speech output operate harmoniously without category conflicts.
@MainActor
final class AudioSessionCoordinator: NSObject, ObservableObject {
    static let shared = AudioSessionCoordinator()
    
    @Published private(set) var isSessionActive: Bool = false
    @Published private(set) var isHeadphonesConnected: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil
    
    private override init() {
        super.init()
        #if os(iOS)
        registerNotifications()
        checkCurrentRoute()
        #endif
    }
    
    // MARK: - Setup & Activation
    
    /// Activates `.playAndRecord` audio session tailored for workbench hands-free tutoring.
    func activateWorkbenchAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            // Options:
            // - defaultToSpeaker: plays through device speakers rather than phone earpiece
            // - allowBluetoothHFP: supports hands-free Bluetooth headsets / AirPods
            // - duckOthers: lowers background music/podcasts
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            self.isSessionActive = true
            self.lastErrorMessage = nil
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
        #endif
    }
    
    /// Deactivates the audio session when leaving the camera / assembly experience.
    func deactivateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            self.isSessionActive = false
        } catch {
            self.lastErrorMessage = error.localizedDescription
        }
        #endif
    }
    
    // MARK: - Notifications & Route Monitoring
    
    #if os(iOS)
    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        checkCurrentRoute()
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            self.isSessionActive = false
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? activateWorkbenchAudioSession()
                }
            }
        @unknown default:
            break
        }
    }
    
    private func checkCurrentRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        let hasHeadphones = route.outputs.contains { output in
            output.portType == .headphones ||
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothHFP ||
            output.portType == .bluetoothLE
        }
        self.isHeadphonesConnected = hasHeadphones
    }
    #endif
}
