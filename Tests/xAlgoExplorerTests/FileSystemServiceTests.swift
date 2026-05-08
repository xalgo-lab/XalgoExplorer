import XCTest
@testable import xAlgoExplorer

final class FileSystemServiceTests: XCTestCase {
    func testRenameRejectsPathTraversalAndPathSeparators() throws {
        let root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("xAlgoExplorerRenameTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let file = root.appendingPathComponent("sample.txt")
        try Data("rename".utf8).write(to: file)

        XCTAssertThrowsError(try FileSystemService.rename(file, to: "../escaped.txt"))
        XCTAssertThrowsError(try FileSystemService.rename(file, to: "nested/name.txt"))
        XCTAssertThrowsError(try FileSystemService.rename(file, to: "nested:name.txt"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.deletingLastPathComponent().appendingPathComponent("escaped.txt").path))
    }

    func testMovingFileBackIntoOriginalDirectoryIsNoOp() throws {
        let root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("xAlgoExplorerMoveTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let file = root.appendingPathComponent("sample.txt")
        try Data("move".utf8).write(to: file)

        try FileSystemService.move([file], to: root)

        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("sample 1.txt").path))
    }
}
