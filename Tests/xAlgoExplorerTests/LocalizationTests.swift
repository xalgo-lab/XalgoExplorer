import XCTest
@testable import xAlgoExplorer

final class LocalizationTests: XCTestCase {
    func testMainstreamLanguagesAreAvailable() {
        XCTAssertEqual(
            AppText.supportedLanguages.map(\.id),
            ["system", "zh-Hans", "zh-Hant", "en", "ja", "ko", "fr", "de", "es", "pt", "ru"]
        )
    }

    func testTooltipsFollowSelectedLanguage() {
        XCTAssertEqual(AppText.localized(.tooltipSearch, language: "zh-Hans"), "搜索")
        XCTAssertEqual(AppText.localized(.tooltipSearch, language: "en"), "Search")
        XCTAssertEqual(AppText.localized(.tooltipSearch, language: "ja"), "検索")
        XCTAssertEqual(AppText.localized(.tooltipSearch, language: "ko"), "검색")
        XCTAssertEqual(AppText.localized(.tooltipSearch, language: "fr"), "Rechercher")
        XCTAssertEqual(AppText.localized(.tooltipSearch, language: "de"), "Suchen")
        XCTAssertEqual(AppText.localized(.tooltipSearch, language: "es"), "Buscar")
        XCTAssertEqual(AppText.localized(.tooltipSearch, language: "pt"), "Pesquisar")
        XCTAssertEqual(AppText.localized(.tooltipSearch, language: "ru"), "Поиск")
        XCTAssertEqual(AppText.localized(.tooltipCopyPath, language: "zh-Hans"), "双击复制路径")
        XCTAssertEqual(AppText.localized(.tooltipCopyPath, language: "en"), "Double-click to copy path")
    }

    func testSidebarTitlesFollowSelectedLanguage() {
        XCTAssertEqual(AppText.localized(.sidebarPictures, language: "zh-Hans"), "图片")
        XCTAssertEqual(AppText.localized(.sidebarPictures, language: "en"), "Pictures")
        XCTAssertEqual(AppText.localized(.sidebarNetwork, language: "zh-Hans"), "内网计算机")
        XCTAssertEqual(AppText.localized(.sidebarNetwork, language: "en"), "Network")
    }
}
