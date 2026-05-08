import XCTest
@testable import xAlgoExplorer

@MainActor
final class SearchAndNetworkTests: XCTestCase {
    func testCloseSearchClearsQueryAndReleasesOpenState() {
        let model = ExplorerModel()
        model.openSearch()
        model.searchText = "abc"

        model.closeSearch()

        XCTAssertFalse(model.searchOpen)
        XCTAssertEqual(model.searchText, "")
    }

    func testNetworkDiscoveryDoesNotReturnHardcodedFakeDevice() {
        XCTAssertFalse(NetworkDiscovery.discoveredDeviceNames().contains("TS-416-QK6WQ01"))
        XCTAssertTrue(NetworkDiscovery.discoveredDeviceNames().isEmpty)
    }
}
