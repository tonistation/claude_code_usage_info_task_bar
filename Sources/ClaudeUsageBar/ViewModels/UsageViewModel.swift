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

    private var fileMonitor: FileMonitor?

    /// Dynamic icon tint color based on the highest rate-limit utilization.
    var iconTintColor: Color {
        let rateLimits = usageLimits.filter { $0.category != "context_window" }
        let maxUtil = rateLimits.map(\.utilization).max() ?? 0
        if maxUtil >= 80 { return .red }
        if maxUtil >= 50 { return .yellow }
        return .blue
    }

    /// NSColor version for tinting the menu bar NSImage.
    var iconTintNSColor: NSColor {
        let rateLimits = usageLimits.filter { $0.category != "context_window" }
        let maxUtil = rateLimits.map(\.utilization).max() ?? 0
        if maxUtil >= 80 { return .systemRed }
        if maxUtil >= 50 { return .systemYellow }
        return .systemBlue
    }

    init() {
        // Read plan info once at launch from Keychain
        if let plan = KeychainService.readPlanInfo() {
            planDisplayName = plan.displayName
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

    /// Create a tinted version of the MenuBarIcon for the menu bar.
    static func tintedMenuBarIcon(color: NSColor) -> NSImage {
        guard let original = NSImage(named: "MenuBarIcon") else {
            return NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Usage")!
        }
        let tinted = NSImage(size: original.size, flipped: false) { rect in
            original.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false  // Not template so our color shows
        return tinted
    }
}
