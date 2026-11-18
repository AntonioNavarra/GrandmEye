import Foundation

extension String {
    /// Looks up a String Catalog key in the given language (e.g. "it"),
    /// independent of the device language. Falls back to the main bundle, then to the key itself.
    static func localized(_ key: String, languageCode: String) -> String {
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}
