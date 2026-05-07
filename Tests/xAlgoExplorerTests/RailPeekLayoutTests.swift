import XCTest
@testable import xAlgoExplorer

final class RailPeekLayoutTests: XCTestCase {
    func testHiddenRailOpensForHoverOrDropTarget() {
        XCTAssertTrue(RailPeekLayout.shouldOpen(isHovering: true, isDropTarget: false))
        XCTAssertTrue(RailPeekLayout.shouldOpen(isHovering: false, isDropTarget: true))
        XCTAssertFalse(RailPeekLayout.shouldOpen(isHovering: false, isDropTarget: false))
    }

    func testHiddenRailStaysOpenWhenPointerMovesFromTriggerOntoRail() {
        XCTAssertTrue(
            RailPeekLayout.shouldOpen(
                isRailHovering: true,
                isTriggerHovering: false,
                isDropTarget: false
            )
        )
    }

    func testHiddenRailOnlyUsesNarrowCollapsedHitArea() {
        XCTAssertEqual(RailPeekLayout.hitWidth(isOpen: false), 14)
        XCTAssertEqual(RailPeekLayout.hitWidth(isOpen: true), 62)
    }

    func testClosedHiddenRailOffsetsBodyOutsideCollapsedHitArea() {
        XCTAssertEqual(RailPeekLayout.railOffset(isOpen: false), -62)
        XCTAssertEqual(RailPeekLayout.railOffset(isOpen: true), 0)
    }

    func testHiddenRailAlwaysClipsBodyForSlideAnimation() {
        XCTAssertTrue(RailPeekLayout.clipsRailBody)
    }

    func testRailBodyWidthMatchesExpandedHitArea() {
        XCTAssertEqual(RailPeekLayout.railBodyWidth, RailPeekLayout.expandedHitWidth)
    }

    func testDockedRailSlotDoesNotClipSharedCapsuleSurface() {
        XCTAssertEqual(RailPeekLayout.dockedRailSlotWidth, RailPeekLayout.railBodyWidth)
    }

    func testCollapsedStripHeightMatchesRailContentHeight() {
        XCTAssertEqual(
            RailPeekLayout.collapsedStripHeight(defaultCount: 7, userCount: 0, utilityCount: 3),
            RailPeekLayout.railContentHeight(defaultCount: 7, userCount: 0, utilityCount: 3)
        )
    }

    func testCollapsedStripIsContentBoundInsteadOfWindowHeight() {
        let height = RailPeekLayout.collapsedStripHeight(defaultCount: 7, userCount: 0, utilityCount: 3)

        XCTAssertGreaterThan(height, 0)
        XCTAssertLessThan(height, 600)
    }

    func testNormalHoverTriggerDoesNotCoverExpandedIcons() {
        XCTAssertEqual(RailPeekLayout.triggerWidth(isDropTarget: false), 14)
    }

    func testDragTargetExpandsToKeepDropActive() {
        XCTAssertEqual(RailPeekLayout.triggerWidth(isDropTarget: true), 62)
    }

    func testRailDropTypesAcceptInternalAndExternalFileDrags() {
        XCTAssertTrue(RailShortcutDropTypes.accepted.contains(.fileURL))
        XCTAssertTrue(RailShortcutDropTypes.accepted.contains(.xAlgoInternalFileDrag))
    }

    func testInternalDragPayloadCanCreateShortcutURLs() throws {
        let payload = InternalFileDragPayload(sourcePaneID: .main, paths: ["/tmp/example.txt", "/tmp/example-folder"])
        let data = try JSONEncoder().encode(payload)

        let urls = RailShortcutPasteboardReader.urls(fromInternalDragData: data)

        XCTAssertEqual(urls.map(\.path), ["/tmp/example.txt", "/tmp/example-folder"])
    }
}
