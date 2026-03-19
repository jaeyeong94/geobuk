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

# SIGWINCH 핸들러: 리사이즈 시 reflow 아티팩트 완화
# Ghostty의 OSC 133 프롬프트 마크에 redraw=last를 추가하여
# 리사이즈 시 마지막 프롬프트만 다시 그리도록 함
_geobuk_precmd_prompt_mark() {
    # OSC 133;A 프롬프트 마크에 redraw=last 힌트 추가
    # 터미널 리사이즈 시 전체 reflow 대신 마지막 프롬프트만 재표시
    printf '\e]133;A;redraw=last\a'
}

# SIGWINCH 핸들러: 리사이즈 시 출력 덮어쓰기 방지
TRAPWINCH() {
    # 기본 SIGWINCH 동작 억제하여 reflow 아티팩트 감소
    :
}

# zsh 훅 등록
precmd_functions+=(_geobuk_precmd)
precmd_functions+=(_geobuk_precmd_prompt_mark)
preexec_functions+=(_geobuk_preexec)

# 최초 로드 시 TTY 보고
_geobuk_report_tty
