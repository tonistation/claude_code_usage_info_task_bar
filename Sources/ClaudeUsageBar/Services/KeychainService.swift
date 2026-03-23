import Foundation
import Security

/// Reads Claude subscription plan info from the macOS Keychain.
struct KeychainService {

    /// Subscription plan info parsed from Keychain credentials.
    struct PlanInfo {
        let subscriptionType: String
        let rateLimitTier: String?
        let displayName: String
    }

    /// Read Claude Code credentials from Keychain and extract plan info.
    /// Service: "Claude Code-credentials", Account: current macOS username.
    static func readPlanInfo() -> PlanInfo? {
        let username = NSUserName()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return parsePlanInfo(from: data)
    }

    /// Parse the JSON credentials and extract subscription info.
    private static func parsePlanInfo(from data: Data) -> PlanInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Try nested path: claudeAiOauth.subscriptionType
        guard let oauth = json["claudeAiOauth"] as? [String: Any],
              let subscriptionType = oauth["subscriptionType"] as? String else {
            return nil
        }

        let rateLimitTier = oauth["rateLimitTier"] as? String
        let displayName = mapDisplayName(subscriptionType: subscriptionType, rateLimitTier: rateLimitTier)

        return PlanInfo(
            subscriptionType: subscriptionType,
            rateLimitTier: rateLimitTier,
            displayName: displayName
        )
    }

    /// Map subscription type and rate limit tier to a user-friendly display name.
    private static func mapDisplayName(subscriptionType: String, rateLimitTier: String?) -> String {
        switch subscriptionType.lowercased() {
        case "max":
            if let tier = rateLimitTier?.lowercased(), tier.contains("5x") {
                return "Claude Max 5x"
            }
            return "Claude Max"
        case "pro":
            return "Claude Pro"
        default:
            // Capitalize the raw type as fallback
            let capitalized = subscriptionType.prefix(1).uppercased() + subscriptionType.dropFirst()
            return "Claude \(capitalized)"
        }
    }
}
