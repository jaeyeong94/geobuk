import AppKit

/// ghostty_app_t를 래핑하는 메인 Ghostty 앱 인스턴스
/// 앱 생명주기 동안 하나만 존재해야 함
@MainActor
final class GhosttyApp {
    // MARK: - Properties

    // nonisolated(unsafe): deinit에서 접근 필요 (MainActor 보장 불가)
    nonisolated(unsafe) private var app: ghostty_app_t?
    nonisolated(unsafe) private var config: ghostty_config_t?

    /// Ghostty 앱 초기화 완료 여부
    var isInitialized: Bool { app != nil }

    // MARK: - Initialization

    private static var ghosttyInitialized = false

    /// ghostty_init()을 한 번만 호출 (프로세스 수준)
    private static func ensureGhosttyInit() {
        guard !ghosttyInitialized else { return }
        // ghostty_init은 argc/argv를 받지만, 임베디드 모드에서는 0, nil 전달
        let result = ghostty_init(0, nil)
        ghosttyInitialized = (result == GHOSTTY_SUCCESS)
    }

    // MARK: - Lifecycle

    /// Ghostty 앱 인스턴스 생성
    func create() throws {
        guard app == nil else { return }

        Self.ensureGhosttyInit()

        // 1. Config 생성 및 로드
        guard let cfg = ghostty_config_new() else {
            throw GhosttyError.configCreationFailed
        }
        ghostty_config_load_default_files(cfg)
        ghostty_config_finalize(cfg)
        self.config = cfg

        // 2. Runtime callbacks 설정
        var runtimeConfig = ghostty_runtime_config_s()
        runtimeConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        runtimeConfig.supports_selection_clipboard = false
        runtimeConfig.wakeup_cb = { userdata in
            guard let userdata else { return }
            let app = Unmanaged<GhosttyApp>.fromOpaque(userdata).takeUnretainedValue()
            DispatchQueue.main.async {
                app.tick()
            }
        }
        runtimeConfig.action_cb = { app, target, action in
            // Phase 1: 액션은 로깅만 (탭 생성, 타이틀 변경 등)
            return false
        }
        runtimeConfig.read_clipboard_cb = { userdata, location, state in
            // userdata = SurfaceView의 unretained pointer
            guard let userdata else { return false }
            let surfaceView = Unmanaged<GhosttySurfaceView>.fromOpaque(userdata).takeUnretainedValue()
            guard let surface = surfaceView.surfaceHandle else { return false }
            let pasteboard = NSPasteboard.general
            guard let str = pasteboard.string(forType: .string) else { return false }
            str.withCString { ptr in
                ghostty_surface_complete_clipboard_request(surface, ptr, state, false)
            }
            return true
        }
        runtimeConfig.confirm_read_clipboard_cb = nil
        runtimeConfig.write_clipboard_cb = { userdata, location, content, len, confirm in
            guard let content else { return }
            // content는 ghostty_clipboard_content_s* 배열
            // 첫 번째 항목의 data를 클립보드에 복사
            if len > 0, let data = content.pointee.data {
                let str = String(cString: data)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(str, forType: .string)
            }
        }
        runtimeConfig.close_surface_cb = { userdata, processAlive in
            guard let userdata else { return }
            let surfaceView = Unmanaged<GhosttySurfaceView>.fromOpaque(userdata).takeUnretainedValue()
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .ghosttySurfaceClosed,
                    object: surfaceView,
                    userInfo: ["processAlive": processAlive]
                )
            }
        }

        // 3. App 생성
        guard let ghosttyApp = ghostty_app_new(&runtimeConfig, cfg) else {
            ghostty_config_free(cfg)
            self.config = nil
            throw GhosttyError.appCreationFailed
        }
        self.app = ghosttyApp
    }

    /// Ghostty 앱 리소스 해제
    func destroy() {
        if let app {
            ghostty_app_free(app)
            self.app = nil
        }
        if let config {
            ghostty_config_free(config)
            self.config = nil
        }
    }

    deinit {
        // deinit에서는 직접 C 리소스 해제 (MainActor 보장 불가)
        if let app {
            ghostty_app_free(app)
        }
        if let config {
            ghostty_config_free(config)
        }
    }

    // MARK: - Tick

    /// libghostty 이벤트 처리 (wakeup_cb에서 호출)
    func tick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }

    // MARK: - Surface 생성

    /// 새 터미널 surface 생성을 위한 앱 핸들 반환
    var appHandle: ghostty_app_t? { app }

    /// 앱 포커스 상태 업데이트
    func setFocus(_ focused: Bool) {
        guard let app else { return }
        ghostty_app_set_focus(app, focused)
    }
}

// MARK: - Errors

enum GhosttyError: Error {
    case configCreationFailed
    case appCreationFailed
    case surfaceCreationFailed
}

// MARK: - Notifications

extension Notification.Name {
    static let ghosttySurfaceClosed = Notification.Name("ghosttySurfaceClosed")
}
