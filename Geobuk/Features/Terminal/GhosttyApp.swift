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
        // 사용자 Ghostty 설정 로드 (~/.config/ghostty/config)
        ghostty_config_load_default_files(cfg)

        // Geobuk 기본 설정 오버라이드 (cursor-style = bar 등)
        if let configPath = Bundle.main.path(forResource: "geobuk-default", ofType: "conf") {
            configPath.withCString { ptr in
                ghostty_config_load_file(cfg, ptr)
            }
        }

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
            // PWD 변경 감지 (셸이 cd 할 때 OSC 7로 전달)
            if action.tag == GHOSTTY_ACTION_PWD {
                if target.tag == GHOSTTY_TARGET_SURFACE {
                    let surface = target.target.surface
                    if let userdata = ghostty_surface_userdata(surface) {
                        // pwd 문자열을 콜백 스코프 안에서 복사 (포인터 유효 범위 보장)
                        if let pwdStr = action.action.pwd.pwd {
                            let pwd = String(cString: pwdStr)
                            DispatchQueue.main.async {
                                // main thread에서 surfaceView 유효성 검증
                                // surface가 이미 해제되었으면 userdata가 무효 → 건너뜀
                                guard ghostty_surface_userdata(surface) != nil else { return }
                                let surfaceView = Unmanaged<GhosttySurfaceView>.fromOpaque(userdata).takeUnretainedValue()
                                guard surfaceView.hasSurface else { return }
                                surfaceView.currentDirectory = pwd
                            }
                        }
                    }
                }
                // false 반환: Ghostty 내부에서도 PWD를 처리하도록 허용 (타이틀 바 등)
                return false
            }
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

    // MARK: - 동적 설정 변경

    /// 설정을 동적으로 변경 (슬라이더 등에서 호출)
    func updateSettings(fontSize: Double, paddingX: Double, paddingY: Double, lineHeight: Double) {
        guard let app else { return }

        guard let newConfig = ghostty_config_new() else { return }
        ghostty_config_load_default_files(newConfig)

        // Geobuk 기본 설정 로드
        if let configPath = Bundle.main.path(forResource: "geobuk-default", ofType: "conf") {
            configPath.withCString { ptr in
                ghostty_config_load_file(newConfig, ptr)
            }
        }

        // 사용자 설정 오버라이드를 문자열로 적용
        let overrides = [
            "font-size=\(Int(fontSize))",
            "window-padding-x=\(Int(paddingX))",
            "window-padding-y=\(Int(paddingY))",
            "adjust-cell-height=\(Int((lineHeight - 1.0) * 100))%",
        ]

        for override in overrides {
            // ghostty_config_load_file은 파일 경로만 받으므로 임시 파일 사용
            // 대안: 설정을 geobuk-default.conf에 직접 쓰고 reload
        }

        // 임시 설정 파일 생성
        let tempPath = NSTemporaryDirectory() + "geobuk-settings-override.conf"
        let content = overrides.joined(separator: "\n")
        try? content.write(toFile: tempPath, atomically: true, encoding: .utf8)

        tempPath.withCString { ptr in
            ghostty_config_load_file(newConfig, ptr)
        }

        ghostty_config_finalize(newConfig)
        ghostty_app_update_config(app, newConfig)
        ghostty_config_free(newConfig)

        // 임시 파일 정리
        try? FileManager.default.removeItem(atPath: tempPath)
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
