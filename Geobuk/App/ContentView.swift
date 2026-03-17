import SwiftUI

struct ContentView: View {
    @State private var ghosttyApp = GhosttyApp()
    @State private var surfaceView: GhosttySurfaceView?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let surfaceView {
                GeometryReader { geo in
                    TerminalSurfaceRepresentable(
                        surfaceView: surfaceView,
                        size: geo.size
                    )
                }
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
        .onDisappear {
            surfaceView?.close()
            ghosttyApp.destroy()
        }
    }

    @MainActor
    private func initializeTerminal() async {
        do {
            try ghosttyApp.create()
            surfaceView = GhosttySurfaceView(app: ghosttyApp)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
