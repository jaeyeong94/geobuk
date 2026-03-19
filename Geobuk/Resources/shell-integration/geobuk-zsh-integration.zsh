# Geobuk Shell Integration for zsh
# Geobuk 터미널 내부에서 실행 시 자동으로 source된다
# 셸 상태(유휴/명령 실행 중)를 Geobuk 앱에 보고한다

# Geobuk 내부가 아니면 스킵
[[ -z "$GEOBUK_SURFACE_ID" ]] && return
[[ -z "$GEOBUK_SOCKET_PATH" ]] && return

# 중복 로드 방지
[[ -n "$_GEOBUK_INTEGRATION_LOADED" ]] && return
_GEOBUK_INTEGRATION_LOADED=1

# TTY 이름을 Geobuk에 보고
_geobuk_report_tty() {
    local tty_name
    tty_name=$(tty)
    _geobuk_send '{"jsonrpc":"2.0","method":"shell.reportTty","params":{"surfaceId":"'"$GEOBUK_SURFACE_ID"'","tty":"'"$tty_name"'"}}'
}

# 프롬프트 표시 시 호출 (명령 실행 완료 → 유휴 상태)
_geobuk_precmd() {
    _geobuk_send '{"jsonrpc":"2.0","method":"shell.reportState","params":{"surfaceId":"'"$GEOBUK_SURFACE_ID"'","state":"prompt"}}'
}

# 명령 실행 직전 호출
_geobuk_preexec() {
    # $1 = 실행되는 명령어 전체
    local cmd="${1//\"/\\\"}"
    _geobuk_send '{"jsonrpc":"2.0","method":"shell.reportState","params":{"surfaceId":"'"$GEOBUK_SURFACE_ID"'","state":"running","command":"'"$cmd"'"}}'
}

# JSON-RPC 메시지를 Geobuk 소켓으로 전송 (fire-and-forget)
# 소켓 전송 실패해도 셸 동작에 영향 없음
_geobuk_send() {
    if command -v socat &>/dev/null; then
        echo "$1" | socat - UNIX-CONNECT:"$GEOBUK_SOCKET_PATH" 2>/dev/null &
    else
        echo "$1" | nc -U -w 1 "$GEOBUK_SOCKET_PATH" 2>/dev/null &
    fi
    disown 2>/dev/null
}

# zsh 훅 등록
precmd_functions+=(_geobuk_precmd)
preexec_functions+=(_geobuk_preexec)

# 최초 로드 시 TTY 보고
_geobuk_report_tty
