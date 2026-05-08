# XalgoExplorer

XalgoExplorer is a native macOS file manager designed for Windows users who are moving to macOS.

It keeps familiar desktop-file workflows close at hand while adopting macOS conventions: a clean native window, multi-pane browsing, drag-and-drop file operations, keyboard navigation, localized tooltips, and a compact sidebar for daily locations and mounted drives.

## Why It Exists

Many Windows users moving to macOS miss a file manager that feels direct, visible, and keyboard-friendly. XalgoExplorer focuses on that transition:

- Familiar multi-pane file browsing for comparing and moving files.
- Finder-style copy and move behavior across disks.
- Clear toolbar actions for back, forward, up, refresh, new folder, new file, cut, copy, and paste.
- A compact icon rail for Home, Pictures, Desktop, Downloads, Documents, Music, Videos, mounted drives, and network locations.
- Localized labels and tooltips for international users.
- Native macOS packaging as an app bundle and DMG installer.

## Candidate Build

The latest candidate build is published on the GitHub Releases page:

- Version: `v0.1.1-candidate`
- Platform: Apple Silicon macOS
- Minimum macOS: 14.0
- Package: `xAlgo_Explorer_v0.1.1-candidate_aarch64.dmg`

## Version Notes

### v0.1.1-candidate

This candidate focuses on file-operation safety, packaging hygiene, and UI reliability:

- Fixed stale internal drag payload handling so a cancelled drag cannot hijack a later file drop.
- Added rename validation for path traversal and path separators, preventing names like `../file` or `a/b` from becoming cross-directory moves.
- Changed cut-and-paste back into the original directory to a no-op instead of silently creating duplicate names.
- Added Finder-compatible system pasteboard support for copying and pasting file URLs between Finder and xAlgo Explorer.
- Added a clear close path for search and released search focus so arrow-key navigation returns to the file list.
- Replaced the hardcoded network device placeholder with an empty network discovery state until real discovery is implemented.
- Updated the candidate version metadata and packaged DMG naming to `v0.1.1-candidate`.

### v0.1.0-candidate

Initial public candidate with the native macOS file manager shell, multi-pane layout, icon rail, localized tooltips, drag-and-drop file operations, keyboard navigation, and signed Apple Silicon app/DMG packaging.

## Build From Source

Requirements:

- Apple Silicon Mac
- macOS 14 or later
- Xcode command line tools
- Swift 6 toolchain

Commands:

```sh
swift test
make app
make dmg
```

The packaged app and DMG are written to `dist/`.

## Languages

Documentation is available in:

- [English](docs/en.md)
- [简体中文](docs/zh-CN.md)
- [日本語](docs/ja.md)
- [한국어](docs/ko.md)
- [Deutsch](docs/de.md)
- [Français](docs/fr.md)
- [Español](docs/es.md)

## License

XalgoExplorer is released under the MIT License. See [LICENSE](LICENSE).
