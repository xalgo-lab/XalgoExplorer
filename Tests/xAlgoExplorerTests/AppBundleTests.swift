import XCTest
@testable import xAlgoExplorer

final class AppBundleTests: XCTestCase {
    func testAppIconAssetExistsAndPackagingReferencesIt() throws {
        let root = repositoryRoot()
        let iconURL = root
            .appendingPathComponent("Sources/xAlgoExplorer/Resources/AppIcon.icns")
        let packageScript = try String(
            contentsOf: root.appendingPathComponent("scripts/package-app.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.path))
        XCTAssertTrue(packageScript.contains("CFBundleIconFile"))
        XCTAssertTrue(packageScript.contains("AppIcon"))
    }

    func testAppPackagingScriptSignsBundleForCandidateBuilds() throws {
        let root = repositoryRoot()
        let packageScript = try String(
            contentsOf: root.appendingPathComponent("scripts/package-app.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(packageScript.contains("codesign --force --deep --sign -"))
    }

    func testDmgPackagingScriptCreatesApplicationInstallerImage() throws {
        let root = repositoryRoot()
        let packageScript = try String(
            contentsOf: root.appendingPathComponent("scripts/package-dmg.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(packageScript.contains("dist/xAlgo Explorer.app"))
        XCTAssertTrue(packageScript.contains("/Applications"))
        XCTAssertTrue(packageScript.contains("hdiutil create"))
        XCTAssertTrue(packageScript.contains("shasum -a 256"))
    }

    func testAboutMetadataContainsRequiredCopyright() {
        XCTAssertEqual(AppMetadata.copyright, "Copyright by 8G 2026 xAlgo Inc.")
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
