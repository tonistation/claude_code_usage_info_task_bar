import Foundation

/// Reads Claude usage data from the local cache file written by Claude Code hooks.
struct UsageAPIClient {

    enum APIError: Error, LocalizedError {
        case noData
        case staleData(Date)
        case fileNotFound
        case decodingError(String)

        var errorDescription: String? {
            switch self {
            case .noData:
                return "No usage data yet. Start a Claude Code session to begin tracking."
            case .staleData(let date):
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                let relative = formatter.localizedString(for: date, relativeTo: Date())
                return "Data may be outdated (last updated \(relative))"
            case .fileNotFound:
                return "No usage data yet. Start a Claude Code session to begin tracking."
            case .decodingError(let msg):
                return "Failed to parse usage data: \(msg)"
            }
        }
    }

    private static var cacheFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/usage_cache.json")
    }

    /// Maximum age in seconds before data is considered stale (6 hours).
    private static let staleThreshold: TimeInterval = 6 * 3600

    /// Read usage data from the cache file written by Claude Code hooks.
    static func fetchUsage() async throws -> CacheFileResponse {
        let url = cacheFileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw APIError.fileNotFound
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }

        guard !data.isEmpty else {
            throw APIError.noData
        }

        let response: CacheFileResponse
        do {
            let decoder = JSONDecoder()
            response = try decoder.decode(CacheFileResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }

        return response
    }

    /// Check if the cached data is stale.
    static func isStale(_ response: CacheFileResponse) -> Bool {
        guard let updatedAt = response.updated_at else { return true }
        let age = Date().timeIntervalSince1970 - Double(updatedAt)
        return age > staleThreshold
    }

    /// Get the last updated date from the cache response.
    static func lastUpdated(_ response: CacheFileResponse) -> Date? {
        guard let updatedAt = response.updated_at else { return nil }
        return Date(timeIntervalSince1970: Double(updatedAt))
    }
}
