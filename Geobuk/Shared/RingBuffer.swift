import Foundation

/// 고정 크기 링 버퍼 (최근 N 라인 보관)
/// 스레드 안전: NSLock 사용
final class RingBuffer: @unchecked Sendable {
    private var buffer: [String?]
    private var writeIndex: Int = 0
    private var count: Int = 0
    private let capacity: Int
    private let lock = NSLock()

    init(capacity: Int = 1000) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
        self.buffer = [String?](repeating: nil, count: capacity)
    }

    /// 한 줄 추가
    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        buffer[writeIndex] = line
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity {
            count += 1
        }
    }

    /// 최근 N 줄 반환 (오래된 순서대로)
    func lastLines(_ requestedCount: Int) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        guard requestedCount > 0, count > 0 else { return [] }

        let n = min(requestedCount, count)
        var result = [String]()
        result.reserveCapacity(n)

        // writeIndex points to the next write position
        // The oldest entry in range starts at (writeIndex - count) mod capacity
        // We want the last n entries
        let startIndex = (writeIndex - n + capacity) % capacity
        for i in 0..<n {
            let idx = (startIndex + i) % capacity
            if let line = buffer[idx] {
                result.append(line)
            }
        }
        return result
    }

    /// 버퍼 초기화
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer = [String?](repeating: nil, count: capacity)
        writeIndex = 0
        count = 0
    }
}
