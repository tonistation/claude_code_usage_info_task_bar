import SwiftUI

/// A reusable progress bar showing a single usage limit.
struct UsageBarView: View {
    let data: UsageLimitData

    private var barColor: Color {
        if data.utilization > 80 {
            return .red
        } else if data.utilization > 50 {
            return .yellow
        } else {
            return .blue
        }
    }

    private var resetLabel: String? {
        guard let date = data.resetsAt else { return nil }

        let now = Date()
        let diff = date.timeIntervalSince(now)

        if diff <= 0 {
            return "Reset imminent"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: date, relativeTo: now)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a zzz"
        let absolute = timeFormatter.string(from: date)

        return "Resets \(relative) (\(absolute))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title row
            HStack {
                Text(data.title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(String(format: "%.0f%% used", data.utilization))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(
                            width: max(0, geo.size.width * min(data.utilization, 100) / 100),
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            // Reset time
            if let resetText = resetLabel {
                Text(resetText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}
