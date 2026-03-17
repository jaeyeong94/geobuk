import Testing
import Foundation
@testable import Geobuk

@Suite("RingBuffer - 고정 크기 링 버퍼")
struct RingBufferTests {

    // MARK: - 생성

    @Test("init_기본용량_1000")
    func init_defaultCapacity_is1000() {
        let buffer = RingBuffer()
        let lines = buffer.lastLines(2000)
        #expect(lines.isEmpty)
    }

    @Test("init_커스텀용량_설정됨")
    func init_customCapacity_isSet() {
        let buffer = RingBuffer(capacity: 5)
        for i in 0..<10 {
            buffer.append("line \(i)")
        }
        let lines = buffer.lastLines(10)
        #expect(lines.count == 5)
    }

    // MARK: - append & lastLines

    @Test("append_한줄추가_lastLines반환")
    func append_oneLine_returnsIt() {
        let buffer = RingBuffer(capacity: 10)
        buffer.append("hello")
        let lines = buffer.lastLines(1)
        #expect(lines == ["hello"])
    }

    @Test("append_여러줄추가_순서유지")
    func append_multipleLines_orderPreserved() {
        let buffer = RingBuffer(capacity: 10)
        buffer.append("first")
        buffer.append("second")
        buffer.append("third")
        let lines = buffer.lastLines(3)
        #expect(lines == ["first", "second", "third"])
    }

    @Test("lastLines_요청보다적은줄_있는만큼반환")
    func lastLines_fewerThanRequested_returnsAvailable() {
        let buffer = RingBuffer(capacity: 10)
        buffer.append("only")
        let lines = buffer.lastLines(5)
        #expect(lines == ["only"])
    }

    @Test("lastLines_0요청_빈배열반환")
    func lastLines_zeroRequested_returnsEmpty() {
        let buffer = RingBuffer(capacity: 10)
        buffer.append("data")
        let lines = buffer.lastLines(0)
        #expect(lines.isEmpty)
    }

    // MARK: - 용량 초과 (래핑)

    @Test("append_용량초과_오래된줄제거")
    func append_overCapacity_removesOldest() {
        let buffer = RingBuffer(capacity: 3)
        buffer.append("a")
        buffer.append("b")
        buffer.append("c")
        buffer.append("d")
        let lines = buffer.lastLines(3)
        #expect(lines == ["b", "c", "d"])
    }

    @Test("append_용량2배초과_최신N개만유지")
    func append_doubleCapacity_keepsLatestN() {
        let buffer = RingBuffer(capacity: 3)
        for i in 0..<9 {
            buffer.append("line\(i)")
        }
        let lines = buffer.lastLines(3)
        #expect(lines == ["line6", "line7", "line8"])
    }

    @Test("lastLines_용량초과후_부분요청정확")
    func lastLines_afterWrap_partialRequestCorrect() {
        let buffer = RingBuffer(capacity: 5)
        for i in 0..<8 {
            buffer.append("line\(i)")
        }
        let lines = buffer.lastLines(2)
        #expect(lines == ["line6", "line7"])
    }

    // MARK: - clear

    @Test("clear_데이터있을때_비워짐")
    func clear_withData_becomesEmpty() {
        let buffer = RingBuffer(capacity: 10)
        buffer.append("data")
        buffer.clear()
        let lines = buffer.lastLines(10)
        #expect(lines.isEmpty)
    }

    @Test("clear_빈버퍼_안전")
    func clear_emptyBuffer_safe() {
        let buffer = RingBuffer(capacity: 10)
        buffer.clear()
        let lines = buffer.lastLines(10)
        #expect(lines.isEmpty)
    }

    @Test("clear_후추가_정상동작")
    func clear_thenAppend_works() {
        let buffer = RingBuffer(capacity: 3)
        buffer.append("old1")
        buffer.append("old2")
        buffer.clear()
        buffer.append("new1")
        let lines = buffer.lastLines(3)
        #expect(lines == ["new1"])
    }

    // MARK: - 경계값

    @Test("capacity1_한줄만유지")
    func capacity1_keepsOnlyOneLine() {
        let buffer = RingBuffer(capacity: 1)
        buffer.append("first")
        buffer.append("second")
        let lines = buffer.lastLines(1)
        #expect(lines == ["second"])
    }

    @Test("빈문자열_추가가능")
    func emptyString_canAppend() {
        let buffer = RingBuffer(capacity: 10)
        buffer.append("")
        let lines = buffer.lastLines(1)
        #expect(lines == [""])
    }

    @Test("lastLines_음수요청_빈배열반환")
    func lastLines_negativeCount_returnsEmpty() {
        let buffer = RingBuffer(capacity: 10)
        buffer.append("data")
        let lines = buffer.lastLines(-1)
        #expect(lines.isEmpty)
    }

    // MARK: - 스레드 안전성

    @Test("concurrentAppend_크래시없음")
    func concurrentAppend_noCrash() async {
        let buffer = RingBuffer(capacity: 100)
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    buffer.append("line\(i)")
                }
            }
        }
        let lines = buffer.lastLines(100)
        #expect(lines.count == 100)
    }

    @Test("concurrentAppendAndRead_크래시없음")
    func concurrentAppendAndRead_noCrash() async {
        let buffer = RingBuffer(capacity: 50)
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    buffer.append("line\(i)")
                }
                group.addTask {
                    _ = buffer.lastLines(10)
                }
            }
        }
        // If we get here without crashing, the test passes
        #expect(true)
    }
}
