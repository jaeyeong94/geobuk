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
        }
    }
}

extension Notification.Name {
    static let newTerminalTab = Notification.Name("newTerminalTab")
    static let splitHorizontally = Notification.Name("splitHorizontally")
    static let splitVertically = Notification.Name("splitVertically")
}
