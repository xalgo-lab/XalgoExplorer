import SwiftUI

@main
@MainActor
struct XAlgoExplorerApp: App {
    @StateObject private var model = ExplorerModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.thumbnails)
                .frame(minWidth: 960, minHeight: 640)
        }
        .commands {
            ExplorerCommands(model: model)
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 430)
        }
    }
}

struct ExplorerCommands: Commands {
    @ObservedObject var model: ExplorerModel

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于 \(AppMetadata.name)") {
                model.showAbout()
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("新建文件夹") {
                model.createFolder()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("新建文件") {
                model.createFile()
            }
            .keyboardShortcut("n", modifiers: [.control, .shift])
        }

        CommandGroup(replacing: .pasteboard) {
            Button("剪切") {
                model.cutSelection()
            }
            .keyboardShortcut("x", modifiers: .command)
            .disabled(!model.hasSelection)

            Button("复制") {
                model.copySelection()
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(!model.hasSelection)

            Button("粘贴") {
                model.pasteClipboard()
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(!model.canPaste)
        }

        CommandMenu("文件") {
            Button("打开") {
                model.openSelection()
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(!model.hasSelection)

            Button("重命名") {
                model.beginRenameSelection()
            }
            .disabled(!model.canRenameSelection)

            Divider()

            Button("移到废纸篓") {
                model.trashSelection()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(!model.hasSelection)
        }

        CommandMenu("查看") {
            Picker("查看方式", selection: Binding(
                get: { model.focusedPane.viewMode },
                set: { model.setViewMode($0) }
            )) {
                ForEach(model.availableViewModesForFocusedPane) { mode in
                    Label(mode.title, systemImage: mode.symbolName).tag(mode)
                }
            }

            Picker("排序方式", selection: Binding(
                get: { model.focusedPane.sortField },
                set: { model.setSortField($0) }
            )) {
                ForEach(SortField.allCases) { field in
                    Text(field.title).tag(field)
                }
            }

            Button(model.focusedPane.sortAscending ? "降序" : "升序") {
                model.toggleSortDirection()
            }
        }

        CommandGroup(after: .toolbar) {
            Button("搜索") {
                model.openSearch()
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("刷新") {
                model.refreshFocusedPane()
            }
        }
    }
}
