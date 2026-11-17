import XCTest
@testable import VoltaLanguageCore

final class AppLanguageTests: XCTestCase {
    func testDetectedLanguageUsesEnglishForEnglishLocaleIdentifiers() {
        XCTAssertEqual(AppLanguage.detected(from: "en-US"), .english)
        XCTAssertEqual(AppLanguage.detected(from: "en_GB"), .english)
    }

    func testDetectedLanguageDefaultsToGermanForOtherLocales() {
        XCTAssertEqual(AppLanguage.detected(from: "de-DE"), .german)
        XCTAssertEqual(AppLanguage.detected(from: "fr-FR"), .german)
        XCTAssertEqual(AppLanguage.detected(from: ""), .german)
    }

    func testLocalizedCopyFollowsTheExplicitSelection() {
        XCTAssertEqual(AppLanguage.english.localized(german: "Sprache", english: "Language"), "Language")
        XCTAssertEqual(AppLanguage.german.localized(german: "Sprache", english: "Language"), "Sprache")
    }

    func testFirstRunPromptsOnlyUntilTheUserChoosesALanguage() {
        XCTAssertTrue(AppLanguage.shouldPresentOnboarding(languageChosen: false))
        XCTAssertFalse(AppLanguage.shouldPresentOnboarding(languageChosen: true))
    }
}
