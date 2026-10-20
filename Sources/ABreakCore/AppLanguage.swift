import Foundation

/// UI language preference. `.system` follows the first preferred macOS language.
public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case english = "en"
    case chinese = "zh-Hans"

    /// Resolves to `.english` or `.chinese`; any Chinese system language maps to Simplified Chinese.
    public func resolved(preferredLanguages: [String]) -> AppLanguage {
        switch self {
        case .english, .chinese:
            return self
        case .system:
            return preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? .chinese : .english
        }
    }
}
