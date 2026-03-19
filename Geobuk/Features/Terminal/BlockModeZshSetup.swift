import Foundation

/// 블록 입력 모드용 ZDOTDIR 설정
/// 임시 디렉토리에 커스텀 .zshrc를 생성하여 프롬프트 테마를 비활성화
/// .zshrc를 수정/필터링하지 않고, 로드 후 프롬프트만 비활성화
final class BlockModeZshSetup {
    /// 임시 ZDOTDIR 경로 (앱 수명 동안 유지)
    static let zdotdir: String = {
        let dir = NSTemporaryDirectory() + "geobuk-zdotdir"
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let zshrc = ###"""
        # Geobuk Block Mode .zshrc
        # 사용자 .zshrc를 그대로 로드한 후, 프롬프트만 비활성화

        # p10k instant prompt 차단
        typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
        typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
        export GEOBUK_BLOCK_MODE=1

        # 사용자 .zshrc 그대로 로드 (alias, PATH, 플러그인 등 모두 유지)
        ZDOTDIR="$HOME"
        [[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"

        # ── 로드 완료 후 프롬프트 비활성화 ──

        # zsh 프롬프트 시스템 비활성화
        prompt off 2>/dev/null

        # 프롬프트 관련 함수 제거 (테마 무관)
        unfunction prompt_powerlevel9k_setup 2>/dev/null
        unfunction p10k 2>/dev/null

        # precmd/preexec에서 프롬프트 관련 함수 제거
        # 패턴 매칭으로 모든 프롬프트 테마 커버
        precmd_functions=(${precmd_functions:#*powerlevel*})
        precmd_functions=(${precmd_functions:#*p9k*})
        precmd_functions=(${precmd_functions:#*p10k*})
        precmd_functions=(${precmd_functions:#*prompt*})
        precmd_functions=(${precmd_functions:#*starship*})
        preexec_functions=(${preexec_functions:#*powerlevel*})
        preexec_functions=(${preexec_functions:#*p9k*})
        preexec_functions=(${preexec_functions:#*starship*})

        # 최소 프롬프트 강제 (precmd 맨 앞)
        _geobuk_force_prompt() {
            PS1=''
            RPS1=''
            RPROMPT=''
            PROMPT=''
        }
        precmd_functions=(_geobuk_force_prompt "${precmd_functions[@]}")

        # 커서 숨김 (DECTCEM: \e[?25l)
        # 블록 입력 모드에서는 하단 입력창이 커서 역할
        printf '\e[?25l'

        # 명령 실행 후에도 커서 숨김 유지
        _geobuk_hide_cursor() { printf '\e[?25l'; }
        precmd_functions+=(_geobuk_hide_cursor)

        # Geobuk 셸 통합 로드
        [[ -n "$GEOBUK_SHELL_INTEGRATION" ]] && source "$GEOBUK_SHELL_INTEGRATION" 2>/dev/null

        # 웰컴 배너
        echo ""
        printf '\e[38;5;114m'
        echo '            __'
        echo ' .-----.  / _)'
        echo '/  ___  \/  /'
        echo '|  /   \   /'
        echo '|  |    | |'
        echo ' \ \___/ /'
        echo "  '-----'"
        echo ''
        echo '╔══════════════════════════════════════╗'
        echo '║  Geobuk Terminal  v0.1               ║'
        echo '╠══════════════════════════════════════╣'
        echo '║                                      ║'
        echo '║  Cmd+D        Split horizontally     ║'
        echo '║  Cmd+Shift+D  Split vertically       ║'
        echo '║  Cmd+W        Close pane             ║'
        echo '║  Cmd+T        New workspace          ║'
        echo '║  Cmd+,        Settings               ║'
        echo '║  Cmd+B        Toggle sidebar         ║'
        echo '║  Cmd+Opt+Arrows  Navigate panes      ║'
        echo '║  Cmd+Shift+C  New Claude session     ║'
        echo '║                                      ║'
        echo '║  Type commands below ↓               ║'
        echo '╚══════════════════════════════════════╝'
        printf '\e[0m'
        echo ''
        """###
        try? zshrc.write(toFile: dir + "/.zshrc", atomically: true, encoding: .utf8)

        let zshenv = """
        # Geobuk Block Mode .zshenv
        typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
        export GEOBUK_BLOCK_MODE=1
        [[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"
        """
        try? zshenv.write(toFile: dir + "/.zshenv", atomically: true, encoding: .utf8)

        return dir
    }()
}
