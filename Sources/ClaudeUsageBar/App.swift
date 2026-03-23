import SwiftUI

@main
struct ClaudeUsageBarApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            HStack(spacing: 4) {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                Text(viewModel.menuBarLabel)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
