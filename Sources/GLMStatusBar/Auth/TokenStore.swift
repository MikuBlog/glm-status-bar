import Foundation

enum TokenStore {
    static let key = "glm_token"

    static func load() -> String? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func save(_ token: String) {
        UserDefaults.standard.set(token, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Normalize the raw `bigmodel_token_production` localStorage value into the
    /// exact `Authorization` header value. The web app uses this value verbatim
    /// (no "Bearer" prefix). It also tolerates JSON-wrapped token objects.
    static func normalize(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("{"),
           let data = value.data(using: .utf8),
           let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            for key in ["token", "access_token", "accessToken", "value", "authorization"] {
                if let s = object[key] as? String, !s.isEmpty {
                    return s
                }
            }
            return nil
        }
        return value
    }

    /// Cookie values may arrive percent-encoded; decode before normalizing.
    static func normalizeCookie(_ raw: String) -> String? {
        let decoded = raw.removingPercentEncoding ?? raw
        return normalize(decoded)
    }
}
