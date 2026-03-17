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
                Button("New Terminal Tab") {
                    NotificationCenter.default.post(name: .newTerminalTab, object: nil)
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
            }

            CommandGroup(after: .windowArrangement) {
                Button("Toggle Maximize") {
                    NotificationCenter.default.post(name: .toggleMaximize, object: nil)
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])

                Divider()

                Button("Focus Previous Pane") {
                    NotificationCenter.default.post(name: .focusPreviousPane, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

                Button("Focus Next Pane") {
                    NotificationCenter.default.post(name: .focusNextPane, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])

                Button("Focus Pane Above") {
                    NotificationCenter.default.post(name: .focusPreviousPane, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])

                Button("Focus Pane Below") {
                    NotificationCenter.default.post(name: .focusNextPane, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            }
        }
    }
}

extension Notification.Name {
    static let newTerminalTab = Notification.Name("newTerminalTab")
    static let splitHorizontally = Notification.Name("splitHorizontally")
    static let splitVertically = Notification.Name("splitVertically")
    static let toggleMaximize = Notification.Name("toggleMaximize")
    static let focusPreviousPane = Notification.Name("focusPreviousPane")
    static let focusNextPane = Notification.Name("focusNextPane")
}
