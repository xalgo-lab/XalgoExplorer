import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var model: ExplorerModel
    @State private var railPeekOpen = false

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                WorkspaceView(railPeekOpen: $railPeekOpen)
            }
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.66))
        }
        .overlay(WindowConfigurator { event in
            model.handleKeyDown(event)
        })
        .alert(item: $model.error) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("确定"))
            )
        }
        .sheet(item: $model.fileInfo) { info in
            FileInfoView(info: info)
        }
        .sheet(isPresented: $model.showingAbout) {
            AboutView()
        }
    }
}

struct WorkspaceView: View {
    @EnvironmentObject private var model: ExplorerModel
    @Binding var railPeekOpen: Bool
    @State private var railBodyHovering = false
    @State private var railTriggerHovering = false
    @State private var railDropTarget = false

    var body: some View {
        let railContentHeight = RailPeekLayout.railContentHeight(
            defaultCount: model.defaultSidebarTargets.count,
            userCount: model.userSidebarTargets.count,
            utilityCount: model.utilitySidebarTargets.count
        )

        ZStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 0) {
                if !model.hideRail && !model.assistOpen {
                    VStack {
                        Spacer(minLength: 0)
                        RailView()
                        Spacer(minLength: 0)
                    }
                    .frame(width: RailPeekLayout.dockedRailSlotWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onDrop(of: RailShortcutDropTypes.accepted, isTargeted: $railDropTarget) { providers in
                        model.handleSidebarShortcutDrop(providers)
                    }
                }

                ExplorerShellView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !model.hideRail && model.assistOpen {
                VStack {
                    Spacer(minLength: 0)
                    ZStack(alignment: .leading) {
                        RailView()
                            .frame(width: RailPeekLayout.railBodyWidth, alignment: .leading)
                            .offset(x: RailPeekLayout.railOffset(isOpen: railPeekOpen))
                            .animation(.smooth(duration: 0.24), value: railPeekOpen)
                            .onHover { hovering in
                                railBodyHovering = hovering
                                railPeekOpen = RailPeekLayout.shouldOpen(
                                    isRailHovering: railBodyHovering,
                                    isTriggerHovering: railTriggerHovering,
                                    isDropTarget: railDropTarget
                                )
                            }

                        if !railPeekOpen {
                            CollapsedRailStripView(height: railContentHeight)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                        }

                        RailPeekTriggerView(
                            width: RailPeekLayout.triggerWidth(isDropTarget: railDropTarget),
                            height: railContentHeight,
                            isDropTarget: $railDropTarget,
                            onHover: { hovering in
                                railTriggerHovering = hovering
                                railPeekOpen = RailPeekLayout.shouldOpen(
                                    isRailHovering: railBodyHovering,
                                    isTriggerHovering: railTriggerHovering,
                                    isDropTarget: railDropTarget
                                )
                            },
                            onDrop: { urls in
                                model.addSidebarShortcuts(urls)
                            }
                        )
                        .onHover { hovering in
                            railTriggerHovering = hovering
                            railPeekOpen = RailPeekLayout.shouldOpen(
                                isRailHovering: railBodyHovering,
                                isTriggerHovering: railTriggerHovering,
                                isDropTarget: railDropTarget
                            )
                        }
                        .zIndex(2)
                    }
                    .frame(width: RailPeekLayout.hitWidth(isOpen: railPeekOpen), alignment: .leading)
                    .clipped()
                    .animation(.smooth(duration: 0.24), value: railPeekOpen)
                    .onChange(of: railDropTarget) { _, targeted in
                        railPeekOpen = RailPeekLayout.shouldOpen(
                            isRailHovering: railBodyHovering,
                            isTriggerHovering: railTriggerHovering,
                            isDropTarget: targeted
                        )
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: RailPeekLayout.hitWidth(isOpen: railPeekOpen), alignment: .leading)
                .frame(maxHeight: .infinity)
                .zIndex(10)
            }
        }
    }
}

struct CollapsedRailStripView: View {
    let height: CGFloat

    var body: some View {
        Capsule()
            .fill(.clear)
            .frame(width: RailPeekLayout.collapsedHitWidth)
            .frame(height: height)
            .capsuleSurface()
            .clipShape(Capsule())
    }
}

enum RailPeekLayout {
    static let collapsedHitWidth: CGFloat = 14
    static let expandedHitWidth: CGFloat = 62
    static let railBodyWidth: CGFloat = expandedHitWidth
    static let railIconColumnWidth: CGFloat = 44
    static let railLeadingPadding: CGFloat = 10
    static let railTrailingPadding: CGFloat = railBodyWidth - railIconColumnWidth - railLeadingPadding
    static let dockedRailSlotWidth: CGFloat = railBodyWidth
    static let railButtonSize: CGFloat = 30
    static let railStackSpacing: CGFloat = 4
    static let railVerticalPadding: CGFloat = 8
    static let userShortcutDividerLineHeight: CGFloat = 1
    static let userShortcutDividerVerticalPadding: CGFloat = 4
    static let utilityGapHeight: CGFloat = 68
    static let clipsRailBody = true

    static var userShortcutDividerHeight: CGFloat {
        userShortcutDividerLineHeight + userShortcutDividerVerticalPadding * 2
    }

    static func hitWidth(isOpen: Bool) -> CGFloat {
        isOpen ? expandedHitWidth : collapsedHitWidth
    }

    static func railOffset(isOpen: Bool) -> CGFloat {
        isOpen ? 0 : -expandedHitWidth
    }

    static func shouldOpen(isHovering: Bool, isDropTarget: Bool) -> Bool {
        shouldOpen(isRailHovering: isHovering, isTriggerHovering: false, isDropTarget: isDropTarget)
    }

    static func shouldOpen(isRailHovering: Bool, isTriggerHovering: Bool, isDropTarget: Bool) -> Bool {
        isRailHovering || isTriggerHovering || isDropTarget
    }

    static func triggerWidth(isDropTarget: Bool) -> CGFloat {
        isDropTarget ? expandedHitWidth : collapsedHitWidth
    }

    static func railContentHeight(defaultCount: Int, userCount: Int, utilityCount: Int) -> CGFloat {
        let buttonCount = defaultCount + userCount + utilityCount
        let dividerCount = userCount > 0 ? 1 : 0
        let utilityGapCount = 1
        let childCount = buttonCount + dividerCount + utilityGapCount
        let spacingHeight = CGFloat(max(childCount - 1, 0)) * railStackSpacing
        let dividerHeight = userCount > 0 ? userShortcutDividerHeight : 0

        return CGFloat(buttonCount) * railButtonSize
            + dividerHeight
            + utilityGapHeight
            + spacingHeight
            + railVerticalPadding * 2
    }

    static func collapsedStripHeight(defaultCount: Int, userCount: Int, utilityCount: Int) -> CGFloat {
        railContentHeight(defaultCount: defaultCount, userCount: userCount, utilityCount: utilityCount)
    }
}

enum RailShortcutDropTypes {
    static let accepted: [UTType] = [.fileURL, .xAlgoInternalFileDrag]
    static let pasteboardTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        NSPasteboard.PasteboardType(UTType.fileURL.identifier),
        NSPasteboard.PasteboardType(UTType.xAlgoInternalFileDrag.identifier)
    ]
}

struct RailPeekTriggerView: View {
    let width: CGFloat
    let height: CGFloat
    @Binding var isDropTarget: Bool
    let onHover: (Bool) -> Void
    let onDrop: ([URL]) -> Bool

    var body: some View {
        RailPeekEventBridge(
            isDropTarget: $isDropTarget,
            onHover: onHover,
            onDrop: onDrop
        )
        .frame(width: width)
        .frame(height: height)
        .contentShape(Rectangle())
    }
}

struct RailPeekEventBridge: NSViewRepresentable {
    @Binding var isDropTarget: Bool
    let onHover: (Bool) -> Void
    let onDrop: ([URL]) -> Bool

    func makeNSView(context: Context) -> RailPeekEventView {
        let view = RailPeekEventView()
        view.registerForDraggedTypes(RailShortcutDropTypes.pasteboardTypes)
        return view
    }

    func updateNSView(_ nsView: RailPeekEventView, context: Context) {
        nsView.onHover = onHover
        nsView.onDrop = onDrop
        nsView.onDropTargetChange = { targeted in
            if isDropTarget != targeted {
                isDropTarget = targeted
            }
        }
    }
}

final class RailPeekEventView: NSView {
    var onHover: ((Bool) -> Void)?
    var onDropTargetChange: ((Bool) -> Void)?
    var onDrop: (([URL]) -> Bool)?

    private var trackingAreaRef: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func updateTrackingAreas() {
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let next = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(next)
        trackingAreaRef = next
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseMoved(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseDown(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseDragged(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDropTargetChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDropTargetChange?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDropTargetChange?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onDropTargetChange?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = RailShortcutPasteboardReader.urls(from: sender.draggingPasteboard)
        let didDrop = onDrop?(urls) ?? false
        onDropTargetChange?(false)
        return didDrop
    }
}

enum RailShortcutPasteboardReader {
    static func urls(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []

        if let nsURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL] {
            urls.append(contentsOf: nsURLs.compactMap { $0 as URL })
        }

        if let fileURLString = pasteboard.string(forType: .fileURL),
           let url = URL(string: fileURLString),
           url.isFileURL {
            urls.append(url)
        }

        let internalType = NSPasteboard.PasteboardType(UTType.xAlgoInternalFileDrag.identifier)
        if let data = pasteboard.data(forType: internalType) {
            urls.append(contentsOf: Self.urls(fromInternalDragData: data))
        }

        return uniqueFileURLs(urls)
    }

    static func urls(fromInternalDragData data: Data) -> [URL] {
        guard let payload = try? JSONDecoder().decode(InternalFileDragPayload.self, from: data) else {
            return []
        }
        return payload.paths.map { URL(fileURLWithPath: $0) }
    }

    private static func uniqueFileURLs(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var unique: [URL] = []
        for url in urls where url.isFileURL {
            let standardized = url.standardizedFileURL
            if seen.insert(standardized.path).inserted {
                unique.append(standardized)
            }
        }
        return unique
    }
}

struct ExplorerShellView: View {
    @EnvironmentObject private var model: ExplorerModel

    var body: some View {
        VStack(spacing: 0) {
            CommandSurfaceView()

            HStack(spacing: 12) {
                FilePaneView(pane: model.mainPane, role: .main)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if model.assistOpen {
                    VStack(spacing: 12) {
                        FilePaneView(pane: model.assistTopPane, role: .assist)
                        FilePaneView(pane: model.assistBottomPane, role: .assist)
                    }
                    .frame(width: 420)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.leading, model.assistOpen ? 0 : 0)
            .padding(.trailing, 14)
            .padding(.bottom, 14)
            .animation(.smooth(duration: 0.22), value: model.assistOpen)
        }
    }
}

struct CommandSurfaceView: View {
    @EnvironmentObject private var model: ExplorerModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            CapsuleGroup {
                CommandIconButton(model.text(.tooltipGoUp), systemName: "chevron.up") {
                    model.goUp(model.mainPane)
                }
                .disabled(!model.mainPane.canGoUp)

                CommandIconButton(model.text(.tooltipBack), systemName: "chevron.left") {
                    model.goBack(model.mainPane)
                }
                .disabled(!model.mainPane.canGoBack)

                CommandIconButton(model.text(.tooltipForward), systemName: "chevron.right") {
                    model.goForward(model.mainPane)
                }
                .disabled(!model.mainPane.canGoForward)

                CommandIconButton(model.text(.tooltipRefresh), systemName: "arrow.clockwise") {
                    model.reload(model.mainPane)
                }
            }

            CapsuleGroup {
                CommandIconButton(model.text(.tooltipCreateFolder), systemName: "folder.badge.plus") {
                    model.createFolder()
                }
                .disabled(!model.focusedPane.isLocalDirectory)

                CommandIconButton(model.text(.tooltipCreateFile), systemName: "doc.badge.plus") {
                    model.createFile()
                }
                .disabled(!model.focusedPane.isLocalDirectory)

                CommandIconButton(model.text(.tooltipCut), systemName: "scissors") {
                    model.cutSelection()
                }
                .disabled(!model.hasSelection)

                CommandIconButton(model.text(.tooltipCopy), systemName: "doc.on.doc") {
                    model.copySelection()
                }
                .disabled(!model.hasSelection)

                CommandIconButton(model.text(.tooltipPaste), systemName: "doc.on.clipboard") {
                    model.pasteClipboard()
                }
                .disabled(!model.canPaste)
            }

            CapsuleGroup {
                SortMenuView(pane: model.mainPane)
                ViewModeMenuView(pane: model.mainPane)
            }

            MainPathView(path: model.mainPane.title) {
                model.copyPath(of: model.mainPane)
            }

            Spacer(minLength: 20)

            HStack(spacing: 4) {
                Button {
                    model.openSearch()
                    searchFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(IconHoverButtonStyle())
                .help(model.text(.tooltipSearch))

                if model.searchOpen {
                    TextField("搜索", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .frame(width: 220)
                        .onSubmit {
                            if model.searchText.isEmpty {
                                model.searchOpen = false
                            }
                        }
                        .onChange(of: searchFocused) { _, focused in
                            if !focused && model.searchText.isEmpty {
                                model.searchOpen = false
                            }
                        }
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 5)
            .capsuleSurface()

            Button {
                model.toggleAssist()
            } label: {
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(model.assistOpen ? Color.selectedCapsule : .clear)
                    )
            }
            .buttonStyle(IconHoverButtonStyle())
            .frame(width: 40, height: 40)
            .background(Circle().fill(.regularMaterial))
            .overlay(Circle().stroke(Color.controlBorder, lineWidth: 0.5))
            .help(model.text(.tooltipThreePane))
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .padding(.leading, 11)
        .padding(.trailing, 14)
    }
}

struct MainPathView: View {
    @EnvironmentObject private var model: ExplorerModel
    let path: String
    let copyAction: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text(path)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: 360, minHeight: 30, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .capsuleSurface()
        .help(model.text(.tooltipCopyPath))
        .onTapGesture(count: 2) {
            copyAction()
        }
    }
}

struct RailView: View {
    @EnvironmentObject private var model: ExplorerModel
    @State private var isDropTarget = false

    var body: some View {
        VStack(spacing: RailPeekLayout.railStackSpacing) {
            let defaultTargets = model.defaultSidebarTargets
            let userTargets = model.userSidebarTargets
            let utilityTargets = model.utilitySidebarTargets

            ForEach(defaultTargets) { target in
                RailButton(target: target)
            }

            if !userTargets.isEmpty {
                Capsule()
                    .fill(Color.controlBorder)
                    .frame(width: 22, height: RailPeekLayout.userShortcutDividerLineHeight)
                    .padding(.vertical, RailPeekLayout.userShortcutDividerVerticalPadding)

                ForEach(userTargets) { target in
                    RailButton(target: target)
                }
            }

            Color.clear
                .frame(height: RailPeekLayout.utilityGapHeight)

            ForEach(utilityTargets) { target in
                RailButton(target: target)
            }
        }
        .frame(width: RailPeekLayout.railIconColumnWidth)
        .padding(.vertical, RailPeekLayout.railVerticalPadding)
        .padding(.leading, RailPeekLayout.railLeadingPadding)
        .padding(.trailing, RailPeekLayout.railTrailingPadding)
        .frame(width: RailPeekLayout.railBodyWidth)
        .capsuleSurface(isHighlighted: isDropTarget)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onDrop(of: RailShortcutDropTypes.accepted, isTargeted: $isDropTarget) { providers in
            model.handleSidebarShortcutDrop(providers)
        }
        .contextMenu {
            DefaultSidebarVisibilityMenu()
        }
    }
}

struct RailButton: View {
    @EnvironmentObject private var model: ExplorerModel
    let target: SidebarTarget
    @State private var isDropTarget = false

    var body: some View {
        Button {
            model.openSidebarTarget(target)
        } label: {
            Image(systemName: target.symbolName)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.primary.opacity(0.76))
                .frame(width: RailPeekLayout.railButtonSize, height: RailPeekLayout.railButtonSize)
        }
        .buttonStyle(IconHoverButtonStyle())
        .help(target.title)
        .onDrop(of: RailShortcutDropTypes.accepted, isTargeted: $isDropTarget) { providers in
            model.handleSidebarShortcutDrop(providers)
        }
        .contextMenu {
            switch target.group {
            case .appDefault:
                DefaultSidebarVisibilityMenu()
            case .userShortcut:
                Button("移除快捷方式") {
                    model.removeSidebarShortcut(target)
                }
            case .mountedVolume:
                Button("推出") {
                    model.ejectVolume(target)
                }
            case .utility:
                EmptyView()
            }
        }
    }
}

struct DefaultSidebarVisibilityMenu: View {
    @EnvironmentObject private var model: ExplorerModel

    var body: some View {
        Section("固定图标") {
            ForEach(model.allDefaultSidebarTargets) { target in
                Toggle(isOn: Binding(
                    get: { model.isDefaultSidebarTargetVisible(target) },
                    set: { model.setDefaultSidebarTarget(target, visible: $0) }
                )) {
                    Label(target.title, systemImage: target.symbolName)
                }
            }
        }
    }
}

struct CapsuleGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 4) {
            content
        }
        .frame(height: 40)
        .padding(.horizontal, 5)
        .capsuleSurface()
    }
}

enum CapsuleSurfaceChrome {
    static let strokeWidth: CGFloat = 0.5
    static let shadowOpacity: Double = 0.05
    static let shadowRadius: CGFloat = 18
    static let shadowYOffset: CGFloat = 10
}

private extension View {
    @ViewBuilder
    func capsuleSurface(isHighlighted: Bool = false) -> some View {
        background {
            Capsule().fill(.regularMaterial)
            if isHighlighted {
                Capsule().fill(Color.selectedCapsule.opacity(0.42))
            }
        }
        .overlay(Capsule().stroke(Color.controlBorder, lineWidth: CapsuleSurfaceChrome.strokeWidth))
        .shadow(
            color: .black.opacity(CapsuleSurfaceChrome.shadowOpacity),
            radius: CapsuleSurfaceChrome.shadowRadius,
            y: CapsuleSurfaceChrome.shadowYOffset
        )
    }
}

struct CommandIconButton: View {
    let title: String
    let systemName: String
    let action: () -> Void

    init(_ title: String, systemName: String, action: @escaping () -> Void) {
        self.title = title
        self.systemName = systemName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(IconHoverButtonStyle())
        .help(title)
    }
}

struct SortMenuView: View {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState

    var body: some View {
        Menu {
            ForEach(SortField.allCases) { field in
                Button {
                    model.setSortField(field, pane: pane)
                } label: {
                    HStack {
                        Text(field.title)
                        if pane.sortField == field {
                            Text(pane.sortAscending ? "↑" : "↓")
                        }
                    }
                }
            }
        } label: {
            MenuIconLabel(systemName: "line.3.horizontal.decrease", width: pane.id.isAssist ? 38 : 54)
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .help(model.text(.tooltipSort))
    }
}

struct ViewModeMenuView: View {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState

    var body: some View {
        Menu {
            ForEach(pane.id == .main ? ExplorerViewMode.allCases : [.list, .files]) { mode in
                Button {
                    model.setViewMode(mode, pane: pane)
                } label: {
                    Label(mode.title, systemImage: mode.symbolName)
                }
            }
        } label: {
            MenuIconLabel(systemName: pane.viewMode.symbolName, width: pane.id.isAssist ? 38 : 54)
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .help(model.text(.tooltipView))
    }
}

struct IconHoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconHoverButtonBody(configuration: configuration)
    }
}

private struct IconHoverButtonBody: View {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    let configuration: ButtonStyle.Configuration

    var body: some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? .secondary : .primary)
            .background(
                Circle()
                    .fill(isEnabled && (configuration.isPressed || isHovering) ? Color.rowHover : .clear)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.74 : 1) : 0.34)
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct MenuIconLabel: View {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    let systemName: String
    let width: CGFloat

    var body: some View {
        HStack(spacing: width <= 38 ? 4 : 6) {
            Image(systemName: systemName)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .frame(width: width, height: 30)
        .foregroundStyle(isEnabled ? .primary : .secondary)
        .background(
            Capsule()
                .fill(isEnabled && isHovering ? Color.rowHover : .clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

struct FileInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let info: FileInfoSheet

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: FileSystemService.appIcon(for: info.entry))
                    .resizable()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.entry.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(info.entry.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Divider()

            LabeledContent("类型", value: info.entry.typeDescription)
            LabeledContent("大小", value: info.sizeText)
            LabeledContent("修改时间", value: info.modifiedText)
            LabeledContent("创建时间", value: info.createdText)

            HStack {
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 440)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: ExplorerModel

    var body: some View {
        Form {
            Toggle("隐藏左侧胶囊", isOn: Binding(
                get: { model.hideRail },
                set: { model.setHideRail($0) }
            ))

            Toggle("自动检查更新", isOn: Binding(
                get: { model.autoCheckUpdates },
                set: { model.setAutoCheckUpdates($0) }
            ))

            Picker("语言", selection: Binding(
                get: { model.language },
                set: { model.setLanguage($0) }
            )) {
                ForEach(AppText.supportedLanguages) { language in
                    Text(language.title).tag(language.id)
                }
            }

            Section("快捷键") {
                Text("复制、剪切、粘贴、全选、搜索、设置保留 macOS 系统习惯；F2、F5、Option + 方向键按文件管理器习惯处理。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)

            Text(AppMetadata.name)
                .font(.system(size: 22, weight: .semibold))

            Text("Version \(AppMetadata.version)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(AppMetadata.copyright)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button("关闭") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.top, 6)
        }
        .padding(28)
        .frame(width: 360)
    }
}

struct WindowConfigurator: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onKeyDown: onKeyDown)
    }

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughNSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindow(view.window)
            context.coordinator.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            configureWindow(nsView.window)
            context.coordinator.window = nsView.window
        }
    }

    private func configureWindow(_ window: NSWindow?) {
        guard let window else { return }
        window.title = "xAlgo Explorer"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.styleMask.remove(.fullSizeContentView)
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.hasShadow = true
        window.minSize = NSSize(width: 960, height: 640)
    }

    final class Coordinator {
        weak var window: NSWindow?
        var onKeyDown: (NSEvent) -> Bool
        private var monitor: Any?

        init(onKeyDown: @escaping (NSEvent) -> Bool) {
            self.onKeyDown = onKeyDown
            self.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard event.window == self.window else { return event }
                return self.onKeyDown(event) ? nil : event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    final class PassthroughNSView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

extension Color {
    static var controlBorder: Color {
        Color(nsColor: .separatorColor).opacity(0.42)
    }

    static var rowHover: Color {
        Color(nsColor: .labelColor).opacity(0.09)
    }

    static var selectedCapsule: Color {
        Color(nsColor: .selectedContentBackgroundColor).opacity(0.18)
    }

    static var previewLabelBackground: Color {
        Color(nsColor: .textBackgroundColor).opacity(0.82)
    }
}
