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
    @Published private var hasLoadedOnce = false

    /// Label shown in the macOS menu bar.
    var menuBarLabel: String {
        if usageLimits.isEmpty {
            return "--%"
        }
        // Show the highest utilization across all limits
        let maxUtil = usageLimits.map(\.utilization).max() ?? 0
        return String(format: "%.0f%%", maxUtil)
    }

    /// Fetch usage from the cache file.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        warningMessage = nil

        do {
            let response = try await UsageAPIClient.fetchUsage()
            usageLimits = response.toUsageLimits()
            lastUpdated = UsageAPIClient.lastUpdated(response)
            hasLoadedOnce = true

            if usageLimits.isEmpty {
                errorMessage = "No rate limit data in cache. Use Claude Code to generate data."
            } else if UsageAPIClient.isStale(response) {
                warningMessage = "Data may be outdated. Use Claude Code to refresh."
            }
        } catch {
            errorMessage = error.localizedDescription
            if !hasLoadedOnce {
                usageLimits = []
            }
        }

        isLoading = false
    }

    /// Called when the popover first appears — auto-refresh if we haven't loaded yet.
    func onAppear() {
        if !hasLoadedOnce {
            Task {
                await refresh()
            }
        }
    }
}
