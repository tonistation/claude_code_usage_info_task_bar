import SwiftUI
import ServiceManagement

/// Main popover content shown when the menu bar icon is clicked.
struct MenuBarView: View {
    @ObservedObject var viewModel: UsageViewModel
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerSection

            Divider()

            if viewModel.isLoading && viewModel.usageLimits.isEmpty {
                ProgressView("Loading usage...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else if let error = viewModel.errorMessage, viewModel.usageLimits.isEmpty {
                // Error state with no data
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.refresh() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                // Usage bars
                ForEach(viewModel.usageLimits) { limit in
                    UsageBarView(data: limit)
                }

                // Staleness warning
                if let warning = viewModel.warningMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.caption2)
                        Text(warning)
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }

                // Error with existing data
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            // Last updated
            if let updated = viewModel.lastUpdated {
                lastUpdatedView(date: updated)
            }

            Divider()

            // Footer: source info + settings + quit
            footerSection
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            viewModel.onAppear()
            syncLaunchAtLoginState()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Usage")
                    .font(.title3)
                    .fontWeight(.semibold)

                // Plan and model subtitle
                if (viewModel.planDisplayName ?? viewModel.modelDisplayName) != nil {
                    HStack(spacing: 6) {
                        if let planName = viewModel.planDisplayName {
                            Text(planName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        if viewModel.planDisplayName != nil && viewModel.modelDisplayName != nil {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        if let model = viewModel.modelDisplayName {
                            Text(model)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if viewModel.sessionsToday > 0 {
                    Text("\(viewModel.sessionsToday) session\(viewModel.sessionsToday == 1 ? "" : "s") today")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            Spacer()

            // Refresh button
            Button(action: {
                Task { await viewModel.refresh() }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Data from Claude Code hooks")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Launch at Login toggle
            Toggle(isOn: $launchAtLogin) {
                Text("Launch at Login")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: launchAtLogin) { newValue in
                setLaunchAtLogin(newValue)
            }

            // GitHub link
            Button(action: {
                if let url = URL(string: "https://github.com/tonistation/claude_code_usage_info_task_bar") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                    Text("Docs, Issues & Contributions")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            // Quit button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit ClaudeUsageBar")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.top, 2)
        }
    }

    // MARK: - Last Updated

    private func lastUpdatedView(date: Date) -> some View {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: date, relativeTo: Date())

        return Text("Last updated \(relative)")
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Launch at Login

    /// Sync the toggle state with the actual SMAppService status.
    private func syncLaunchAtLoginState() {
        let status = SMAppService.mainApp.status
        launchAtLogin = (status == .enabled)
    }

    /// Register or unregister the app for launch at login.
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // If registration fails, revert the toggle
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
}
