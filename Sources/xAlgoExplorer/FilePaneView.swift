import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum FilePaneRole {
    case main
    case assist
}

struct DirectoryNavigationDropDelegate: DropDelegate {
    static let acceptedTypes: [UTType] = [.xAlgoInternalFileDrag, .fileURL]

    let model: ExplorerModel
    let pane: PaneState
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        if model.hasActiveInternalDrag {
            return model.canNavigateActiveInternalDragToDirectory()
        }
        return info.hasItemsConforming(to: Self.acceptedTypes)
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        validateDrop(info: info)
            ? DropProposal(operation: .copy)
            : DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        guard validateDrop(info: info) else { return false }
        return model.navigateToDroppedDirectory(
            info.itemProviders(for: Self.acceptedTypes),
            in: pane
        )
    }
}

struct FileDropDelegate: DropDelegate {
    static let acceptedTypes: [UTType] = [.xAlgoInternalFileDrag, .fileURL]

    let model: ExplorerModel
    let pane: PaneState
    let targetDirectory: URL
    let allowsDrop: Bool
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        allowsDrop && info.hasItemsConforming(to: Self.acceptedTypes)
    }

    func dropEntered(info: DropInfo) {
        guard allowsDrop else { return }
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard allowsDrop else {
            return DropProposal(operation: .cancel)
        }

        let intent = FileDropIntent(modifierFlags: NSEvent.modifierFlags)
        if model.hasActiveInternalDrag {
            guard let operation = model.activeInternalDropOperation(into: targetDirectory, intent: intent) else {
                return DropProposal(operation: .cancel)
            }
            return DropProposal(operation: operation.dropProposalOperation)
        }

        if info.hasItemsConforming(to: [.xAlgoInternalFileDrag]) {
            if intent == .forceCopy {
                return DropProposal(operation: .copy)
            }
            return DropProposal(operation: .move)
        }

        return DropProposal(operation: intent == .forceMove ? .move : .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        guard allowsDrop else { return false }
        let intent = FileDropIntent(modifierFlags: NSEvent.modifierFlags)
        if model.hasActiveInternalDrag,
           model.activeInternalDropOperation(into: targetDirectory, intent: intent) == nil {
            return false
        }
        model.setFocus(pane.id)
        return model.handleDrop(
            info.itemProviders(for: Self.acceptedTypes),
            into: targetDirectory,
            intent: intent
        )
    }
}

private extension FileDropOperation {
    var dropProposalOperation: DropOperation {
        switch self {
        case .copy:
            return .copy
        case .move:
            return .move
        }
    }
}

private extension View {
    @ViewBuilder
    func fileDropTarget(isEnabled: Bool, delegate: FileDropDelegate) -> some View {
        if isEnabled {
            self.onDrop(of: FileDropDelegate.acceptedTypes, delegate: delegate)
        } else {
            self
        }
    }

    func reportsSelectionFrame(for entry: FileEntry, in pane: PaneState) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FileEntryFramePreferenceKey.self,
                    value: [entry.id: proxy.frame(in: .named(FileSelectionCoordinateSpace.name(for: pane)))]
                )
            }
        )
    }
}

private enum FileSelectionCoordinateSpace {
    static func name(for pane: PaneState) -> String {
        "file-selection-\(pane.id.rawValue)"
    }
}

private struct FileEntryFramePreferenceKey: PreferenceKey {
    static let defaultValue: [FileEntry.ID: CGRect] = [:]

    static func reduce(value: inout [FileEntry.ID: CGRect], nextValue: () -> [FileEntry.ID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct FileSelectionSurface<Content: View>: View {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState
    @State private var entryFrames: [FileEntry.ID: CGRect] = [:]
    @State private var selectionRect: CGRect?
    @State private var dragStartedOnEntry = false
    let content: Content

    init(pane: PaneState, @ViewBuilder content: () -> Content) {
        self.pane = pane
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .coordinateSpace(name: FileSelectionCoordinateSpace.name(for: pane))
            .onPreferenceChange(FileEntryFramePreferenceKey.self) { frames in
                entryFrames = frames
            }
            .contentShape(Rectangle())
            .simultaneousGesture(blankTapGesture)
            .simultaneousGesture(selectionDragGesture)
            .overlay(alignment: .topLeading) {
                if let selectionRect {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.16))
                        .overlay(
                            Rectangle()
                                .stroke(Color.accentColor.opacity(0.72), lineWidth: 1)
                        )
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .offset(x: selectionRect.minX, y: selectionRect.minY)
                        .allowsHitTesting(false)
                }
            }
    }

    private var blankTapGesture: some Gesture {
        SpatialTapGesture(count: 1, coordinateSpace: .named(FileSelectionCoordinateSpace.name(for: pane)))
            .onEnded { value in
                model.clearSelectionIfBlankClick(
                    at: value.location,
                    frames: entryFrames,
                    in: pane
                )
            }
    }

    private var selectionDragGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named(FileSelectionCoordinateSpace.name(for: pane)))
            .onChanged { value in
                if selectionRect == nil {
                    dragStartedOnEntry = entryFrames.values.contains { $0.contains(value.startLocation) }
                    if !dragStartedOnEntry {
                        model.setFocus(pane.id)
                    }
                }

                guard !dragStartedOnEntry else { return }
                let rect = CGRect(
                    x: min(value.startLocation.x, value.location.x),
                    y: min(value.startLocation.y, value.location.y),
                    width: abs(value.location.x - value.startLocation.x),
                    height: abs(value.location.y - value.startLocation.y)
                )
                selectionRect = rect
                model.selectEntries(
                    intersecting: rect,
                    frames: entryFrames,
                    in: pane,
                    modifiers: NSEvent.modifierFlags
                )
            }
            .onEnded { _ in
                selectionRect = nil
                dragStartedOnEntry = false
            }
    }
}

private struct PaneBlankContextMenuBackground: View {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .contentShape(Rectangle())
            .contextMenu {
                Button("粘贴") {
                    model.setFocus(pane.id)
                    model.pasteClipboard(in: pane, to: pane.url)
                }
                .disabled(!model.canPaste(in: pane))
            }
    }
}

struct FilePaneView: View {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState
    let role: FilePaneRole
    @State private var isDropTarget = false

    private var isFocused: Bool {
        model.focusedPaneID == pane.id
    }

    var body: some View {
        VStack(spacing: 0) {
            if role == .assist {
                AssistPaneHeaderView(pane: pane)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            if pane.virtualPage == .network {
                NetworkPaneView()
            } else {
                switch pane.viewMode {
                case .list:
                    ResizableListPaneView(pane: pane, role: role)
                case .files:
                    FileGridView(pane: pane, role: role)
                case .preview:
                    if pane.id == .main {
                        PreviewGridView(pane: pane)
                    } else {
                        FileGridView(pane: pane, role: role)
                    }
                }
            }
        }
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: role == .main ? 0 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: role == .main ? 0 : 18, style: .continuous)
                .stroke(isFocused && role == .assist ? Color.selectedCapsule : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.setFocus(pane.id)
        }
        .background(
            RoundedRectangle(cornerRadius: role == .main ? 0 : 18, style: .continuous)
                .fill(isDropTarget ? Color.selectedCapsule.opacity(0.45) : .clear)
        )
        .onDrop(
            of: FileDropDelegate.acceptedTypes,
            delegate: FileDropDelegate(
                model: model,
                pane: pane,
                targetDirectory: pane.url,
                allowsDrop: pane.isLocalDirectory,
                isTargeted: $isDropTarget
            )
        )
    }

    @ViewBuilder
    private var background: some View {
        if role == .assist {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 34, y: 18)
        } else {
            Color.clear
        }
    }
}

struct AssistPaneHeaderView: View {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState
    @State private var isDirectoryDropTarget = false

    var body: some View {
        HStack(spacing: 8) {
            CommandIconButton(model.text(.tooltipGoUp), systemName: "chevron.up") {
                model.goUp(pane)
            }
            .disabled(!pane.canGoUp)

            CommandIconButton(model.text(.tooltipBack), systemName: "chevron.left") {
                model.goBack(pane)
            }
            .disabled(!pane.canGoBack)

            CommandIconButton(model.text(.tooltipForward), systemName: "chevron.right") {
                model.goForward(pane)
            }
            .disabled(!pane.canGoForward)

            Spacer(minLength: 0)

            Text(pane.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(titleBackground)
                )
                .help(model.text(.tooltipCopyPath))
                .onTapGesture(count: 2) {
                    model.copyPath(of: pane)
                }
                .onDrop(
                    of: DirectoryNavigationDropDelegate.acceptedTypes,
                    delegate: DirectoryNavigationDropDelegate(
                        model: model,
                        pane: pane,
                        isTargeted: $isDirectoryDropTarget
                    )
                )

            Spacer(minLength: 0)

            SortMenuView(pane: pane)
                .frame(width: 38)

            ViewModeMenuView(pane: pane)
                .frame(width: 38)
        }
        .frame(height: 34)
    }

    private var titleBackground: Color {
        if isDirectoryDropTarget {
            return Color.selectedCapsule.opacity(0.72)
        }
        if model.focusedPaneID == pane.id {
            return Color.selectedCapsule
        }
        return .clear
    }
}

struct ResizableListPaneView: View {
    @ObservedObject var pane: PaneState
    let role: FilePaneRole

    private var horizontalPadding: CGFloat {
        role == .main ? 11 : 10
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    ColumnHeaderView(pane: pane, role: role)
                        .frame(width: contentWidth(for: geometry.size.width), alignment: .leading)

                    FileListView(pane: pane, role: role)
                        .frame(width: contentWidth(for: geometry.size.width), alignment: .leading)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: contentWidth(for: geometry.size.width), height: geometry.size.height, alignment: .topLeading)
            }
        }
    }

    private func contentWidth(for availableWidth: CGFloat) -> CGFloat {
        max(pane.totalColumnWidth + horizontalPadding * 2, availableWidth)
    }
}

struct ColumnHeaderView: View {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState
    let role: FilePaneRole

    var body: some View {
        HStack(spacing: 0) {
            HeaderCell(title: "文件名", field: .name, leadingResizeColumn: nil, trailingResizeColumn: nil, pane: pane, alignment: .leading)
                .frame(width: pane.columnNameWidth, alignment: .leading)
            HeaderCell(title: "修改日期", field: .modified, leadingResizeColumn: .name, trailingResizeColumn: nil, pane: pane, alignment: .leading)
                .frame(width: pane.columnModifiedWidth, alignment: .leading)
            HeaderCell(title: "类型", field: .type, leadingResizeColumn: .modified, trailingResizeColumn: nil, pane: pane, alignment: .leading)
                .frame(width: pane.columnTypeWidth, alignment: .leading)
            HeaderCell(title: "大小", field: .size, leadingResizeColumn: .type, trailingResizeColumn: .size, pane: pane, alignment: .trailing)
                .frame(width: pane.columnSizeWidth, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .regular))
        .foregroundStyle(.secondary)
        .frame(height: 26)
        .padding(.horizontal, role == .main ? 11 : 10)
    }
}

struct HeaderCell: View {
    @EnvironmentObject private var model: ExplorerModel
    let title: String
    let field: SortField
    let leadingResizeColumn: FileColumn?
    let trailingResizeColumn: FileColumn?
    @ObservedObject var pane: PaneState
    let alignment: Alignment
    @State private var dragStartWidth: CGFloat?

    var body: some View {
        ZStack(alignment: .leading) {
            Button {
                model.setSortField(field, pane: pane)
            } label: {
                HStack(spacing: 4) {
                    Text(title)
                        .lineLimit(1)
                    if pane.sortField == field {
                        Text(pane.sortAscending ? "↑" : "↓")
                            .font(.system(size: 10))
                    }
                }
                .frame(maxWidth: .infinity, alignment: alignment)
                .padding(.leading, leadingResizeColumn == nil ? 3 : 9)
                .padding(.trailing, trailingResizeColumn == nil ? 3 : 9)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)

            if let leadingResizeColumn {
                resizeHandle(for: leadingResizeColumn, alignment: .leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            if let trailingResizeColumn {
                resizeHandle(for: trailingResizeColumn, alignment: .trailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .contextMenu {
            Text("显示文件名")
            Text("显示修改日期")
            Text("显示类型")
            Text("显示大小")
        }
    }

    private func resizeHandle(for column: FileColumn, alignment: Alignment) -> some View {
        Rectangle()
            .fill(Color.controlBorder)
            .frame(width: 1, height: 14)
            .frame(width: 12, height: 22, alignment: alignment)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartWidth == nil {
                            dragStartWidth = pane.width(for: column)
                        }
                        let nextWidth = (dragStartWidth ?? pane.width(for: column)) + value.translation.width
                        applyColumnWidth(nextWidth, for: column, persist: false)
                    }
                    .onEnded { value in
                        if let dragStartWidth {
                            applyColumnWidth(dragStartWidth + value.translation.width, for: column, persist: true)
                        }
                        dragStartWidth = nil
                    }
            )
    }

    private func applyColumnWidth(_ width: CGFloat, for column: FileColumn, persist: Bool) {
        let roundedWidth = width.rounded(.toNearestOrAwayFromZero)
        let currentWidth = pane.width(for: column)
        if !persist && abs(currentWidth - roundedWidth) < 1 {
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if persist {
                model.setColumnWidth(roundedWidth, for: column, in: pane)
            } else {
                pane.setWidth(roundedWidth, for: column)
            }
        }
    }
}

struct FileListView: View {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState
    let role: FilePaneRole
    @State private var isDropTarget = false

    var body: some View {
        GeometryReader { geometry in
            FileSelectionSurface(pane: pane) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let error = pane.errorMessage {
                            EmptyStateView(symbolName: "exclamationmark.triangle", title: error)
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else if model.displayedEntries(for: pane).isEmpty {
                            EmptyStateView(symbolName: "tray", title: "没有文件")
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            ForEach(model.displayedEntries(for: pane)) { entry in
                                FileListRow(entry: entry, pane: pane, role: role)
                            }
                        }
                    }
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .topLeading)
                    .background(PaneBlankContextMenuBackground(pane: pane))
                    .transaction { transaction in
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
                }
                .scrollContentBackground(.hidden)
                .onAppear {
                    model.updateKeyboardColumnCount(1, in: pane)
                }
            }
            .animation(nil, value: pane.columnNameWidth)
            .animation(nil, value: pane.columnModifiedWidth)
            .animation(nil, value: pane.columnTypeWidth)
            .animation(nil, value: pane.columnSizeWidth)
            .background(
                RoundedRectangle(cornerRadius: role == .main ? 0 : 12, style: .continuous)
                    .fill(isDropTarget ? Color.selectedCapsule.opacity(0.38) : .clear)
            )
            .onDrop(
                of: FileDropDelegate.acceptedTypes,
                delegate: FileDropDelegate(
                    model: model,
                    pane: pane,
                    targetDirectory: pane.url,
                    allowsDrop: pane.isLocalDirectory,
                    isTargeted: $isDropTarget
                )
            )
        }
    }
}

struct FileListRow: View {
    @EnvironmentObject private var model: ExplorerModel
    let entry: FileEntry
    @ObservedObject var pane: PaneState
    let role: FilePaneRole
    @State private var isHovering = false
    @State private var isDropTarget = false

    private var selected: Bool {
        pane.selectedIDs.contains(entry.id)
    }

    private var horizontalPadding: CGFloat {
        role == .main ? 11 : 10
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                FileIconView(entry: entry, size: role == .main ? 22 : 18)
                FileNameContent(entry: entry, pane: pane)
            }
            .frame(width: pane.columnNameWidth, alignment: .leading)

            Text(FileSystemService.formattedDate(entry.modified))
                .fileMetaStyle()
                .frame(width: pane.columnModifiedWidth, alignment: .leading)

            Text(entry.typeDescription)
                .fileMetaStyle()
                .frame(width: pane.columnTypeWidth, alignment: .leading)

            Text(FileSystemService.formattedSize(entry))
                .fileMetaStyle()
                .frame(width: pane.columnSizeWidth, alignment: .trailing)
        }
        .frame(height: role == .main ? 34 : 28)
        .padding(.horizontal, horizontalPadding)
        .frame(width: pane.totalColumnWidth + horizontalPadding * 2, alignment: .leading)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: selected || isHovering ? 12 : 0, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            model.primaryClick(entry, in: pane)
        }
        .onDrag {
            model.dragProvider(for: entry, in: pane)
        }
        .fileDropTarget(
            isEnabled: entry.isDirectory && !entry.isPackage,
            delegate: FileDropDelegate(
                model: model,
                pane: pane,
                targetDirectory: entry.url,
                allowsDrop: true,
                isTargeted: $isDropTarget
            )
        )
        .contextMenu {
            FileContextMenu(entry: entry, pane: pane)
        }
        .reportsSelectionFrame(for: entry, in: pane)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isDropTarget {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.selectedCapsule.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.7), lineWidth: 1)
                )
        } else if selected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.selectedCapsule)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.controlBorder, lineWidth: 0.5)
                )
        } else if isHovering {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.rowHover)
        } else {
            Color.clear
        }
    }
}

struct FileGridView: View {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState
    let role: FilePaneRole
    @State private var isDropTarget = false

    var body: some View {
        GeometryReader { geometry in
            FileSelectionSurface(pane: pane) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: role == .main ? 8 : 4) {
                        ForEach(model.displayedEntries(for: pane)) { entry in
                            FileTileView(entry: entry, pane: pane, role: role)
                        }
                    }
                    .padding(role == .main ? 8 : 6)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .topLeading)
                    .background(PaneBlankContextMenuBackground(pane: pane))
                }
                .onAppear {
                    model.updateKeyboardColumnCount(columnCount(for: geometry.size.width), in: pane)
                }
                .onChange(of: geometry.size.width) { _, width in
                    model.updateKeyboardColumnCount(columnCount(for: width), in: pane)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: role == .main ? 0 : 12, style: .continuous)
                    .fill(isDropTarget ? Color.selectedCapsule.opacity(0.38) : .clear)
            )
            .onDrop(
                of: FileDropDelegate.acceptedTypes,
                delegate: FileDropDelegate(
                    model: model,
                    pane: pane,
                    targetDirectory: pane.url,
                    allowsDrop: pane.isLocalDirectory,
                    isTargeted: $isDropTarget
                )
            )
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: role == .main ? 112 : 76), spacing: role == .main ? 4 : 2)]
    }

    private func columnCount(for width: CGFloat) -> Int {
        let minWidth = role == .main ? 112.0 : 76.0
        let spacing = role == .main ? 4.0 : 2.0
        let horizontalPadding = role == .main ? 16.0 : 12.0
        let usableWidth = max(0, width - horizontalPadding)
        return max(1, Int((usableWidth + spacing) / (minWidth + spacing)))
    }
}

struct FileTileView: View {
    @EnvironmentObject private var model: ExplorerModel
    let entry: FileEntry
    @ObservedObject var pane: PaneState
    let role: FilePaneRole
    @State private var isHovering = false
    @State private var isDropTarget = false

    private var selected: Bool {
        pane.selectedIDs.contains(entry.id)
    }

    var body: some View {
        VStack(spacing: 6) {
            FileIconView(entry: entry, size: role == .main ? 44 : 32)

            FileNameContent(entry: entry, pane: pane)
                .font(.system(size: role == .main ? 13 : 11))
                .frame(maxWidth: .infinity)
        }
        .frame(minHeight: role == .main ? 92 : 72)
        .padding(role == .main ? 8 : 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tileBackground)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            model.primaryClick(entry, in: pane)
        }
        .onDrag {
            model.dragProvider(for: entry, in: pane)
        }
        .fileDropTarget(
            isEnabled: entry.isDirectory && !entry.isPackage,
            delegate: FileDropDelegate(
                model: model,
                pane: pane,
                targetDirectory: entry.url,
                allowsDrop: true,
                isTargeted: $isDropTarget
            )
        )
        .contextMenu {
            FileContextMenu(entry: entry, pane: pane)
        }
        .reportsSelectionFrame(for: entry, in: pane)
    }

    private var tileBackground: Color {
        if isDropTarget {
            return Color.selectedCapsule.opacity(0.72)
        }
        if selected {
            return Color.selectedCapsule
        }
        if isHovering {
            return Color.rowHover
        }
        return .clear
    }
}

struct PreviewGridView: View {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState
    @State private var isDropTarget = false

    var body: some View {
        GeometryReader { geometry in
            FileSelectionSurface(pane: pane) {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 16)], spacing: 18) {
                        ForEach(model.displayedEntries(for: pane)) { entry in
                            PreviewTileView(entry: entry, pane: pane)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .topLeading)
                    .background(PaneBlankContextMenuBackground(pane: pane))
                }
                .onAppear {
                    model.updateKeyboardColumnCount(previewColumnCount(for: geometry.size.width), in: pane)
                }
                .onChange(of: geometry.size.width) { _, width in
                    model.updateKeyboardColumnCount(previewColumnCount(for: width), in: pane)
                }
            }
            .background(
                Rectangle()
                    .fill(isDropTarget ? Color.selectedCapsule.opacity(0.38) : .clear)
            )
            .onDrop(
                of: FileDropDelegate.acceptedTypes,
                delegate: FileDropDelegate(
                    model: model,
                    pane: pane,
                    targetDirectory: pane.url,
                    allowsDrop: pane.isLocalDirectory,
                    isTargeted: $isDropTarget
                )
            )
        }
    }

    private func previewColumnCount(for width: CGFloat) -> Int {
        let usableWidth = max(0, width - 28)
        return max(1, Int((usableWidth + 16) / (156 + 16)))
    }
}

struct PreviewTileView: View {
    @EnvironmentObject private var model: ExplorerModel
    @EnvironmentObject private var thumbnails: ThumbnailCache
    let entry: FileEntry
    @ObservedObject var pane: PaneState
    @State private var isHovering = false
    @State private var isDropTarget = false

    private var selected: Bool {
        pane.selectedIDs.contains(entry.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                previewContent
                    .frame(width: 140, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                FileNameContent(entry: entry, pane: pane)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .frame(maxWidth: 130)
                    .background(Capsule().fill(Color.previewLabelBackground))
                    .overlay(Capsule().stroke(Color.controlBorder, lineWidth: 0.5))
                    .padding(.bottom, 5)
            }
        }
        .frame(width: 156)
        .frame(minHeight: 128)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tileBackground)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onAppear {
            thumbnails.request(url: entry.url, size: CGSize(width: 280, height: 224))
        }
        .onTapGesture {
            model.primaryClick(entry, in: pane)
        }
        .onDrag {
            model.dragProvider(for: entry, in: pane)
        }
        .fileDropTarget(
            isEnabled: entry.isDirectory && !entry.isPackage,
            delegate: FileDropDelegate(
                model: model,
                pane: pane,
                targetDirectory: entry.url,
                allowsDrop: true,
                isTargeted: $isDropTarget
            )
        )
        .contextMenu {
            FileContextMenu(entry: entry, pane: pane)
        }
        .reportsSelectionFrame(for: entry, in: pane)
    }

    private var tileBackground: Color {
        if isDropTarget {
            return Color.selectedCapsule.opacity(0.72)
        }
        if selected {
            return Color.selectedCapsule
        }
        if isHovering {
            return Color.rowHover
        }
        return .clear
    }

    @ViewBuilder
    private var previewContent: some View {
        if let image = thumbnails.image(for: entry.url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            FileIconView(entry: entry, size: 82)
        }
    }
}

struct FileNameContent: View {
    @EnvironmentObject private var model: ExplorerModel
    let entry: FileEntry
    @ObservedObject var pane: PaneState
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if pane.renamingID == entry.id {
                TextField("", text: $pane.renameDraft)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit {
                        model.commitRename(in: pane)
                    }
                    .onExitCommand {
                        model.cancelRename(in: pane)
                    }
                    .onAppear {
                        focused = true
                    }
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused {
                            model.commitRename(in: pane)
                        }
                    }
            } else {
                Text(entry.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}

struct FileIconView: View {
    let entry: FileEntry
    let size: CGFloat

    var body: some View {
        Image(nsImage: FileSystemService.appIcon(for: entry))
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

enum FileContextMenuLayout {
    static let chooseApplicationOpenTitle = "选择应用打开"
    static let copyURLTitle = "复制URL"
    static let topActionTitles = [chooseApplicationOpenTitle, copyURLTitle]
}

struct FileContextMenu: View {
    @EnvironmentObject private var model: ExplorerModel
    let entry: FileEntry
    @ObservedObject var pane: PaneState

    var body: some View {
        Button(FileContextMenuLayout.chooseApplicationOpenTitle) {
            model.chooseApplicationAndOpen(entry, in: pane)
        }

        Button(FileContextMenuLayout.copyURLTitle) {
            model.copyURL(of: entry)
        }

        Divider()

        Button("剪切") {
            model.select(entry, in: pane)
            model.cutSelection()
        }

        Button("复制") {
            model.select(entry, in: pane)
            model.copySelection()
        }

        Button("粘贴") {
            let destination = entry.isDirectory && !entry.isPackage ? entry.url : pane.url
            model.setFocus(pane.id)
            model.pasteClipboard(to: destination)
        }
        .disabled(!model.canPaste)

        Divider()

        Button("删除") {
            model.select(entry, in: pane)
            model.trashSelection()
        }

        Button("重命名") {
            model.beginRename(entry, in: pane)
        }

        Button("属性") {
            model.showInfo(for: entry)
        }
    }
}

struct NetworkPaneView: View {
    @EnvironmentObject private var model: ExplorerModel
    private let devices = ["TS-416-QK6WQ01"]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 24)], spacing: 26) {
                ForEach(filteredDevices, id: \.self) { device in
                    VStack(spacing: 10) {
                        Image(systemName: "network")
                            .font(.system(size: 54, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text(device)
                            .font(.system(size: 13, weight: .regular))
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .frame(height: 28)
                            .background(Capsule().fill(.regularMaterial))
                            .overlay(Capsule().stroke(Color.controlBorder, lineWidth: 0.5))
                    }
                    .frame(width: 180, height: 150)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("连接") {}
                            .disabled(true)
                    }
                }
            }
            .padding(.top, 110)
            .padding(.horizontal, 80)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            if filteredDevices.isEmpty {
                EmptyStateView(symbolName: "network.slash", title: "没有发现内网计算机")
                    .frame(maxWidth: .infinity, minHeight: 260)
            }
        }
    }

    private var filteredDevices: [String] {
        guard !model.searchText.isEmpty else { return devices }
        return devices.filter { $0.localizedCaseInsensitiveContains(model.searchText) }
    }
}

struct EmptyStateView: View {
    let symbolName: String
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

extension View {
    func fileMetaStyle() -> some View {
        self
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
