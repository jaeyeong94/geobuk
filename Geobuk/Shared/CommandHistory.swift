import Foundation

/// 명령어 히스토리를 관리하는 값 타입
/// 위/아래 화살표로 이전 명령어를 탐색할 수 있다
struct CommandHistory: Sendable {
    /// 저장된 명령어 목록 (오래된 순)
    private(set) var commands: [String] = []

    /// 현재 탐색 인덱스 (-1: 탐색 중이 아님, 0: 가장 최근)
    private var navigationIndex: Int = -1

    /// 최대 저장 크기
    private let maxSize: Int

    init(maxSize: Int = 1000) {
        self.maxSize = maxSize
    }

    // MARK: - 명령어 추가

    /// 새 명령어를 히스토리에 추가한다
    /// - 빈 문자열이나 공백만 있는 문자열은 무시한다
    /// - 직전 명령어와 동일하면 중복 추가하지 않는다
    /// - 최대 크기 초과 시 가장 오래된 명령어를 제거한다
    mutating func add(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // 연속 중복 방지
        if commands.last == command { return }

        commands.append(command)

        // 최대 크기 제한
        if commands.count > maxSize {
            commands.removeFirst(commands.count - maxSize)
        }

        resetNavigation()
    }

    // MARK: - 탐색

    /// 위로 탐색 (이전 명령어)
    /// - Returns: 이전 명령어, 없으면 nil
    mutating func navigateUp() -> String? {
        guard !commands.isEmpty else { return nil }

        if navigationIndex == -1 {
            // 처음 위로 탐색: 가장 최근 명령어
            navigationIndex = commands.count - 1
        } else if navigationIndex > 0 {
            navigationIndex -= 1
        }
        // navigationIndex == 0이면 가장 오래된 명령, 더 이상 위로 못감

        return commands[navigationIndex]
    }

    /// 아래로 탐색 (다음 명령어)
    /// - Returns: 다음 명령어, 맨 아래면 nil
    mutating func navigateDown() -> String? {
        guard navigationIndex >= 0 else { return nil }

        if navigationIndex < commands.count - 1 {
            navigationIndex += 1
            return commands[navigationIndex]
        } else {
            // 맨 아래 도달: 탐색 리셋
            navigationIndex = -1
            return nil
        }
    }

    /// 탐색 인덱스를 초기 상태로 리셋한다
    mutating func resetNavigation() {
        navigationIndex = -1
    }
}
