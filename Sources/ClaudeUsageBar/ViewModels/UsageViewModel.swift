import Foundation
import SwiftUI

/// Main view model — reads usage from cache file and exposes data to the UI.
@MainActor
class UsageViewModel: ObservableObject {
    @Published var usageLimits: [UsageLimitData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var warningMessage: String?
    @Published var lastUpdated: Date?
    @Published var planDisplayName: String?
    @Published var modelDisplayName: String?
    @Published var sessionsToday: Int = 0

    private var fileMonitor: FileMonitor?

    /// Dynamic icon tint color — white by default, colored only at alert thresholds.
    var iconTintColor: Color {
        let rateLimits = usageLimits.filter { $0.category != "context_window" }
        let maxUtil = rateLimits.map(\.utilization).max() ?? 0
        if maxUtil >= 80 { return .red }
        if maxUtil >= 50 { return .yellow }
        return .white
    }

    /// NSColor version for tinting the menu bar NSImage.
    var iconTintNSColor: NSColor {
        let rateLimits = usageLimits.filter { $0.category != "context_window" }
        let maxUtil = rateLimits.map(\.utilization).max() ?? 0
        if maxUtil >= 80 { return .systemRed }
        if maxUtil >= 50 { return .systemYellow }
        return .white
    }

    init() {
        // Request notification permission on first launch
        NotificationService.shared.requestPermission()

        // Read plan info: try UserDefaults cache first, then Keychain
        if let cached = UserDefaults.standard.string(forKey: "cachedPlanDisplayName") {
            planDisplayName = cached
        } else if let plan = KeychainService.readPlanInfo() {
            planDisplayName = plan.displayName
            UserDefaults.standard.set(plan.displayName, forKey: "cachedPlanDisplayName")
        }

        // Initial load
        Task { [weak self] in
            await self?.refresh()
        }

        // Start file monitor for auto-refresh
        startFileMonitor()
    }

    /// Label shown in the macOS menu bar.
    var menuBarLabel: String {
        if usageLimits.isEmpty {
            return "--%"
        }
        // Show the highest utilization across rate limit bars (exclude context window)
        let rateLimits = usageLimits.filter { $0.category != "context_window" }
        let maxUtil = rateLimits.map(\.utilization).max() ?? usageLimits.map(\.utilization).max() ?? 0
        return String(format: "%.0f%%", maxUtil)
    }

    /// Fetch usage from the cache file.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        warningMessage = nil

        do {
            let response = try await UsageAPIClient.fetchUsage()
            let newLimits = response.toUsageLimits()

            // Only update if data actually changed to avoid UI flicker
            if !limitsEqual(usageLimits, newLimits) {
                usageLimits = newLimits
            }

            lastUpdated = UsageAPIClient.lastUpdated(response)

            // Update model display name from cache
            if let displayName = response.model?.display_name, !displayName.isEmpty {
                modelDisplayName = displayName
            } else if let modelId = response.model?.id, !modelId.isEmpty {
                modelDisplayName = modelId
            }

            // Check notification thresholds
            NotificationService.shared.checkThresholds(
                fiveHour: response.rate_limits?.five_hour,
                sevenDay: response.rate_limits?.seven_day
            )

            // Count active sessions today
            sessionsToday = Self.countSessionsToday()

            if newLimits.isEmpty {
                errorMessage = "No rate limit data in cache. Use Claude Code to generate data."
            } else if UsageAPIClient.isStale(response) {
                warningMessage = "Data may be outdated. Use Claude Code to refresh."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Called when the popover appears — always try to refresh.
    func onAppear() {
        Task {
            await refresh()
        }
    }

    // MARK: - File Monitor

    private func startFileMonitor() {
        fileMonitor = FileMonitor { [weak self] in
            // Callback fires on a background queue — dispatch to MainActor
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        fileMonitor?.start()
    }

    // MARK: - Session Counting

    /// Count JSONL files in ~/.claude/projects/ modified today.
    static func countSessionsToday() -> Int {
        let fm = FileManager.default
        let projectsDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        guard fm.fileExists(atPath: projectsDir.path) else { return 0 }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        var count = 0

        guard let enumerator = fm.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = values.contentModificationDate else { continue }
            if modDate >= todayStart {
                count += 1
            }
        }

        return count
    }

    // MARK: - Helpers

    /// Compare two limit arrays by value to avoid unnecessary UI updates.
    private func limitsEqual(_ a: [UsageLimitData], _ b: [UsageLimitData]) -> Bool {
        guard a.count == b.count else { return false }
        for (lhs, rhs) in zip(a, b) {
            if lhs.category != rhs.category || lhs.utilization != rhs.utilization || lhs.title != rhs.title {
                return false
            }
        }
        return true
    }

    /// Whether the icon should use alert coloring.
    var isAlertState: Bool {
        let rateLimits = usageLimits.filter { $0.category != "context_window" }
        let maxUtil = rateLimits.map(\.utilization).max() ?? 0
        return maxUtil >= 50
    }

    /// Load the menu bar icon from bundle resources.
    static func loadMenuBarIcon() -> NSImage {
        if let url = Bundle.module.url(forResource: "icon_36", withExtension: "png",
                                        subdirectory: "Assets.xcassets/MenuBarIcon.imageset"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Usage")!
    }

    /// Menu bar icon: template (auto light/dark) in normal state, tinted for alerts.
    /// Sized to 16x16 points to match standard macOS menu bar icons.
    static func menuBarIcon(alertColor: NSColor?) -> NSImage {
        let original = loadMenuBarIcon()
        let targetSize = NSSize(width: 16, height: 16)

        // Set the image size to 16pt (the pixel data stays high-res for Retina)
        original.size = targetSize

        guard let color = alertColor else {
            original.isTemplate = true
            return original
        }

        // Alert state: tint with color
        let tinted = NSImage(size: targetSize, flipped: false) { rect in
            original.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        return tinted
    }
}
