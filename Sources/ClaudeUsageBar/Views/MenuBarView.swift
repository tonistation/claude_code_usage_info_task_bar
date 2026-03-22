import SwiftUI

/// Main popover content shown when the menu bar icon is clicked.
struct MenuBarView: View {
    @ObservedObject var viewModel: UsageViewModel

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

            // Source info
            Text("Data from Claude Code hooks")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Quit button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit ClaudeUsageBar")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Claude Usage")
                .font(.title3)
                .fontWeight(.semibold)

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
}
