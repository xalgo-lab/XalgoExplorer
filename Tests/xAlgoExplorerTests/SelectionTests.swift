import XCTest
@testable import xAlgoExplorer

@MainActor
final class SelectionTests: XCTestCase {
    func testArrowSelectionStartsAtFirstEntryAndMovesDown() {
        let model = ExplorerModel()
        let pane = makePane(entries: ["a.txt", "b.txt", "c.txt"])

        XCTAssertTrue(model.moveSelection(in: pane, direction: .down, modifiers: []))
        XCTAssertEqual(pane.selectedIDs, ["/tmp/a.txt"])

        XCTAssertTrue(model.moveSelection(in: pane, direction: .down, modifiers: []))
        XCTAssertEqual(pane.selectedIDs, ["/tmp/b.txt"])
    }

    func testGridArrowSelectionUsesColumnCountForVerticalMoves() {
        let model = ExplorerModel()
        let pane = makePane(entries: ["a.txt", "b.txt", "c.txt", "d.txt", "e.txt"])
        pane.keyboardColumnCount = 3
        pane.selectedIDs = ["/tmp/b.txt"]
        pane.selectionAnchorID = "/tmp/b.txt"

        XCTAssertTrue(model.moveSelection(in: pane, direction: .down, modifiers: []))
        XCTAssertEqual(pane.selectedIDs, ["/tmp/e.txt"])

        XCTAssertTrue(model.moveSelection(in: pane, direction: .up, modifiers: []))
        XCTAssertEqual(pane.selectedIDs, ["/tmp/b.txt"])
    }

    func testShiftArrowExtendsSelectionFromAnchor() {
        let model = ExplorerModel()
        let pane = makePane(entries: ["a.txt", "b.txt", "c.txt"])
        pane.selectedIDs = ["/tmp/a.txt"]
        pane.selectionAnchorID = "/tmp/a.txt"

        XCTAssertTrue(model.moveSelection(in: pane, direction: .down, modifiers: [.shift]))
        XCTAssertEqual(pane.selectedIDs, ["/tmp/a.txt", "/tmp/b.txt"])
    }

    func testMarqueeSelectionUsesIntersectingEntryFrames() {
        let model = ExplorerModel()
        let pane = makePane(entries: ["a.txt", "b.txt", "c.txt"])
        let frames: [FileEntry.ID: CGRect] = [
            "/tmp/a.txt": CGRect(x: 0, y: 0, width: 80, height: 30),
            "/tmp/b.txt": CGRect(x: 0, y: 34, width: 80, height: 30),
            "/tmp/c.txt": CGRect(x: 0, y: 80, width: 80, height: 30)
        ]

        model.selectEntries(
            intersecting: CGRect(x: -4, y: 20, width: 90, height: 50),
            frames: frames,
            in: pane,
            modifiers: []
        )

        XCTAssertEqual(pane.selectedIDs, ["/tmp/a.txt", "/tmp/b.txt"])
    }

    func testBlankClickClearsSelection() {
        let model = ExplorerModel()
        let pane = makePane(entries: ["a.txt"])
        pane.selectedIDs = ["/tmp/a.txt"]
        pane.selectionAnchorID = "/tmp/a.txt"
        pane.selectionCursorID = "/tmp/a.txt"

        model.clearSelectionIfBlankClick(
            at: CGPoint(x: 120, y: 120),
            frames: ["/tmp/a.txt": CGRect(x: 0, y: 0, width: 80, height: 30)],
            in: pane
        )

        XCTAssertTrue(pane.selectedIDs.isEmpty)
        XCTAssertNil(pane.selectionAnchorID)
        XCTAssertNil(pane.selectionCursorID)
    }

    func testClickingEntryDoesNotClearSelection() {
        let model = ExplorerModel()
        let pane = makePane(entries: ["a.txt"])
        pane.selectedIDs = ["/tmp/a.txt"]
        pane.selectionAnchorID = "/tmp/a.txt"
        pane.selectionCursorID = "/tmp/a.txt"

        model.clearSelectionIfBlankClick(
            at: CGPoint(x: 20, y: 20),
            frames: ["/tmp/a.txt": CGRect(x: 0, y: 0, width: 80, height: 30)],
            in: pane
        )

        XCTAssertEqual(pane.selectedIDs, ["/tmp/a.txt"])
        XCTAssertEqual(pane.selectionAnchorID, "/tmp/a.txt")
        XCTAssertEqual(pane.selectionCursorID, "/tmp/a.txt")
    }

    func testEntryPointIsNotBlankInteractionTarget() {
        let frames: [FileEntry.ID: CGRect] = [
            "/tmp/a.txt": CGRect(x: 0, y: 0, width: 80, height: 30)
        ]

        XCTAssertFalse(
            FileSelectionHitTesting.isBlankLocation(
                CGPoint(x: 20, y: 20),
                frames: frames
            )
        )
    }

    func testSingleClickingAlreadySelectedEntryDoesNotOpenDirectory() {
        let model = ExplorerModel()
        let pane = makePane(entries: ["folder"], directories: ["folder"])
        pane.selectedIDs = ["/tmp/folder"]
        pane.selectionAnchorID = "/tmp/folder"
        pane.selectionCursorID = "/tmp/folder"
        let entry = pane.entries[0]

        model.primaryClick(entry, in: pane)

        XCTAssertEqual(pane.url.path, "/tmp")
        XCTAssertEqual(pane.selectedIDs, ["/tmp/folder"])
    }

    func testSlowSecondClickingSelectedEntryDoesNotOpenDirectory() {
        let model = ExplorerModel()
        let pane = makePane(entries: ["folder"], directories: ["folder"])
        let entry = pane.entries[0]

        model.primaryClick(entry, in: pane)
        Thread.sleep(forTimeInterval: 0.55)
        model.primaryClick(entry, in: pane)

        XCTAssertEqual(pane.url.path, "/tmp")
        XCTAssertEqual(pane.selectedIDs, ["/tmp/folder"])
    }

    func testDoubleClickOpensDirectory() {
        let root = URL(fileURLWithPath: "/tmp")
        let model = ExplorerModel()
        let pane = makePane(entries: ["folder"], directories: ["folder"])
        let entry = pane.entries[0]

        model.doubleClick(entry, in: pane)

        XCTAssertEqual(pane.url.standardizedFileURL, root.appendingPathComponent("folder").standardizedFileURL)
    }

    func testPaneInteractionRevisionChangesWhenPaneIsClicked() {
        let model = ExplorerModel()
        let initialRevision = model.paneInteractionRevision

        model.setFocus(.main)

        XCTAssertGreaterThan(model.paneInteractionRevision, initialRevision)
    }

    func testAppKitTableScrollTargetFollowsSelectionCursor() {
        let pane = makePane(entries: ["a.txt", "b.txt", "c.txt"])
        pane.selectedIDs = ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"]
        pane.selectionCursorID = "/tmp/c.txt"

        XCTAssertEqual(
            AppKitSelectionScrollTarget.tableRow(
                entries: pane.entries,
                selectedIDs: pane.selectedIDs,
                cursorID: pane.selectionCursorID
            ),
            2
        )
    }

    func testAppKitCollectionScrollTargetFallsBackToSelectedItem() {
        let pane = makePane(entries: ["a.txt", "b.txt", "c.txt"])
        pane.selectedIDs = ["/tmp/b.txt"]
        pane.selectionCursorID = nil

        XCTAssertEqual(
            AppKitSelectionScrollTarget.collectionIndexPath(
                entries: pane.entries,
                selectedIDs: pane.selectedIDs,
                cursorID: pane.selectionCursorID
            ),
            IndexPath(item: 1, section: 0)
        )
    }

    private func makePane(entries names: [String], directories: Set<String> = []) -> PaneState {
        let pane = PaneState(
            id: .main,
            url: URL(fileURLWithPath: "/tmp"),
            viewMode: .list,
            sortField: .name,
            sortAscending: true
        )
        pane.entries = names.map { name in
            FileEntry(
                url: URL(fileURLWithPath: "/tmp").appendingPathComponent(name),
                name: name,
                isDirectory: directories.contains(name),
                isPackage: false,
                modified: nil,
                created: nil,
                size: 1,
                typeDescription: "text",
                typeIdentifier: nil
            )
        }
        return pane
    }
}
