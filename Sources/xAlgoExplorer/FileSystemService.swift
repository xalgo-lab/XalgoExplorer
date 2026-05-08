import AppKit
import Foundation
import UniformTypeIdentifiers

enum FileSystemService {
    static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isPackageKey,
        .contentModificationDateKey,
        .creationDateKey,
        .fileSizeKey,
        .localizedNameKey,
        .contentTypeKey,
        .typeIdentifierKey
    ]

    static func entries(in directory: URL) throws -> [FileEntry] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        )

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else {
                return nil
            }

            let isDirectory = values.isDirectory ?? false
            let isPackage = values.isPackage ?? false
            let size = values.fileSize.map(Int64.init)
            let typeIdentifier = values.typeIdentifier
            let contentType = values.contentType
            let name = values.localizedName ?? url.lastPathComponent
            let typeDescription: String

            if isDirectory && !isPackage {
                typeDescription = "folder"
            } else if let description = contentType?.localizedDescription {
                typeDescription = description
            } else if !url.pathExtension.isEmpty {
                typeDescription = url.pathExtension.lowercased()
            } else {
                typeDescription = "file"
            }

            return FileEntry(
                url: url,
                name: name,
                isDirectory: isDirectory,
                isPackage: isPackage,
                modified: values.contentModificationDate,
                created: values.creationDate,
                size: size,
                typeDescription: typeDescription,
                typeIdentifier: typeIdentifier
            )
        }
    }

    static func sort(_ entries: [FileEntry], by field: SortField, ascending: Bool) -> [FileEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }

            let result: ComparisonResult
            switch field {
            case .name:
                result = lhs.name.localizedStandardCompare(rhs.name)
            case .modified:
                result = compare(lhs.modified, rhs.modified)
            case .created:
                result = compare(lhs.created, rhs.created)
            case .size:
                result = compare(lhs.size, rhs.size)
            case .type:
                result = lhs.typeDescription.localizedStandardCompare(rhs.typeDescription)
            case .ext:
                result = lhs.fileExtension.localizedStandardCompare(rhs.fileExtension)
            }

            if result == .orderedSame {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    static func createFolder(in directory: URL) throws -> URL {
        let url = uniqueURL(in: directory, baseName: "未命名文件夹", extensionName: nil)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    static func createFile(in directory: URL) throws -> URL {
        let url = uniqueURL(in: directory, baseName: "未命名", extensionName: "txt")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }

    static func rename(_ url: URL, to newName: String) throws -> URL {
        let validName = try validatedFileName(newName)
        let parent = url.deletingLastPathComponent().standardizedFileURL
        let target = parent.appendingPathComponent(validName).standardizedFileURL
        guard target.deletingLastPathComponent().standardizedFileURL == parent else {
            throw FileSystemServiceError.invalidFileName(newName)
        }
        try FileManager.default.moveItem(at: url, to: target)
        return target
    }

    static func copy(_ urls: [URL], to directory: URL) throws {
        for url in urls {
            let target = uniqueURL(in: directory, originalName: url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: target)
        }
    }

    static func move(_ urls: [URL], to directory: URL) throws {
        let destinationDirectory = directory.standardizedFileURL
        for url in urls {
            let source = url.standardizedFileURL
            if source.deletingLastPathComponent().standardizedFileURL == destinationDirectory {
                continue
            }
            let target = uniqueURL(in: destinationDirectory, originalName: source.lastPathComponent)
            try FileManager.default.moveItem(at: source, to: target)
        }
    }

    static func trash(_ urls: [URL]) throws {
        for url in urls {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        }
    }

    static func mountedVolumes() -> [URL] {
        FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeIsEjectableKey],
            options: [.skipHiddenVolumes]
        ) ?? []
    }

    static func areOnSameVolume(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let lhsSystemNumber = fileSystemNumber(for: lhs),
              let rhsSystemNumber = fileSystemNumber(for: rhs) else {
            return false
        }
        return lhsSystemNumber == rhsSystemNumber
    }

    private static func fileSystemNumber(for url: URL) -> Int? {
        let path = nearestExistingPath(for: url)
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: path) else {
            return nil
        }
        if let number = attributes[.systemNumber] as? NSNumber {
            return number.intValue
        }
        return attributes[.systemNumber] as? Int
    }

    private static func nearestExistingPath(for url: URL) -> String {
        var candidate = url.standardizedFileURL
        while !FileManager.default.fileExists(atPath: candidate.path) {
            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else { break }
            candidate = parent
        }
        return candidate.path
    }

    static func appIcon(for entry: FileEntry) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: entry.url.path)
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }

    static func formattedSize(_ entry: FileEntry) -> String {
        guard !entry.isDirectory, let size = entry.size else {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    static func formattedDate(_ date: Date?) -> String {
        guard let date else { return "--" }
        return DateFormatters.fileDate.string(from: date)
    }

    static func uniqueURL(in directory: URL, originalName: String) -> URL {
        let original = directory.appendingPathComponent(originalName)
        if !FileManager.default.fileExists(atPath: original.path) {
            return original
        }

        let base = (originalName as NSString).deletingPathExtension
        let ext = (originalName as NSString).pathExtension
        return uniqueURL(in: directory, baseName: base, extensionName: ext.isEmpty ? nil : ext)
    }

    static func uniqueURL(in directory: URL, baseName: String, extensionName: String?) -> URL {
        func candidate(_ index: Int?) -> URL {
            let suffix = index.map { " \($0)" } ?? ""
            let name = baseName + suffix
            if let extensionName, !extensionName.isEmpty {
                return directory.appendingPathComponent(name).appendingPathExtension(extensionName)
            }
            return directory.appendingPathComponent(name)
        }

        var index: Int?
        while true {
            let url = candidate(index)
            if !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            index = (index ?? 1) + 1
        }
    }

    private static func validatedFileName(_ name: String) throws -> String {
        guard !name.isEmpty,
              name != ".",
              name != "..",
              name.rangeOfCharacter(from: CharacterSet(charactersIn: "/:")) == nil else {
            throw FileSystemServiceError.invalidFileName(name)
        }
        return name
    }

    private static func compare<T: Comparable>(_ lhs: T?, _ rhs: T?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if lhs == rhs { return .orderedSame }
            return lhs < rhs ? .orderedAscending : .orderedDescending
        case (nil, nil):
            return .orderedSame
        case (nil, _):
            return .orderedDescending
        case (_, nil):
            return .orderedAscending
        }
    }
}

enum FileSystemServiceError: LocalizedError {
    case invalidFileName(String)

    var errorDescription: String? {
        switch self {
        case let .invalidFileName(name):
            "无效文件名：\(name)"
        }
    }
}

enum DateFormatters {
    static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
