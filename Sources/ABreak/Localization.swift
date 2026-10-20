import ABreakCore
import Foundation

/// Current UI language, resolved from the in-app setting (default: follow macOS).
var currentLanguage: AppLanguage {
    let raw = UserDefaults.standard.string(forKey: Pref.language) ?? AppLanguage.system.rawValue
    return (AppLanguage(rawValue: raw) ?? .system).resolved(preferredLanguages: Locale.preferredLanguages)
}

/// Picks the string for the current UI language. Strings live next to their use so both
/// languages are always updated together; switching takes effect without a relaunch.
func tr(_ english: String, _ chinese: String) -> String {
    currentLanguage == .chinese ? chinese : english
}
