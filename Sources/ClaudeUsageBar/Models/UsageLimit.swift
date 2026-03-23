import Foundation

/// A single usage limit entry to display in the UI.
struct UsageLimitData: Identifiable {
    let id = UUID()
    let title: String
    let utilization: Double  // 0-100
    let resetsAt: Date?
    let category: String     // e.g. "five_hour", "seven_day", "context_window"
}

// MARK: - Cache File JSON Models

/// Model info from Claude Code
struct ModelInfo: Decodable {
    let id: String?
    let display_name: String?
}

/// Context window usage from Claude Code
struct ContextWindow: Decodable {
    let used_percentage: Double?
    let remaining_percentage: Double?
}

/// The JSON structure written by the Claude Code hook to ~/.claude/usage_cache.json
struct CacheFileResponse: Decodable {
    let rate_limits: RateLimits?
    let context_window: ContextWindow?
    let updated_at: Int?
    let session_id: String?
    let model: ModelInfo?

    /// Convert cache data into display-ready items.
    func toUsageLimits() -> [UsageLimitData] {
        var items: [UsageLimitData] = []

        if let fh = rate_limits?.five_hour {
            items.append(UsageLimitData(
                title: "Current session (5h)",
                utilization: fh.used_percentage,
                resetsAt: fh.resetDate,
                category: "five_hour"
            ))
        }

        if let sd = rate_limits?.seven_day {
            items.append(UsageLimitData(
                title: "Current week (7d)",
                utilization: sd.used_percentage,
                resetsAt: sd.resetDate,
                category: "seven_day"
            ))
        }

        if let sonnet = rate_limits?.seven_day_sonnet {
            items.append(UsageLimitData(
                title: "Current week - Sonnet",
                utilization: sonnet.used_percentage,
                resetsAt: sonnet.resetDate,
                category: "seven_day_sonnet"
            ))
        }

        if let ctx = context_window, let used = ctx.used_percentage {
            items.append(UsageLimitData(
                title: "Context window",
                utilization: used,
                resetsAt: nil,
                category: "context_window"
            ))
        }

        return items
    }
}

struct RateLimits: Decodable {
    let five_hour: RateLimitBucket?
    let seven_day: RateLimitBucket?
    let seven_day_sonnet: RateLimitBucket?
}

struct RateLimitBucket: Decodable {
    let used_percentage: Double
    let resets_at: Double?

    var resetDate: Date? {
        guard let epoch = resets_at else { return nil }
        return Date(timeIntervalSince1970: epoch)
    }
}
