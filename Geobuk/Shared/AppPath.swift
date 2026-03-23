import Foundation

/// Geobuk 앱의 파일 시스템 경로를 관리하는 유틸리티
enum AppPath {
    /// ~/Library/Application Support/Geobuk/
    static let appSupport: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let geobukDir = url.appendingPathComponent("Geobuk")
        try? FileManager.default.createDirectory(at: geobukDir, withIntermediateDirectories: true)
        return geobukDir
    }()

    /// ~/Library/Application Support/Geobuk/ as String path
    static var appSupportPath: String { appSupport.path }

    /// ~/Library/Application Support/Geobuk/bin/ — shim 스크립트 설치 디렉토리
    static let binDir: URL = {
        let dir = appSupport.appendingPathComponent("bin")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// it2 shim을 bin 디렉토리에 설치한다
    static func installShims() {
        let shimContent = """
        #!/bin/bash
        set -euo pipefail
        SOCKET_PATH="${GEOBUK_SOCKET_PATH:-}"
        SURFACE_ID="${GEOBUK_SURFACE_ID:-}"
        [ -z "$SOCKET_PATH" ] || [ -z "$SURFACE_ID" ] && exit 1
        _send_rpc() {
            if command -v socat &>/dev/null; then
                echo "$1" | socat -t 1 - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null
            else
                echo "$1" | nc -U -w 1 "$SOCKET_PATH" 2>/dev/null
            fi
        }
        _extract_result() {
            echo "$1" | sed -n 's/.*"result":"\\([^"]*\\)".*/\\1/p'
        }
        case "${1:-}" in
            session)
                case "${2:-}" in
                    list) exit 0 ;;
                    split)
                        shift 2
                        SOURCE_ID=""
                        while [ $# -gt 0 ]; do
                            case "$1" in
                                -v|-h) shift ;;
                                -s) SOURCE_ID="$2"; shift 2 ;;
                                *) shift ;;
                            esac
                        done
                        SPLIT_SOURCE="${SOURCE_ID:-$SURFACE_ID}"
                        RESPONSE=$(_send_rpc "{\\"jsonrpc\\":\\"2.0\\",\\"method\\":\\"pane.split\\",\\"params\\":{\\"sourcePaneId\\":\\"$SPLIT_SOURCE\\",\\"direction\\":\\"horizontal\\"},\\"id\\":1}")
                        PANE_ID=$(_extract_result "$RESPONSE")
                        if [ -n "$PANE_ID" ]; then
                            echo "Created new pane: $PANE_ID"
                            exit 0
                        fi
                        exit 1
                        ;;
                    *) exit 1 ;;
                esac
                ;;
            *)
                PANE_ID="${1:-}"
                SUBCOMMAND="${2:-}"
                if [ "$SUBCOMMAND" = "send-keys" ]; then
                    TEXT=$(cat)
                    ESCAPED_TEXT=$(echo -n "$TEXT" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\\t/\\\\t/g' | tr -d '\\n')
                    _send_rpc "{\\"jsonrpc\\":\\"2.0\\",\\"method\\":\\"pane.sendKeys\\",\\"params\\":{\\"paneId\\":\\"$PANE_ID\\",\\"text\\":\\"$ESCAPED_TEXT\\"},\\"id\\":1}" > /dev/null
                    exit 0
                fi
                exit 1
                ;;
        esac
        """

        let it2Path = binDir.appendingPathComponent("it2")
        try? shimContent.write(to: it2Path, atomically: true, encoding: .utf8)

        // 실행 권한 부여
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: it2Path.path)
    }
}
