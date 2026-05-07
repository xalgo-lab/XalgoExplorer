import XCTest
@testable import xAlgoExplorer

final class FileContextMenuTests: XCTestCase {
    func testTopContextMenuActionsIncludeChooseApplicationThenCopyURL() {
        XCTAssertEqual(FileContextMenuLayout.topActionTitles, ["选择应用打开", "复制URL"])
        XCTAssertFalse(FileContextMenuLayout.topActionTitles.contains("打开"))
    }

    @MainActor
    func testCopyURLCopiesAbsolutePathIncludingName() {
        let model = ExplorerModel()
        let entry = FileEntry(
            url: URL(fileURLWithPath: "/tmp/example folder/demo.txt"),
            name: "demo.txt",
            isDirectory: false,
            isPackage: false,
            modified: nil,
            created: nil,
            size: 1,
            typeDescription: "text",
            typeIdentifier: nil
        )

        model.copyURL(of: entry)

        XCTAssertEqual(
            NSPasteboard.general.string(forType: .string),
            "/tmp/example folder/demo.txt"
        )
    }
}
