import AppKit

/// libghostty C API의 thin wrapper
/// 안정적인 API 서브셋만 노출하여 API 변경에 대한 격리 계층 역할
///
/// 이 어댑터는 TerminalRenderer 프로토콜을 구현하며,
/// 향후 SwiftTerm 폴백으로 교체 가능한 인터페이스를 제공합니다.
final class GhosttyTerminalAdapter: TerminalRenderer {
    // MARK: - Properties

    private var app: OpaquePointer?     // ghostty_app_t
    private var surface: OpaquePointer? // ghostty_surface_t
    private var config: OpaquePointer?  // ghostty_config_t

    private let _surfaceView: NSView

    var surfaceView: NSView { _surfaceView }

    // MARK: - Initialization

    /// 어댑터 초기화 (libghostty가 빌드되지 않은 경우 placeholder 뷰 사용)
    init() {
        // Phase 0: placeholder - libghostty 빌드 후 실제 surface로 교체
        _surfaceView = NSView()
        _surfaceView.wantsLayer = true
        _surfaceView.layer?.backgroundColor = NSColor.black.cgColor
    }

    deinit {
        destroy()
    }

    // MARK: - TerminalRenderer

    func resize(columns: UInt16, rows: UInt16) {
        guard let surface else { return }
        // ghostty_surface_set_size(surface, UInt32(columns), UInt32(rows))
    }

    func setFocus(_ focused: Bool) {
        guard let surface else { return }
        // ghostty_surface_set_focus(surface, focused)
    }

    func setContentScale(_ scaleX: Double, _ scaleY: Double) {
        guard let surface else { return }
        // ghostty_surface_set_content_scale(surface, scaleX, scaleY)
    }

    func handleKey(_ event: NSEvent) -> Bool {
        guard surface != nil else { return false }
        // ghostty_surface_key(surface, ...)
        return false
    }

    func insertText(_ text: String) {
        guard surface != nil else { return }
        // ghostty_surface_text(surface, text, text.utf8.count)
    }

    func destroy() {
        if let surface {
            // ghostty_surface_free(surface)
            self.surface = nil
        }
        if let config {
            // ghostty_config_free(config)
            self.config = nil
        }
        if let app {
            // ghostty_app_free(app)
            self.app = nil
        }
    }

    // MARK: - Ghostty Info (C API 연동 검증)

    /// libghostty 빌드 정보 조회 (C API 호출 검증용)
    struct GhosttyInfo {
        let version: String
        let buildMode: String
    }

    /// ghostty_info() C API를 호출하여 라이브러리 정보 반환
    static func getGhosttyInfo() -> GhosttyInfo {
        let info = ghostty_info()

        let version: String
        if let ptr = info.version, info.version_len > 0 {
            version = String(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: ptr),
                length: Int(info.version_len),
                encoding: .utf8,
                freeWhenDone: false
            ) ?? "unknown"
        } else {
            version = "unknown"
        }

        let buildMode: String = switch info.build_mode {
        case GHOSTTY_BUILD_MODE_DEBUG: "debug"
        case GHOSTTY_BUILD_MODE_RELEASE_SAFE: "release-safe"
        case GHOSTTY_BUILD_MODE_RELEASE_FAST: "release-fast"
        case GHOSTTY_BUILD_MODE_RELEASE_SMALL: "release-small"
        default: "unknown"
        }

        return GhosttyInfo(version: version, buildMode: buildMode)
    }

    // MARK: - Ghostty Lifecycle (Phase 1에서 구현)

    /// Ghostty 앱 인스턴스 초기화
    func initializeGhostty() throws {
        // Phase 1에서 구현:
        // 1. ghostty_config_new() → config
        // 2. ghostty_config_load_default_files(config)
        // 3. ghostty_config_finalize(config)
        // 4. ghostty_app_new(&runtimeConfig, config) → app
        // 5. ghostty_surface_new(app, &surfaceConfig) → surface
    }

    /// 프레임 틱 (호스트 이벤트 루프에서 호출)
    func tick() {
        guard let app else { return }
        // ghostty_app_tick(app)
    }
}
