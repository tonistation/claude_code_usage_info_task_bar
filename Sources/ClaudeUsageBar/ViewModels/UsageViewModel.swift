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
    @Published private var hasLoadedOnce = false

    init() {
        // Read plan info once at launch from Keychain
        if let plan = KeychainService.readPlanInfo() {
            planDisplayName = plan.displayName
        }
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
            usageLimits = response.toUsageLimits()
            lastUpdated = UsageAPIClient.lastUpdated(response)
            hasLoadedOnce = true

            // Update model display name from cache
            if let displayName = response.model?.display_name, !displayName.isEmpty {
                modelDisplayName = displayName
            } else if let modelId = response.model?.id, !modelId.isEmpty {
                modelDisplayName = modelId
            }

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
