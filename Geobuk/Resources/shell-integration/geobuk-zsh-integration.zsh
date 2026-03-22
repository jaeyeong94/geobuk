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

# 터미널 너비 (COLUMNS가 0일 수 있으므로 tput 사용)
_geobuk_cols() {
    local c=${COLUMNS:-0}
    (( c <= 0 )) && c=$(tput cols 2>/dev/null || echo 80)
    echo $c
}

# 프롬프트 표시 시 호출 (명령 실행 완료 → 유휴 상태)
_geobuk_precmd() {
    local exit_code=$?
    _geobuk_send '{"jsonrpc":"2.0","method":"shell.reportState","params":{"surfaceId":"'"$GEOBUK_SURFACE_ID"'","state":"prompt"}}'

    # 블록 입력 모드 복귀 시그널 (파일 기반 fallback)
    touch "/tmp/geobuk-precmd-${GEOBUK_SURFACE_ID}" 2>/dev/null

    # 블록 하단 여백 (첫 프롬프트는 스킵)
    if [[ -n "$_GEOBUK_CMD_RUNNING" ]]; then
        unset _GEOBUK_CMD_RUNNING
        echo ''
    fi
}

# JSON 문자열 이스케이프 (개행, 탭, 백슬래시, 따옴표, 제어문자 처리)
_geobuk_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"      # \ -> \\
    s="${s//\"/\\\"}"      # " -> \"
    s="${s//$'\n'/\\n}"    # newline -> \n
    s="${s//$'\r'/\\r}"    # carriage return -> \r
    s="${s//$'\t'/\\t}"    # tab -> \t
    echo -n "$s"
}

# 명령 실행 직전 호출
_geobuk_preexec() {
    # $1 = 실행되는 명령어 전체
    local cmd
    cmd=$(_geobuk_json_escape "$1")
    _geobuk_send '{"jsonrpc":"2.0","method":"shell.reportState","params":{"surfaceId":"'"$GEOBUK_SURFACE_ID"'","state":"running","command":"'"$cmd"'"}}'

    # 명령 시작 시 precmd 시그널 파일 삭제 (앱에서 빠른/느린 명령 판별용)
    rm -f "/tmp/geobuk-precmd-${GEOBUK_SURFACE_ID}" 2>/dev/null

    # 셸이 echo한 명령어 줄을 지우고 블록 헤더로 대체
    # 커서를 한 줄 위로 이동 + 줄 전체 삭제
    printf '\e[1A\e[2K'

    # 블록 구분: 명령어 헤더
    _GEOBUK_CMD_RUNNING=1
    local w=$(_geobuk_cols)
    printf '\e[38;5;238m'
    printf '%.0s─' $(seq 1 $w)
    printf '\e[0m\n'
    printf '  \e[48;5;236m\e[38;5;114m \e[1m❯ %s \e[0m\n' "$1"
    printf '\e[38;5;238m'
    printf '%.0s─' $(seq 1 $w)
    printf '\e[0m\n'
}

# JSON-RPC 메시지를 Geobuk 소켓으로 동기 전송
# 백그라운드(&!)는 zsh job control 지연을 유발하므로 동기로 실행
# socat -t 0.1: 100ms 타임아웃으로 셸 블로킹 최소화
_geobuk_send() {
    if command -v socat &>/dev/null; then
        echo "$1" | socat -t 0.1 - UNIX-CONNECT:"$GEOBUK_SOCKET_PATH" 2>/dev/null
    else
        echo "$1" | nc -U -w 0 "$GEOBUK_SOCKET_PATH" 2>/dev/null
    fi
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

# 블록 입력 모드: 셸 프롬프트 숨김
# Geobuk의 BlockInputBar가 프롬프트 역할을 대신함
# 어떤 zsh 테마든 PS1/RPS1을 덮어써서 숨김
_geobuk_saved_PS1="$PS1"
_geobuk_saved_RPS1="$RPS1"
PS1='$ '
RPS1=''
# precmd에서 테마가 PS1을 복원하는 것을 방지
_geobuk_force_minimal_prompt() {
    PS1='$ '
    RPS1=''
}
precmd_functions=(_geobuk_force_minimal_prompt "${precmd_functions[@]}")

# zsh 훅 등록
precmd_functions+=(_geobuk_precmd)
precmd_functions+=(_geobuk_precmd_prompt_mark)
preexec_functions+=(_geobuk_preexec)

# 최초 로드 시 TTY 보고
_geobuk_report_tty

