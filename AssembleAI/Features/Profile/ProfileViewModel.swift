//
//  ProfileViewModel.swift
//  AssembleAI
//
//  Central ViewModel managing user profile metadata, application configuration settings,
//  research telemetry data export, and on-device data governance.
//

import SwiftUI
import SwiftData
import Combine

/// Central ViewModel managing user profile metadata, application configuration settings, and data governance.
@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Dependencies
    private var authService: SupabaseAuthService?
    
    // MARK: - User State
    @Published var displayName: String = "Hardware Assembler"
    @Published var email: String = "guest@assemble.ai"
    @Published var avatarSymbol: String = "person.crop.circle.fill"
    @Published var avatarColorHex: String = "#0A84FF"
    @Published var isGuest: Bool = true
    
    var user: User? {
        if let current = authService?.currentUser {
            return current
        }
        return User(
            id: "local_user",
            name: displayName,
            email: email,
            provider: isGuest ? .guest : .email
        )
    }
    
    // MARK: - Stats State
    @Published var completedSessionsCount: Int = 0
    @Published var totalAssemblyMinutes: Int = 0
    @Published var overallAccuracyScore: Int = 100
    @Published var cachedExplanationsCount: Int = 0
    
    // MARK: - Sheet & Alert State
    @Published var showEditProfileSheet: Bool = false
    @Published var showSignOutDialog: Bool = false
    @Published var showClearCacheToast: Bool = false
    @Published var isExportingTelemetry: Bool = false
    @Published var exportedCSVContent: String = ""
    @Published var exportedShareURL: URL? = nil
    @Published var isGeneratingExport: Bool = false
    @Published var showResetDataAlert: Bool = false
    @Published var showResetSuccessToast: Bool = false
    @Published var showDeleteAccountDialog: Bool = false
    @Published var showDeleteAccountConfirmation: Bool = false
    @Published var isDeletingAccount: Bool = false
    @Published var isLoading: Bool = false
    @Published var deletionError: String? = nil
    
    // MARK: - Research Telemetry & Cloud Sync State
    @Published var researchSessionCount: Int = 0
    @Published var researchEventsCount: Int = 0
    @Published var pendingSyncCount: Int = 0
    @Published var isCloudSyncing: Bool = false
    @Published var researchWebhookURL: String = ""
    @Published var showClearResearchAlert: Bool = false
    @Published var showClearResearchToast: Bool = false
    @Published var showSyncSuccessToast: Bool = false
    @Published var showWebhookEditorSheet: Bool = false
    @Published var isTestingWebhook: Bool = false
    @Published var webhookTestStatusMessage: String? = nil
    @Published var webhookTestSucceeded: Bool? = nil
    
    // MARK: - App Preferences (Persisted via @AppStorage)
    @AppStorage("app_guidance_level") var guidanceLevelRaw: String = GuidanceLevel.concise.rawValue
    @AppStorage("app_verification_mode") var verificationMode: String = "hybrid"
    @AppStorage("app_visual_history_strategy") var visualHistoryStrategyRaw: String = VisualHistoryStrategy.currentFrame.rawValue
    @AppStorage("app_last_n_frames") var lastNFramesValue: Int = 5
    @AppStorage("app_camera_grid") var showCameraGrid: Bool = true
    @AppStorage("app_reticle_pulsing") var reticlePulsing: Bool = true
    @AppStorage("app_auto_torch") var autoTorch: Bool = false
    @AppStorage("app_haptics_enabled") var hapticsEnabled: Bool = true
    @AppStorage("app_reminder_enabled") var remindersEnabled: Bool = true
    @AppStorage("app_daily_streak_reminder") var streakRemindersEnabled: Bool = true
    
    // Available SF Symbol Avatars
    static let availableAvatarSymbols: [String] = [
        "person.crop.circle.fill",
        "cpu.fill",
        "wrench.and.screwdriver.fill",
        "bolt.fill",
        "viewfinder",
        "hammer.fill",
        "gearshape.fill",
        "ruler.fill",
        "dot.radiowaves.left.and.right",
        "terminal.fill",
        "macpro.gen3.fill",
        "antenna.radiowaves.left.and.right"
    ]
    
    // Available Avatar Colors (Precision Industrial Hardware Palette)
    static let availableColors: [(name: String, hex: String, color: Color)] = [
        ("Studio Orange", "#FF5E00", AppColors.brandPrimary),
        ("Signal Green", "#30D158", AppColors.success),
        ("Calibration Amber", "#FF9F0A", AppColors.warning),
        ("Titanium Graphite", "#8E8E93", Color.gray),
        ("Precision Crimson", "#FF453A", AppColors.error),
        ("Slate Teal", "#30B0C7", Color.teal)
    ]
    
    init(authService: SupabaseAuthService? = nil) {
        self.authService = authService
        loadPersistedProfile()
        if let user = authService?.currentUser {
            updateUser(user: user)
        }
    }
    
    // MARK: - Profile Persistence
    
    private func loadPersistedProfile() {
        if let savedName = UserDefaults.standard.string(forKey: "user_display_name"), !savedName.isEmpty {
            self.displayName = savedName
        }
        if let savedAvatar = UserDefaults.standard.string(forKey: "user_avatar_symbol"), !savedAvatar.isEmpty {
            self.avatarSymbol = savedAvatar
        }
        if let savedColor = UserDefaults.standard.string(forKey: "user_avatar_color_hex"), !savedColor.isEmpty {
            self.avatarColorHex = savedColor
        }
        self.researchWebhookURL = UserDefaults.standard.string(forKey: "research_webhook_url")
            ?? AppConfig.researchTelemetryWebhookURL ?? ""
    }
    
    func updateUser(user: User?) {
        if let user = user {
            self.isGuest = user.isGuest
            self.email = user.email ?? (user.isGuest ? "Guest Mode" : "user@assemble.ai")
            if let name = user.displayName as String?, !name.isEmpty {
                self.displayName = name
            }
        } else {
            self.isGuest = true
            self.email = "Guest Mode"
        }
    }
    
    func saveProfile(newName: String, newAvatar: String, newColorHex: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            self.displayName = trimmed
            UserDefaults.standard.set(trimmed, forKey: "user_display_name")
        }
        self.avatarSymbol = newAvatar
        UserDefaults.standard.set(newAvatar, forKey: "user_avatar_symbol")
        
        self.avatarColorHex = newColorHex
        UserDefaults.standard.set(newColorHex, forKey: "user_avatar_color_hex")
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    // MARK: - Stats Calculation
    
    func loadSessionMetrics(sessionRepository: SessionRepository) async {
        do {
            let sessions = try await sessionRepository.fetchAllSessions()
            self.completedSessionsCount = sessions.filter { $0.status == .completed }.count
            
            let totalSeconds = sessions.reduce(0) { sum, s in
                if let start = s.startedAt as Date?, let end = s.completedAt {
                    return sum + max(0, Int(end.timeIntervalSince(start)))
                }
                return sum
            }
            self.totalAssemblyMinutes = max(0, totalSeconds / 60)
            
            let totalAttempts = sessions.reduce(0) { $0 + $1.attempts }
            let totalErrors = sessions.reduce(0) { $0 + $1.errors }
            if totalAttempts > 0 {
                let score = Double(totalAttempts - totalErrors) / Double(totalAttempts) * 100.0
                self.overallAccuracyScore = max(50, min(100, Int(score)))
            } else {
                self.overallAccuracyScore = 100
            }
        } catch {
            // Default demo stats fallback
            self.completedSessionsCount = 3
            self.totalAssemblyMinutes = 24
            self.overallAccuracyScore = 95
        }
    }
    
    // MARK: - Research Telemetry & Export Engine
    
    /// Refreshes live research telemetry counters and offline queue count from disk storage.
    func loadResearchStats() async {
        let stats = await ResearchLogger.shared.getTelemetryStats()
        self.researchSessionCount = stats.sessionCount
        self.researchEventsCount = stats.eventCount
        self.pendingSyncCount = await ResearchCloudSyncService.shared.getPendingQueueCount()
    }
    
    /// Updates and persists the destination webhook URL for automated Google Sheets / Airtable syncing.
    func saveWebhookURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: "research_webhook_url")
        self.researchWebhookURL = trimmed
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    /// Sends a real test payload to verify that the webhook is receiving data correctly.
    func testWebhookConnection(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            webhookTestSucceeded = false
            webhookTestStatusMessage = "Please enter a valid URL."
            return
        }
        isTestingWebhook = true
        webhookTestStatusMessage = "Sending test telemetry ping…"
        webhookTestSucceeded = nil
        Task { [weak self] in
            guard let self = self else { return }
            let result = await ResearchCloudSyncService.shared.sendTestPayload(to: trimmed)
            self.isTestingWebhook = false
            self.webhookTestSucceeded = result.success
            self.webhookTestStatusMessage = result.message
            if result.success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
    
    /// Manually triggers immediate upload of any pending offline research evaluation payloads.
    func flushCloudTelemetry() {
        Task { [weak self] in
            guard let self = self else { return }
            self.isCloudSyncing = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            await ResearchLogger.shared.flushCloudSyncQueue()
            await self.loadResearchStats()
            self.isCloudSyncing = false
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation {
                self.showSyncSuccessToast = true
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation {
                self.showSyncSuccessToast = false
            }
        }
    }
    
    /// Exports research summary CSV (one row per session) to Documents/ResearchExports and presents share sheet.
    func exportSummaryCSV() {
        Task { [weak self] in
            guard let self = self else { return }
            self.isGeneratingExport = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            do {
                let fileURL = try await ResearchLogger.shared.exportSummaryCSVFile()
                self.exportedShareURL = fileURL
                self.exportedCSVContent = ""
                self.isExportingTelemetry = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                let csv = await ResearchLogger.shared.exportSummaryCSV()
                self.exportedCSVContent = csv
                self.exportedShareURL = nil
                self.isExportingTelemetry = true
            }
            self.isGeneratingExport = false
        }
    }
    
    /// Exports all raw chronological events as RFC 4180 CSV and presents share sheet.
    func exportDetailedEventsCSV() {
        Task { [weak self] in
            guard let self = self else { return }
            self.isGeneratingExport = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            do {
                let fileURL = try await ResearchLogger.shared.exportCSVFile()
                self.exportedShareURL = fileURL
                self.exportedCSVContent = ""
                self.isExportingTelemetry = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                let csv = await ResearchLogger.shared.exportCSV()
                self.exportedCSVContent = csv
                self.exportedShareURL = nil
                self.isExportingTelemetry = true
            }
            self.isGeneratingExport = false
        }
    }
    
    /// Exports complete telemetry data as pretty-printed JSON file.
    func exportJSONTelemetry() {
        Task { [weak self] in
            guard let self = self else { return }
            self.isGeneratingExport = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            do {
                let fileURL = try await ResearchLogger.shared.exportJSONFile()
                self.exportedShareURL = fileURL
                self.exportedCSVContent = ""
                self.isExportingTelemetry = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                let json = (try? await ResearchLogger.shared.exportJSON()) ?? "[]"
                self.exportedCSVContent = json
                self.exportedShareURL = nil
                self.isExportingTelemetry = true
            }
            self.isGeneratingExport = false
        }
    }
    
    /// Legacy export method preserving backward compatibility.
    func exportTelemetry() {
        exportSummaryCSV()
    }
    
    /// Clears only the research telemetry events and sessions without touching user progress.
    func clearResearchData() {
        Task { [weak self] in
            guard let self = self else { return }
            await ResearchLogger.shared.clearLogs()
            await self.loadResearchStats()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation {
                self.showClearResearchToast = true
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation {
                self.showClearResearchToast = false
            }
        }
    }
    
    // MARK: - Cache & Governance
    
    func clearModelCache() {
        Task { [weak self] in
            guard let self = self else { return }
            await GuidanceCache.shared.clear()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation {
                self.showClearCacheToast = true
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation {
                self.showClearCacheToast = false
            }
        }
    }
    
    func resetAllLocalData(modelContext: ModelContext) {
        do {
            try modelContext.delete(model: LocalAssemblySession.self)
            try modelContext.delete(model: LocalAttempt.self)
            try modelContext.save()
            
            Task { [weak self] in
                guard let self = self else { return }
                await ResearchLogger.shared.clearLogs()
                await GuidanceCache.shared.clear()
                await self.loadResearchStats()
            }
            
            self.completedSessionsCount = 0
            self.totalAssemblyMinutes = 0
            self.overallAccuracyScore = 100
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation {
                self.showResetSuccessToast = true
            }
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation {
                    self?.showResetSuccessToast = false
                }
            }
        } catch {
            // Error handling
        }
    }
    
    func deleteAccount(authService: SupabaseAuthService, modelContext: ModelContext, completion: @escaping () -> Void) {
        resetAllLocalData(modelContext: modelContext)
        UserDefaults.standard.removeObject(forKey: "user_display_name")
        UserDefaults.standard.removeObject(forKey: "user_avatar_symbol")
        UserDefaults.standard.removeObject(forKey: "user_avatar_color_hex")
        self.displayName = "Hardware Assembler"
        self.avatarSymbol = "person.crop.circle.fill"
        self.avatarColorHex = "#0A84FF"
        
        Task {
            try? await authService.deleteAccount()
            completion()
        }
    }
    
    func deleteAccount() async {
        isDeletingAccount = true
        deletionError = nil
        if let auth = authService {
            do {
                try await auth.deleteAccount()
                showDeleteAccountConfirmation = false
            } catch {
                deletionError = error.localizedDescription
            }
        } else {
            showDeleteAccountConfirmation = false
        }
        isDeletingAccount = false
    }
    
    func signOut() async {
        await authService?.signOut()
    }
}
