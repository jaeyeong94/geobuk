import SwiftUI

@main
struct GeobukApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Workspace") {
                    NotificationCenter.default.post(name: .newWorkspace, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Split Horizontally") {
                    NotificationCenter.default.post(name: .splitHorizontally, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Split Vertically") {
                    NotificationCenter.default.post(name: .splitVertically, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Close Pane") {
                    NotificationCenter.default.post(name: .closePane, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Close Workspace") {
                    NotificationCenter.default.post(name: .closeWorkspace, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command, .option])
            }

            CommandGroup(after: .windowArrangement) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Toggle Maximize") {
                    NotificationCenter.default.post(name: .toggleMaximize, object: nil)
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])

                Divider()

                Button("Focus Left Pane") {
                    NotificationCenter.default.post(name: .focusPaneDirection, object: NavigationDirection.left)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

                Button("Focus Right Pane") {
                    NotificationCenter.default.post(name: .focusPaneDirection, object: NavigationDirection.right)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])

                Button("Focus Pane Above") {
                    NotificationCenter.default.post(name: .focusPaneDirection, object: NavigationDirection.up)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])

                Button("Focus Pane Below") {
                    NotificationCenter.default.post(name: .focusPaneDirection, object: NavigationDirection.down)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])

                Divider()

                // Cmd+1~9: Switch workspace by number
                ForEach(1...9, id: \.self) { number in
                    Button("Workspace \(number)") {
                        NotificationCenter.default.post(name: .switchWorkspaceByNumber, object: number)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
                }
            }
        }
    }
}

extension Notification.Name {
    static let newTerminalTab = Notification.Name("newTerminalTab")
    static let splitHorizontally = Notification.Name("splitHorizontally")
    static let splitVertically = Notification.Name("splitVertically")
    static let toggleMaximize = Notification.Name("toggleMaximize")
    static let focusPaneDirection = Notification.Name("focusPaneDirection")
    static let closePane = Notification.Name("closePane")
    static let newWorkspace = Notification.Name("newWorkspace")
    static let closeWorkspace = Notification.Name("closeWorkspace")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let switchWorkspaceByNumber = Notification.Name("switchWorkspaceByNumber")
}
