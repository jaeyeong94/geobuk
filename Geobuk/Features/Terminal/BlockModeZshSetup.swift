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
        let zshrc = """
        # Geobuk Block Mode .zshrc
        # 프롬프트 테마를 비활성화하고 사용자 설정을 로드

        # 프롬프트 테마 비활성화 (p10k, oh-my-zsh 테마 등)
        ZSH_THEME=""
        POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
        POWERLEVEL9K_INSTANT_PROMPT=off

        # 사용자의 원래 ZDOTDIR 복원 후 .zshrc 로드
        ZDOTDIR="$HOME"
        [[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"

        # .zshrc 로드 후 프롬프트 강제 덮어쓰기
        PS1='$ '
        RPS1=''
        RPROMPT=''
        PROMPT='$ '

        # precmd에서 프롬프트를 복원하려는 모든 시도를 차단
        _geobuk_force_prompt() { PS1='$ '; RPS1=''; RPROMPT=''; PROMPT='$ '; }
        precmd_functions=(_geobuk_force_prompt "${precmd_functions[@]}")

        # Geobuk 셸 통합 로드
        [[ -n "$GEOBUK_SHELL_INTEGRATION" ]] && source "$GEOBUK_SHELL_INTEGRATION" 2>/dev/null
        """
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
