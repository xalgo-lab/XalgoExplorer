# XalgoExplorer

XalgoExplorer is a native macOS file manager for Windows users switching to macOS.

The goal is to make the transition easier: keep the direct file-management habits Windows users know, while fitting into macOS as a native app.

## Highlights

- Multi-pane workspace for browsing several folders at once.
- Familiar toolbar actions: back, forward, up, refresh, new folder, new file, cut, copy, and paste.
- Drag-and-drop behavior that follows Finder-style rules: move on the same disk, copy across disks.
- Compact sidebar for home folders, user shortcuts, mounted drives, and network locations.
- Keyboard navigation and mouse selection for file lists and grids.
- Multilingual labels and tooltips.
- DMG packaging for macOS installation.

## Candidate Release

The `v0.1.1-candidate` build targets Apple Silicon macOS 14 or later.

Download the DMG from GitHub Releases, open it, and drag `xAlgo Explorer.app` into `Applications`.

## Version Notes

### v0.1.1-candidate

- Fixed stale internal drag data so a cancelled drag cannot move the wrong file later.
- Rejected unsafe rename inputs such as `../file` or `a/b`.
- Made cut-and-paste back into the original folder a no-op instead of creating a duplicate.
- Added Finder-compatible file copy and paste through the system pasteboard.
- Added a visible search close control and Escape handling so arrow keys return to file navigation.
- Replaced the fake network device with an empty network state until real discovery is implemented.
- Updated candidate metadata, package naming, README notes, and regression tests.

### v0.1.0-candidate

Initial public candidate with native macOS packaging, multi-pane browsing, drag-and-drop file operations, keyboard navigation, localized tooltips, and signed Apple Silicon DMG packaging.

## License

MIT License.
