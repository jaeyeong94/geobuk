import Foundation

/// Tab 완성 캐시 + ShellCompletionSession 관리.
/// AppCoordinator에서 하나만 생성하여 앱 수명 동안 유지한다.
@MainActor
final class TabCompletionProvider {

    private let session = ShellCompletionSession()
    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 5.0
    private var currentCwd: String = NSHomeDirectory()

    private struct CacheEntry {
        let results: [String]
        let timestamp: Date
    }

    // MARK: - Lifecycle

    func start() {
        session.start()
    }

    func updateCwd(_ cwd: String) {
        guard cwd != currentCwd else { return }
        currentCwd = cwd
        session.updateCwd(cwd)
        // CWD 변경 시 캐시 무효화 (파일 경로 완성이 달라짐)
        cache.removeAll()
    }

    func destroy() {
        session.destroy()
        cache.removeAll()
    }

    // MARK: - Completion

    /// Tab 완성 결과를 반환한다 (캐시 활용).
    func complete(_ input: String) async -> [String] {
        guard !input.isEmpty else { return [] }

        let cacheKey = "\(currentCwd):\(input)"

        // 캐시 히트
        if let entry = cache[cacheKey],
           Date().timeIntervalSince(entry.timestamp) < cacheTTL {
            return entry.results
        }

        // 세션이 준비되지 않았으면 빈 결과
        guard session.isReady else {
            // 재시작 시도
            if cache.isEmpty { session.restart() }
            return []
        }

        // Tab 완성 실행
        let results = await session.complete(input)

        // 캐시 저장
        cache[cacheKey] = CacheEntry(results: results, timestamp: Date())

        // 오래된 캐시 정리 (100개 초과 시)
        if cache.count > 100 {
            pruneCache()
        }

        return results
    }

    // MARK: - Private

    private func pruneCache() {
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) < cacheTTL }
    }
}
