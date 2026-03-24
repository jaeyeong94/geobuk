import SwiftUI

/// 터미널 내 검색 오버레이 (Cmd+F)
struct TerminalSearchOverlay: View {
    let surfaceView: GhosttySurfaceView
    @State private var needle: String = ""
    @State private var total: Int = -1
    @State private var selected: Int = -1
    @FocusState private var isFocused: Bool
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))

            TextField("Find", text: $needle)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .frame(minWidth: 120, maxWidth: 200)
                .onSubmit {
                    surfaceView.navigateSearch(direction: "next")
                }
                .onChange(of: needle) { _, newValue in
                    surfaceView.submitSearch(newValue)
                }

            if total >= 0 {
                Text(total == 0 ? "No results" : "\(selected + 1)/\(total)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Button(action: { surfaceView.navigateSearch(direction: "previous") }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(total <= 0)

            Button(action: { surfaceView.navigateSearch(direction: "next") }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(total <= 0)

            Button(action: { surfaceView.endSearch() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .padding(.leading, 12)
        .padding(.top, 8)
        .onAppear {
            // 약간의 지연 후 포커스 — SwiftUI 레이아웃 완료 후 TextField가 포커스를 받도록
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFocused = true
            }
            needle = surfaceView.searchNeedle
            // 로컬 이벤트 모니터: Esc와 Cmd+F를 캡처
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Esc: 검색 닫기
                if event.keyCode == 53 {
                    DispatchQueue.main.async { surfaceView.endSearch() }
                    return nil // 이벤트 소비
                }
                // Cmd+F: 토글 닫기
                if event.modifierFlags.contains(.command) && event.keyCode == 3 {
                    DispatchQueue.main.async { surfaceView.endSearch() }
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .geobukSearchStateChanged)) { notification in
            guard let sv = notification.object as? GhosttySurfaceView,
                  sv.viewId == surfaceView.viewId else { return }
            total = sv.searchTotal
            selected = sv.searchSelected
        }
    }
}
