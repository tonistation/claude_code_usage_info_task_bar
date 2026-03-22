import SwiftUI

@main
struct ClaudeUsageBarApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Label(viewModel.menuBarLabel, systemImage: "chart.bar.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
