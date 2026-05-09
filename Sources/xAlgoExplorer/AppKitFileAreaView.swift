import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppKitTablePaneView: NSViewControllerRepresentable {
    @EnvironmentObject private var model: ExplorerModel
    @ObservedObject var pane: PaneState
    let role: FilePaneRole

    func makeNSViewController(context: Context) -> AppKitFileTableController {
        AppKitFileTableController()
    }

    func updateNSViewController(_ controller: AppKitFileTableController, context: Context) {
        controller.configure(model: model, pane: pane, role: role)
    }
}

struct AppKitCollectionPaneView: NSViewControllerRepresentable {
    @EnvironmentObject private var model: ExplorerModel
    @EnvironmentObject private var thumbnails: ThumbnailCache
    @ObservedObject var pane: PaneState
    let role: FilePaneRole
    let previewStyle: Bool

    func makeNSViewController(context: Context) -> AppKitFileCollectionController {
        AppKitFileCollectionController()
    }

    func updateNSViewController(_ controller: AppKitFileCollectionController, context: Context) {
        controller.configure(model: model, thumbnails: thumbnails, pane: pane, role: role, previewStyle: previewStyle)
    }
}

private enum AppKitFilePasteboard {
    static let acceptedTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        NSPasteboard.PasteboardType(UTType.fileURL.identifier),
        NSPasteboard.PasteboardType(UTType.xAlgoInternalFileDrag.identifier)
    ]
}

private extension FileDropOperation {
    var nsDragOperation: NSDragOperation {
        switch self {
        case .copy:
            return .copy
        case .move:
            return .move
        }
    }
}

enum AppKitSelectionScrollTarget {
    static func tableRow(entries: [FileEntry], selectedIDs: Set<FileEntry.ID>, cursorID: FileEntry.ID?) -> Int? {
        if let cursorID,
           let cursorRow = entries.firstIndex(where: { $0.id == cursorID }) {
            return cursorRow
        }
        return entries.firstIndex { selectedIDs.contains($0.id) }
    }

    static func collectionIndexPath(entries: [FileEntry], selectedIDs: Set<FileEntry.ID>, cursorID: FileEntry.ID?) -> IndexPath? {
        guard let item = tableRow(entries: entries, selectedIDs: selectedIDs, cursorID: cursorID) else {
            return nil
        }
        return IndexPath(item: item, section: 0)
    }
}

@MainActor
final class AppKitFileTableController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let scrollView = NSScrollView()
    private let tableView = AppKitFileTableView()
    private var model: ExplorerModel?
    private var pane: PaneState?
    private var role: FilePaneRole = .main
    private var entries: [FileEntry] = []
    private var isApplyingSelection = false
    private var editingEntryID: FileEntry.ID?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        tableView.owner = self
        tableView.headerView = NSTableHeaderView()
        tableView.backgroundColor = .clear
        tableView.enclosingScrollView?.drawsBackground = false
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .regular
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(openSelectedEntry)
        tableView.target = self
        tableView.registerForDraggedTypes(AppKitFilePasteboard.acceptedTypes)
        configureColumns()

        scrollView.documentView = tableView
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func configure(model: ExplorerModel, pane: PaneState, role: FilePaneRole) {
        self.model = model
        self.pane = pane
        self.role = role
        let nextEntries = model.displayedEntries(for: pane)
        let needsReload = entries.map(\.id) != nextEntries.map(\.id)
            || entries.map(\.name) != nextEntries.map(\.name)
            || entries.map(\.typeDescription) != nextEntries.map(\.typeDescription)
            || entries.map(\.size) != nextEntries.map(\.size)
            || entries.map(\.modified) != nextEntries.map(\.modified)
        entries = nextEntries
        tableView.rowHeight = role == .main ? 34 : 28
        syncColumns()
        if needsReload {
            tableView.reloadData()
        } else {
            tableView.reloadData(forRowIndexes: IndexSet(integersIn: 0..<entries.count), columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        }
        applySelectionFromModel()
        startRenameIfNeeded()
        model.updateKeyboardColumnCount(1, in: pane)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard entries.indices.contains(row),
              let column = FileColumn(rawValue: tableColumn?.identifier.rawValue ?? "") else {
            return nil
        }

        let entry = entries[row]
        switch column {
        case .name:
            let identifier = NSUserInterfaceItemIdentifier("name-cell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? AppKitFileNameTableCellView
                ?? AppKitFileNameTableCellView(identifier: identifier)
            cell.configure(entry: entry, pane: pane, role: role, delegate: self)
            return cell
        case .modified, .type, .size:
            let identifier = NSUserInterfaceItemIdentifier("meta-\(column.rawValue)-cell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? AppKitFileTextTableCellView
                ?? AppKitFileTextTableCellView(identifier: identifier)
            cell.configure(text: text(for: column, entry: entry), alignment: column == .size ? .right : .left)
            return cell
        }
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        guard let model, let pane,
              let field = sortField(for: tableColumn.identifier) else { return }
        model.setSortField(field, pane: pane)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingSelection,
              let model,
              let pane else { return }
        let selectedIDs = tableView.selectedRowIndexes
            .compactMap { entries.indices.contains($0) ? entries[$0].id : nil }
        pane.selectedIDs = Set(selectedIDs)
        pane.selectionAnchorID = selectedIDs.first
        pane.selectionCursorID = selectedIDs.last
        model.setFocus(pane.id)
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let model, let pane, entries.indices.contains(row) else { return nil }
        return model.dragPasteboardItem(for: entries[row], in: pane)
    }

    func tableView(
        _ tableView: NSTableView,
        validateDrop info: NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        let effectiveDropOperation: NSTableView.DropOperation
        if row >= 0,
           entries.indices.contains(row),
           entries[row].isDirectory,
           !entries[row].isPackage {
            tableView.setDropRow(row, dropOperation: .on)
            effectiveDropOperation = .on
        } else {
            effectiveDropOperation = dropOperation
        }
        guard let model,
              let targetDirectory = targetDirectory(forRow: row, dropOperation: effectiveDropOperation) else {
            return []
        }
        let intent = FileDropIntent(modifierFlags: NSEvent.modifierFlags)
        return model.dropOperation(from: info.draggingPasteboard, into: targetDirectory, intent: intent)?.nsDragOperation ?? []
    }

    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        let effectiveDropOperation: NSTableView.DropOperation
        if row >= 0,
           entries.indices.contains(row),
           entries[row].isDirectory,
           !entries[row].isPackage {
            effectiveDropOperation = .on
        } else {
            effectiveDropOperation = dropOperation
        }
        guard let model,
              let pane,
              let targetDirectory = targetDirectory(forRow: row, dropOperation: effectiveDropOperation) else {
            return false
        }
        model.setFocus(pane.id)
        return model.handleDrop(
            from: info.draggingPasteboard,
            into: targetDirectory,
            intent: FileDropIntent(modifierFlags: NSEvent.modifierFlags)
        )
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        guard let model, let pane,
              let column = notification.userInfo?["NSTableColumn"] as? NSTableColumn,
              let fileColumn = FileColumn(rawValue: column.identifier.rawValue) else {
            return
        }
        model.setColumnWidth(column.width, for: fileColumn, in: pane)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        AppKitFileTableRowView()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? AppKitRenameTextField,
              let pane,
              field.entryID == pane.renamingID else { return }
        pane.renameDraft = field.stringValue
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? AppKitRenameTextField,
              let model,
              let pane,
              field.entryID == pane.renamingID else { return }
        let movement = notification.userInfo?["NSTextMovement"] as? Int
        pane.renameDraft = field.stringValue
        editingEntryID = nil
        if movement == NSTextMovement.cancel.rawValue {
            model.cancelRename(in: pane)
        } else {
            model.commitRename(in: pane)
        }
    }

    func blankClick() {
        guard let model, let pane else { return }
        model.clearSelection(pane)
    }

    func entryMenu(for row: Int) -> NSMenu? {
        guard let model, let pane, entries.indices.contains(row) else { return blankMenu() }
        if !tableView.selectedRowIndexes.contains(row) {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))
        }
        return AppKitFileContextMenu.makeFileMenu(entry: entries[row], pane: pane, model: model)
    }

    func blankMenu() -> NSMenu? {
        guard let model, let pane else { return nil }
        return AppKitFileContextMenu.makeBlankMenu(pane: pane, model: model)
    }

    @objc private func openSelectedEntry() {
        guard let model,
              let pane,
              tableView.clickedRow >= 0,
              entries.indices.contains(tableView.clickedRow) else { return }
        model.doubleClick(entries[tableView.clickedRow], in: pane)
    }

    private func configureColumns() {
        for column in FileColumn.allCases {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
            tableColumn.title = title(for: column)
            tableColumn.minWidth = column.minWidth
            tableColumn.resizingMask = .userResizingMask
            tableView.addTableColumn(tableColumn)
        }
    }

    private func syncColumns() {
        guard let pane else { return }
        for tableColumn in tableView.tableColumns {
            guard let column = FileColumn(rawValue: tableColumn.identifier.rawValue) else { continue }
            let width = pane.width(for: column)
            if abs(tableColumn.width - width) > 0.5 {
                tableColumn.width = width
            }
            tableColumn.headerCell.stringValue = headerTitle(for: column, pane: pane)
        }
    }

    private func applySelectionFromModel() {
        guard let pane else { return }
        let selectedRows = entries.enumerated().compactMap { index, entry in
            pane.selectedIDs.contains(entry.id) ? index : nil
        }
        let nextSelection = IndexSet(selectedRows)
        if tableView.selectedRowIndexes != nextSelection {
            isApplyingSelection = true
            tableView.selectRowIndexes(nextSelection, byExtendingSelection: false)
            isApplyingSelection = false
        }
        if let row = AppKitSelectionScrollTarget.tableRow(
            entries: entries,
            selectedIDs: pane.selectedIDs,
            cursorID: pane.selectionCursorID
        ) {
            tableView.scrollRowToVisible(row)
        }
    }

    private func startRenameIfNeeded() {
        guard let pane,
              let renamingID = pane.renamingID,
              renamingID != editingEntryID,
              let row = entries.firstIndex(where: { $0.id == renamingID }) else {
            return
        }
        editingEntryID = renamingID
        tableView.scrollRowToVisible(row)
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let view = self.tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? AppKitFileNameTableCellView else {
                return
            }
            view.beginEditing()
        }
    }

    private func targetDirectory(forRow row: Int, dropOperation: NSTableView.DropOperation) -> URL? {
        guard let pane else { return nil }
        if row >= 0,
           entries.indices.contains(row),
           dropOperation == .on,
           entries[row].isDirectory,
           !entries[row].isPackage {
            return entries[row].url
        }
        return pane.isLocalDirectory ? pane.url : nil
    }

    private func title(for column: FileColumn) -> String {
        switch column {
        case .name: return "文件名"
        case .modified: return "修改日期"
        case .type: return "类型"
        case .size: return "大小"
        }
    }

    private func headerTitle(for column: FileColumn, pane: PaneState) -> String {
        let title = title(for: column)
        let field: SortField
        switch column {
        case .name: field = .name
        case .modified: field = .modified
        case .type: field = .type
        case .size: field = .size
        }
        guard pane.sortField == field else { return title }
        return "\(title) \(pane.sortAscending ? "↑" : "↓")"
    }

    private func sortField(for identifier: NSUserInterfaceItemIdentifier) -> SortField? {
        switch FileColumn(rawValue: identifier.rawValue) {
        case .name: return .name
        case .modified: return .modified
        case .type: return .type
        case .size: return .size
        case .none: return nil
        }
    }

    private func text(for column: FileColumn, entry: FileEntry) -> String {
        switch column {
        case .name:
            return entry.name
        case .modified:
            return FileSystemService.formattedDate(entry.modified)
        case .type:
            return entry.typeDescription
        case .size:
            return FileSystemService.formattedSize(entry)
        }
    }
}

@MainActor
final class AppKitFileCollectionController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout, NSTextFieldDelegate {
    private let scrollView = NSScrollView()
    private let collectionView = AppKitFileCollectionView()
    private let layout = NSCollectionViewFlowLayout()
    private var model: ExplorerModel?
    private var thumbnails: ThumbnailCache?
    private var pane: PaneState?
    private var role: FilePaneRole = .main
    private var previewStyle = false
    private var entries: [FileEntry] = []
    private var isApplyingSelection = false
    private var editingEntryID: FileEntry.ID?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 8
        layout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 18, right: 8)

        collectionView.owner = self
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(AppKitFileCollectionItem.self, forItemWithIdentifier: AppKitFileCollectionItem.reuseIdentifier)
        collectionView.registerForDraggedTypes(AppKitFilePasteboard.acceptedTypes)

        scrollView.documentView = collectionView
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func configure(model: ExplorerModel, thumbnails: ThumbnailCache, pane: PaneState, role: FilePaneRole, previewStyle: Bool) {
        let oldPreviewStyle = self.previewStyle
        self.model = model
        self.thumbnails = thumbnails
        self.pane = pane
        self.role = role
        self.previewStyle = previewStyle
        let nextEntries = model.displayedEntries(for: pane)
        let needsReload = entries.map(\.id) != nextEntries.map(\.id)
            || entries.map(\.name) != nextEntries.map(\.name)
            || previewStyle != oldPreviewStyle
        entries = nextEntries
        updateLayout()
        if needsReload {
            collectionView.reloadData()
        } else {
            collectionView.reloadItems(at: Set(entries.indices.map { IndexPath(item: $0, section: 0) }))
        }
        applySelectionFromModel()
        startRenameIfNeeded()
        updateKeyboardColumnCount()
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        entries.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: AppKitFileCollectionItem.reuseIdentifier, for: indexPath)
        guard let fileItem = item as? AppKitFileCollectionItem,
              entries.indices.contains(indexPath.item) else {
            return item
        }
        fileItem.configure(
            entry: entries[indexPath.item],
            pane: pane,
            role: role,
            previewStyle: previewStyle,
            thumbnails: thumbnails,
            delegate: self
        )
        return fileItem
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        syncSelectionToModel()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        syncSelectionToModel()
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        layout collectionViewLayout: NSCollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> NSSize {
        if previewStyle {
            return NSSize(width: 156, height: 132)
        }
        return role == .main ? NSSize(width: 112, height: 96) : NSSize(width: 78, height: 78)
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        pasteboardWriterForItemAt indexPath: IndexPath
    ) -> NSPasteboardWriting? {
        guard let model, let pane, entries.indices.contains(indexPath.item) else { return nil }
        return model.dragPasteboardItem(for: entries[indexPath.item], in: pane)
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        validateDrop draggingInfo: NSDraggingInfo,
        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation {
        let index = proposedDropIndexPath.pointee.item
        if entries.indices.contains(index),
           entries[index].isDirectory,
           !entries[index].isPackage {
            proposedDropOperation.pointee = .on
        }

        guard let model,
              let targetDirectory = targetDirectory(for: proposedDropIndexPath.pointee as IndexPath, dropOperation: proposedDropOperation.pointee) else {
            return []
        }
        let intent = FileDropIntent(modifierFlags: NSEvent.modifierFlags)
        return model.dropOperation(from: draggingInfo.draggingPasteboard, into: targetDirectory, intent: intent)?.nsDragOperation ?? []
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        acceptDrop draggingInfo: NSDraggingInfo,
        indexPath: IndexPath,
        dropOperation: NSCollectionView.DropOperation
    ) -> Bool {
        guard let model,
              let pane,
              let targetDirectory = targetDirectory(for: indexPath, dropOperation: dropOperation) else {
            return false
        }
        model.setFocus(pane.id)
        return model.handleDrop(
            from: draggingInfo.draggingPasteboard,
            into: targetDirectory,
            intent: FileDropIntent(modifierFlags: NSEvent.modifierFlags)
        )
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? AppKitRenameTextField,
              let pane,
              field.entryID == pane.renamingID else { return }
        pane.renameDraft = field.stringValue
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? AppKitRenameTextField,
              let model,
              let pane,
              field.entryID == pane.renamingID else { return }
        let movement = notification.userInfo?["NSTextMovement"] as? Int
        pane.renameDraft = field.stringValue
        editingEntryID = nil
        if movement == NSTextMovement.cancel.rawValue {
            model.cancelRename(in: pane)
        } else {
            model.commitRename(in: pane)
        }
    }

    func blankClick() {
        guard let model, let pane else { return }
        model.clearSelection(pane)
    }

    func openEntry(at indexPath: IndexPath) {
        guard let model, let pane, entries.indices.contains(indexPath.item) else { return }
        model.doubleClick(entries[indexPath.item], in: pane)
    }

    func menu(for indexPath: IndexPath?) -> NSMenu? {
        guard let model, let pane else { return nil }
        guard let indexPath,
              entries.indices.contains(indexPath.item) else {
            return AppKitFileContextMenu.makeBlankMenu(pane: pane, model: model)
        }
        if !collectionView.selectionIndexPaths.contains(indexPath) {
            collectionView.selectionIndexPaths = [indexPath]
            syncSelectionToModel()
        }
        return AppKitFileContextMenu.makeFileMenu(entry: entries[indexPath.item], pane: pane, model: model)
    }

    private func syncSelectionToModel() {
        guard !isApplyingSelection,
              let model,
              let pane else { return }
        let selectedIDs = collectionView.selectionIndexPaths
            .sorted()
            .compactMap { entries.indices.contains($0.item) ? entries[$0.item].id : nil }
        pane.selectedIDs = Set(selectedIDs)
        pane.selectionAnchorID = selectedIDs.first
        pane.selectionCursorID = selectedIDs.last
        model.setFocus(pane.id)
    }

    private func applySelectionFromModel() {
        guard let pane else { return }
        let indexPaths = Set(entries.enumerated().compactMap { index, entry in
            pane.selectedIDs.contains(entry.id) ? IndexPath(item: index, section: 0) : nil
        })
        if collectionView.selectionIndexPaths != indexPaths {
            isApplyingSelection = true
            collectionView.selectionIndexPaths = indexPaths
            isApplyingSelection = false
        }
        if let indexPath = AppKitSelectionScrollTarget.collectionIndexPath(
            entries: entries,
            selectedIDs: pane.selectedIDs,
            cursorID: pane.selectionCursorID
        ) {
            collectionView.scrollToItems(at: [indexPath], scrollPosition: .nearestVerticalEdge)
        }
    }

    private func startRenameIfNeeded() {
        guard let pane,
              let renamingID = pane.renamingID,
              renamingID != editingEntryID,
              let index = entries.firstIndex(where: { $0.id == renamingID }) else {
            return
        }
        editingEntryID = renamingID
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItems(at: [indexPath], scrollPosition: .nearestVerticalEdge)
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let item = self.collectionView.item(at: indexPath) as? AppKitFileCollectionItem else {
                return
            }
            item.beginEditing()
        }
    }

    private func updateLayout() {
        layout.itemSize = previewStyle
            ? NSSize(width: 156, height: 132)
            : (role == .main ? NSSize(width: 112, height: 96) : NSSize(width: 78, height: 78))
        layout.minimumInteritemSpacing = previewStyle ? 16 : (role == .main ? 4 : 2)
        layout.minimumLineSpacing = previewStyle ? 18 : (role == .main ? 8 : 4)
        layout.sectionInset = previewStyle
            ? NSEdgeInsets(top: 12, left: 14, bottom: 30, right: 14)
            : NSEdgeInsets(top: role == .main ? 8 : 6, left: role == .main ? 8 : 6, bottom: 18, right: role == .main ? 8 : 6)
        layout.invalidateLayout()
    }

    private func updateKeyboardColumnCount() {
        guard let model, let pane else { return }
        let width = collectionView.enclosingScrollView?.contentSize.width ?? collectionView.bounds.width
        let itemWidth = layout.itemSize.width
        let spacing = layout.minimumInteritemSpacing
        let usable = max(0, width - layout.sectionInset.left - layout.sectionInset.right)
        let count = max(1, Int((usable + spacing) / (itemWidth + spacing)))
        model.updateKeyboardColumnCount(count, in: pane)
    }

    private func targetDirectory(for indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> URL? {
        guard let pane else { return nil }
        if dropOperation == .on,
           entries.indices.contains(indexPath.item),
           entries[indexPath.item].isDirectory,
           !entries[indexPath.item].isPackage {
            return entries[indexPath.item].url
        }
        return pane.isLocalDirectory ? pane.url : nil
    }
}

private final class AppKitFileTableView: NSTableView {
    weak var owner: AppKitFileTableController?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if row(at: point) == -1 {
            owner?.blankClick()
        }
        super.mouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        return row >= 0 ? owner?.entryMenu(for: row) : owner?.blankMenu()
    }
}

private final class AppKitFileCollectionView: NSCollectionView {
    weak var owner: AppKitFileCollectionController?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let indexPath = indexPathForItem(at: point)
        if indexPath == nil {
            owner?.blankClick()
        }
        super.mouseDown(with: event)
        if event.clickCount >= 2, let indexPath {
            owner?.openEntry(at: indexPath)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        return owner?.menu(for: indexPathForItem(at: point))
    }
}

private final class AppKitFileTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        let rect = bounds.insetBy(dx: 6, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        NSColor.selectedContentBackgroundColor.withAlphaComponent(0.78).setFill()
        path.fill()
    }
}

private final class AppKitFileNameTableCellView: NSTableCellView {
    private let iconView = NSImageView()
    let nameField = AppKitRenameTextField()

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(entry: FileEntry, pane: PaneState?, role: FilePaneRole, delegate: NSTextFieldDelegate) {
        iconView.image = FileSystemService.appIcon(for: entry)
        nameField.entryID = entry.id
        nameField.stringValue = pane?.renamingID == entry.id ? (pane?.renameDraft ?? entry.name) : entry.name
        nameField.delegate = delegate
        nameField.isEditable = pane?.renamingID == entry.id
        nameField.isSelectable = pane?.renamingID == entry.id
        nameField.font = .systemFont(ofSize: role == .main ? 13 : 12, weight: .regular)
        iconView.setFrameSize(NSSize(width: role == .main ? 22 : 18, height: role == .main ? 22 : 18))
        toolTip = entry.url.path
    }

    func beginEditing() {
        nameField.isEditable = true
        nameField.isSelectable = true
        window?.makeFirstResponder(nameField)
        nameField.selectText(nil)
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.lineBreakMode = .byTruncatingTail
        nameField.usesSingleLineMode = true
        nameField.focusRingType = .none

        addSubview(iconView)
        addSubview(nameField)
        textField = nameField
        imageView = iconView

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            nameField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class AppKitFileTextTableCellView: NSTableCellView {
    private let valueField = NSTextField(labelWithString: "")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(text: String, alignment: NSTextAlignment) {
        valueField.stringValue = text
        valueField.alignment = alignment
    }

    private func setup() {
        valueField.translatesAutoresizingMaskIntoConstraints = false
        valueField.font = .systemFont(ofSize: 12)
        valueField.textColor = .secondaryLabelColor
        valueField.lineBreakMode = .byTruncatingTail
        addSubview(valueField)
        textField = valueField
        NSLayoutConstraint.activate([
            valueField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            valueField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            valueField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class AppKitFileCollectionItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("file-collection-item")

    private let container = NSView()
    private let iconImageView = NSImageView()
    private let nameField = AppKitRenameTextField()
    private var entryID: FileEntry.ID?

    override func loadView() {
        view = container
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.backgroundColor = NSColor.clear.cgColor

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.alignment = .center
        nameField.lineBreakMode = .byTruncatingTail
        nameField.maximumNumberOfLines = 2
        nameField.focusRingType = .none

        container.addSubview(iconImageView)
        container.addSubview(nameField)

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            iconImageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            nameField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            nameField.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 6),
            nameField.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -6)
        ])
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionBackground()
        }
    }

    func configure(
        entry: FileEntry,
        pane: PaneState?,
        role: FilePaneRole,
        previewStyle: Bool,
        thumbnails: ThumbnailCache?,
        delegate: NSTextFieldDelegate
    ) {
        entryID = entry.id
        nameField.entryID = entry.id
        nameField.stringValue = pane?.renamingID == entry.id ? (pane?.renameDraft ?? entry.name) : entry.name
        nameField.delegate = delegate
        nameField.isEditable = pane?.renamingID == entry.id
        nameField.isSelectable = pane?.renamingID == entry.id
        nameField.font = .systemFont(ofSize: previewStyle ? 12 : (role == .main ? 13 : 11))
        container.toolTip = entry.url.path

        if previewStyle {
            thumbnails?.request(url: entry.url, size: CGSize(width: 280, height: 224))
            iconImageView.image = thumbnails?.image(for: entry.url) ?? FileSystemService.appIcon(for: entry)
        } else {
            iconImageView.image = FileSystemService.appIcon(for: entry)
        }

        let imageSize: CGFloat = previewStyle ? 82 : (role == .main ? 44 : 32)
        iconImageView.constraints
            .filter { $0.firstAttribute == .width || $0.firstAttribute == .height }
            .forEach { iconImageView.removeConstraint($0) }
        iconImageView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
        iconImageView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
        updateSelectionBackground()
    }

    func beginEditing() {
        nameField.isEditable = true
        nameField.isSelectable = true
        view.window?.makeFirstResponder(nameField)
        nameField.selectText(nil)
    }

    private func updateSelectionBackground() {
        container.layer?.backgroundColor = isSelected
            ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.72).cgColor
            : NSColor.clear.cgColor
    }
}

private final class AppKitRenameTextField: NSTextField {
    var entryID: FileEntry.ID?
}

@MainActor
private enum AppKitFileContextMenu {
    static func makeFileMenu(entry: FileEntry, pane: PaneState, model: ExplorerModel) -> NSMenu {
        let menu = AppKitActionMenu()
        let target = AppKitMenuActionTarget(model: model, pane: pane, entry: entry)
        menu.actionTarget = target
        menu.addItem(item(FileContextMenuLayout.chooseApplicationOpenTitle, action: #selector(AppKitMenuActionTarget.chooseApplication), target: target))
        menu.addItem(item(FileContextMenuLayout.copyURLTitle, action: #selector(AppKitMenuActionTarget.copyURL), target: target))
        menu.addItem(.separator())
        menu.addItem(item("剪切", action: #selector(AppKitMenuActionTarget.cut), target: target))
        menu.addItem(item("复制", action: #selector(AppKitMenuActionTarget.copyItem), target: target))
        let paste = item("粘贴", action: #selector(AppKitMenuActionTarget.paste), target: target)
        paste.isEnabled = model.canPaste(in: pane)
        menu.addItem(paste)
        menu.addItem(.separator())
        menu.addItem(item("删除", action: #selector(AppKitMenuActionTarget.trash), target: target))
        menu.addItem(item("重命名", action: #selector(AppKitMenuActionTarget.rename), target: target))
        menu.addItem(item("属性", action: #selector(AppKitMenuActionTarget.info), target: target))
        return menu
    }

    static func makeBlankMenu(pane: PaneState, model: ExplorerModel) -> NSMenu {
        let menu = AppKitActionMenu()
        let target = AppKitMenuActionTarget(model: model, pane: pane, entry: nil)
        menu.actionTarget = target
        let paste = item("粘贴", action: #selector(AppKitMenuActionTarget.paste), target: target)
        paste.isEnabled = model.canPaste(in: pane)
        menu.addItem(paste)
        return menu
    }

    private static func item(_ title: String, action: Selector, target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        return item
    }
}

@MainActor
private final class AppKitActionMenu: NSMenu {
    var actionTarget: AppKitMenuActionTarget?
}

@MainActor
private final class AppKitMenuActionTarget: NSObject {
    private weak var model: ExplorerModel?
    private weak var pane: PaneState?
    private let entry: FileEntry?

    init(model: ExplorerModel, pane: PaneState, entry: FileEntry?) {
        self.model = model
        self.pane = pane
        self.entry = entry
    }

    @objc func chooseApplication() {
        guard let model, let pane, let entry else { return }
        model.chooseApplicationAndOpen(entry, in: pane)
    }

    @objc func copyURL() {
        guard let model, let entry else { return }
        model.copyURL(of: entry)
    }

    @objc func cut() {
        guard let model, let pane, let entry else { return }
        model.select(entry, in: pane)
        model.cutSelection(in: pane)
    }

    @objc func copyItem() {
        guard let model, let pane, let entry else { return }
        model.select(entry, in: pane)
        model.copySelection(in: pane)
    }

    @objc func paste() {
        guard let model, let pane else { return }
        let destination = entry.flatMap { $0.isDirectory && !$0.isPackage ? $0.url : nil } ?? pane.url
        model.setFocus(pane.id)
        model.pasteClipboard(in: pane, to: destination)
    }

    @objc func trash() {
        guard let model, let pane, let entry else { return }
        model.select(entry, in: pane)
        model.trashSelection()
    }

    @objc func rename() {
        guard let model, let pane, let entry else { return }
        model.beginRename(entry, in: pane)
    }

    @objc func info() {
        guard let model, let entry else { return }
        model.showInfo(for: entry)
    }
}
