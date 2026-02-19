import Foundation

/// Reads configuration values from the bundled environment file, process environment,
/// or Keychain fallback. The `.env` file at the project root is copied into the app
/// bundle by a post-build script, making it readable within the sandbox.
///
/// Priority: ProcessInfo environment → bundled env file → Keychain.
enum EnvironmentConfig {

    nonisolated(unsafe) private static var envCache: [String: String]?

    /// Returns the Gemini API key from the first available source.
    static var geminiAPIKey: String? {
        // 1. Process environment (Xcode scheme env vars / terminal launch)
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
           !key.isEmpty {
            return key
        }

        // 2. Bundled .env file (copied at build time)
        if let key = loadBundledEnv()["GEMINI_API_KEY"],
           !key.isEmpty {
            return key
        }

        // 3. Keychain fallback (manual entry from Settings)
        return KeychainHelper.readString(key: KeychainHelper.Keys.geminiAPIKey)
    }

    /// Describes where the current Gemini key was resolved from.
    static var geminiKeySource: KeySource {
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
           !key.isEmpty {
            return .processEnvironment
        }
        if let key = loadBundledEnv()["GEMINI_API_KEY"],
           !key.isEmpty {
            return .envFile
        }
        if KeychainHelper.readString(key: KeychainHelper.Keys.geminiAPIKey) != nil {
            return .keychain
        }
        return .none
    }

    enum KeySource: Equatable {
        case processEnvironment
        case envFile
        case keychain
        case none

        var displayLabel: String {
            switch self {
            case .processEnvironment: "PROCESS ENV"
            case .envFile: "ENV FILE"
            case .keychain: "KEYCHAIN"
            case .none: "NOT CONFIGURED"
            }
        }
    }

    // MARK: - .env File Parsing

    private static func loadBundledEnv() -> [String: String] {
        if let cached = envCache { return cached }

        guard let url = Bundle.main.url(forResource: "env", withExtension: "local"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            envCache = [:]
            return [:]
        }

        let parsed = parseEnv(contents)
        envCache = parsed
        return parsed
    }

    /// Parses `KEY=VALUE` lines from a `.env` file. Ignores comments (#) and blank lines.
    static func parseEnv(_ contents: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)

            // Strip surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        return result
    }
}
