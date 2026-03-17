import SwiftUI

struct ContentView: View {
    @State private var ghosttyApp = GhosttyApp()
    @State private var splitManager = SplitTreeManager()
    @State private var surfaceViews: [UUID: GhosttySurfaceView] = [:]
    @State private var errorMessage: String?
    @State private var isInitialized = false

    var body: some View {
        Group {
            if isInitialized {
                SplitContainerView(
                    node: splitManager.root,
                    focusedPaneId: splitManager.focusedPaneId,
                    onFocusPane: { id in
                        splitManager.setFocusedPane(id: id)
                    },
                    surfaceViewProvider: { id in
                        surfaceViews[id]
                    }
                )
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Terminal Error")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Initializing terminal...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color.black)
        .task {
            await initializeTerminal()
        }
        .onReceive(NotificationCenter.default.publisher(for: .splitHorizontally)) { _ in
            splitFocusedPane(direction: .horizontal)
        }
        .onReceive(NotificationCenter.default.publisher(for: .splitVertically)) { _ in
            splitFocusedPane(direction: .vertical)
        }
        .onDisappear {
            for surfaceView in surfaceViews.values {
                surfaceView.close()
            }
            surfaceViews.removeAll()
            ghosttyApp.destroy()
        }
    }

    // MARK: - Terminal Initialization

    @MainActor
    private func initializeTerminal() async {
        do {
            try ghosttyApp.create()
            // 초기 패널용 surface 생성
            let initialPaneId = splitManager.focusedPaneId!
            let surfaceView = GhosttySurfaceView(app: ghosttyApp)
            surfaceViews[initialPaneId] = surfaceView
            isInitialized = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Split Operations

    @MainActor
    private func splitFocusedPane(direction: SplitDirection) {
        guard isInitialized else { return }

        splitManager.splitFocusedPane(direction: direction)

        // 새 패널용 surface 생성
        if let newPaneId = splitManager.focusedPaneId,
           surfaceViews[newPaneId] == nil {
            let surfaceView = GhosttySurfaceView(app: ghosttyApp)
            surfaceViews[newPaneId] = surfaceView
        }
    }
}

#Preview {
    ContentView()
}
