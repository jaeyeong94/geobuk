import Foundation

/// 블록 입력 모드용 ZDOTDIR 설정
/// 임시 디렉토리에 커스텀 .zshrc를 생성하여 프롬프트 테마를 비활성화
final class BlockModeZshSetup {
    /// 임시 ZDOTDIR 경로 (앱 수명 동안 유지)
    static let zdotdir: String = {
        let dir = NSTemporaryDirectory() + "geobuk-zdotdir"
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // 커스텀 .zshrc 생성
        let zshrc = ###"""
        # Geobuk Block Mode .zshrc
        # 사용자 설정을 로드하되 프롬프트 테마를 완전 비활성화

        # p10k instant prompt 차단 (source 전에 함수 재정의)
        typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
        typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

        # 사용자의 .zshrc를 로드하되, p10k/프롬프트 관련 부분을 필터링
        ZDOTDIR="$HOME"
        if [[ -f "$HOME/.zshrc" ]]; then
            # .zshrc에서 프롬프트 테마 관련 줄을 제거하고 실행
            eval "$(sed \
                -e '/p10k-instant-prompt/d' \
                -e '/source.*p10k\.zsh/d' \
                -e '/ZSH_THEME=/s/.*/ZSH_THEME=""/' \
                "$HOME/.zshrc" 2>/dev/null)"
        fi

        # 프롬프트 시스템 완전 리셋
        prompt off 2>/dev/null
        PS1='$ '
        RPS1=''
        RPROMPT=''
        PROMPT='$ '

        # p10k 함수가 로드되었다면 제거
        unfunction prompt_powerlevel9k_setup 2>/dev/null
        unfunction p10k 2>/dev/null

        # precmd/preexec에서 p10k 관련 함수 제거
        precmd_functions=(${precmd_functions:#*powerlevel*})
        precmd_functions=(${precmd_functions:#*p9k*})
        precmd_functions=(${precmd_functions:#*p10k*})
        preexec_functions=(${preexec_functions:#*powerlevel*})
        preexec_functions=(${preexec_functions:#*p9k*})

        # 프롬프트 강제 유지 (precmd 맨 앞에서 실행)
        _geobuk_force_prompt() { PS1='$ '; RPS1=''; RPROMPT=''; PROMPT='$ '; }
        precmd_functions=(_geobuk_force_prompt "${precmd_functions[@]}")

        # Geobuk 셸 통합 로드
        [[ -n "$GEOBUK_SHELL_INTEGRATION" ]] && source "$GEOBUK_SHELL_INTEGRATION" 2>/dev/null
        """###
        try? zshrc.write(toFile: dir + "/.zshrc", atomically: true, encoding: .utf8)

        // .zshenv도 생성 (p10k instant prompt 차단)
        let zshenv = """
        # Geobuk Block Mode .zshenv
        # p10k instant prompt 비활성화
        typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
        # 사용자의 .zshenv 로드
        [[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"
        """
        try? zshenv.write(toFile: dir + "/.zshenv", atomically: true, encoding: .utf8)

        return dir
    }()
}
