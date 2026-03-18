import Foundation
import SwiftUI

@MainActor
final class LocalizationService: ObservableObject {
    static let shared = LocalizationService()

    private let selectedLanguageKey = "workout.localization.selectedLanguage"
    private let didChooseLanguageKey = "workout.localization.didChooseLanguage"

    @Published private(set) var selectedLanguage: AppLanguage
    @Published private(set) var didChooseLanguage: Bool

    private init() {
        let defaults = UserDefaults.standard
        let storedLanguage = defaults.string(forKey: selectedLanguageKey).flatMap(AppLanguage.init(rawValue:))
        self.selectedLanguage = storedLanguage ?? AppLanguage.bestMatch(
            for: Locale.preferredLanguages.first ?? Locale.current.identifier
        )
        self.didChooseLanguage = defaults.bool(forKey: didChooseLanguageKey)
    }

    var locale: Locale {
        Locale(identifier: selectedLanguage.localeIdentifier)
    }

    var layoutDirection: LayoutDirection {
        selectedLanguage == .arabic ? .rightToLeft : .leftToRight
    }

    func choose(_ language: AppLanguage, explicit: Bool = true) {
        selectedLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: selectedLanguageKey)
        if explicit {
            didChooseLanguage = true
            UserDefaults.standard.set(true, forKey: didChooseLanguageKey)
        }
    }

    func apply(settings: AppSettings) {
        choose(settings.preferredLanguageValue, explicit: true)
    }

    func localized(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedFormat(for: key)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    private func localizedFormat(for key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    private var localizedBundle: Bundle {
        if let path = Bundle.main.path(forResource: selectedLanguage.localeIdentifier, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
}
