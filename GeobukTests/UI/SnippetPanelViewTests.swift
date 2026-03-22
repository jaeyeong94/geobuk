import Testing
import Foundation
@testable import Geobuk

// MARK: - CommandSnippet Model Tests

@Suite("CommandSnippet - 모델 및 직렬화")
struct CommandSnippetTests {

    // MARK: - Identifiable

    @Suite("Identifiable")
    struct IdentifiableTests {

        @Test("기본생성_고유ID할당됨")
        func defaultInit_uniqueIDAssigned() {
            let a = CommandSnippet(name: "a", command: "cmd_a")
            let b = CommandSnippet(name: "b", command: "cmd_b")
            #expect(a.id != b.id)
        }

        @Test("지정ID로생성_해당ID유지됨")
        func customID_preserved() {
            let id = UUID()
            let snippet = CommandSnippet(id: id, name: "n", command: "c")
            #expect(snippet.id == id)
        }
    }

    // MARK: - 기본값

    @Suite("기본값")
    struct DefaultValueTests {

        @Test("카테고리기본값_nil")
        func defaultCategory_isNil() {
            let snippet = CommandSnippet(name: "n", command: "c")
            #expect(snippet.category == nil)
        }

        @Test("생성시각_현재시각근접")
        func createdAt_isNearNow() {
            let before = Date()
            let snippet = CommandSnippet(name: "n", command: "c")
            let after = Date()
            #expect(snippet.createdAt >= before)
            #expect(snippet.createdAt <= after)
        }
    }

    // MARK: - Codable 왕복 직렬화

    @Suite("Codable 왕복 직렬화")
    struct CodableRoundTripTests {

        @Test("기본필드_왕복직렬화_동일값반환")
        func basicFields_roundTrip_preservesValues() throws {
            let original = CommandSnippet(
                id: UUID(),
                name: "git status",
                command: "git status",
                category: "Git",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(CommandSnippet.self, from: data)
            #expect(decoded.id == original.id)
            #expect(decoded.name == original.name)
            #expect(decoded.command == original.command)
            #expect(decoded.category == original.category)
            #expect(decoded.createdAt.timeIntervalSince1970 == original.createdAt.timeIntervalSince1970)
        }

        @Test("카테고리없음_왕복직렬화_nil유지")
        func nilCategory_roundTrip_remainsNil() throws {
            let original = CommandSnippet(name: "ls", command: "ls -la")
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(CommandSnippet.self, from: data)
            #expect(decoded.category == nil)
        }

        @Test("배열직렬화_왕복_동일개수와값")
        func arrayRoundTrip_preservesAllItems() throws {
            let snippets = [
                CommandSnippet(name: "a", command: "cmd_a", category: "Cat"),
                CommandSnippet(name: "b", command: "cmd_b")
            ]
            let data = try JSONEncoder().encode(snippets)
            let decoded = try JSONDecoder().decode([CommandSnippet].self, from: data)
            #expect(decoded.count == 2)
            #expect(decoded[0].name == "a")
            #expect(decoded[1].name == "b")
        }

        @Test("빈배열직렬화_왕복_빈배열반환")
        func emptyArrayRoundTrip_returnsEmptyArray() throws {
            let empty: [CommandSnippet] = []
            let data = try JSONEncoder().encode(empty)
            let decoded = try JSONDecoder().decode([CommandSnippet].self, from: data)
            #expect(decoded.isEmpty)
        }

        @Test("특수문자포함명령어_왕복_보존됨")
        func specialCharactersInCommand_roundTrip_preserved() throws {
            let special = CommandSnippet(
                name: "특수 문자",
                command: "grep -E 'foo|bar' file.txt | awk '{print $1}' && echo \"done\"",
                category: "Unix & Shell"
            )
            let data = try JSONEncoder().encode(special)
            let decoded = try JSONDecoder().decode(CommandSnippet.self, from: data)
            #expect(decoded.name == special.name)
            #expect(decoded.command == special.command)
            #expect(decoded.category == special.category)
        }

        @Test("유니코드문자열_왕복_보존됨")
        func unicodeStrings_roundTrip_preserved() throws {
            let snippet = CommandSnippet(name: "🚀 배포", command: "echo '안녕하세요'", category: "기타")
            let data = try JSONEncoder().encode(snippet)
            let decoded = try JSONDecoder().decode(CommandSnippet.self, from: data)
            #expect(decoded.name == snippet.name)
            #expect(decoded.command == snippet.command)
            #expect(decoded.category == snippet.category)
        }

        @Test("손상된JSON_디코딩실패_에러발생")
        func corruptedJSON_throwsError() {
            let bad = Data("not valid json".utf8)
            #expect(throws: (any Error).self) {
                _ = try JSONDecoder().decode(CommandSnippet.self, from: bad)
            }
        }

        @Test("필수필드누락JSON_디코딩실패_에러발생")
        func missingRequiredField_throwsError() {
            // 'command' 필드 누락
            let json = Data(#"{"id":"00000000-0000-0000-0000-000000000001","name":"x","createdAt":0}"#.utf8)
            #expect(throws: (any Error).self) {
                _ = try JSONDecoder().decode(CommandSnippet.self, from: json)
            }
        }
    }
}

// MARK: - SnippetStore Tests

/// SnippetStore를 테스트용 임시 URL로 주입할 수 없으므로,
/// 각 테스트마다 고유한 임시 디렉토리를 생성하여 사용한다.
/// SnippetStore.storageURL이 static이므로 실제 파일을 건드리지 않도록
/// 테스트는 파일 I/O 결과(메모리 상태)를 검증한다.
@Suite("SnippetStore - 스니펫 저장소")
@MainActor
struct SnippetStoreTests {

    // MARK: - 초기 상태 / 기본 스니펫

    @Suite("초기 상태")
    @MainActor
    struct InitialStateTests {

        @Test("신규초기화_기본스니펫로드됨")
        func freshInit_loadsDefaultSnippets() {
            let store = SnippetStore()
            // 기본 스니펫이 존재하거나 파일에서 로드한 스니펫이 있어야 함
            #expect(!store.snippets.isEmpty)
        }

        @Test("신규초기화_기본스니펫에git포함")
        func freshInit_defaultSnippetsContainGit() {
            let store = SnippetStore()
            let hasGit = store.snippets.contains { $0.category == "Git" }
            #expect(hasGit)
        }

        @Test("신규초기화_기본스니펫에npm포함")
        func freshInit_defaultSnippetsContainNpm() {
            let store = SnippetStore()
            let hasNpm = store.snippets.contains { $0.category == "npm" }
            #expect(hasNpm)
        }

        @Test("신규초기화_기본스니펫에Docker포함")
        func freshInit_defaultSnippetsContainDocker() {
            let store = SnippetStore()
            let hasDocker = store.snippets.contains { $0.category == "Docker" }
            #expect(hasDocker)
        }

        @Test("신규초기화_기본스니펫에System포함")
        func freshInit_defaultSnippetsContainSystem() {
            let store = SnippetStore()
            let hasSystem = store.snippets.contains { $0.category == "System" }
            #expect(hasSystem)
        }
    }

    // MARK: - 추가

    @Suite("스니펫 추가")
    @MainActor
    struct AddTests {

        @Test("스니펫추가_목록에반영됨")
        func add_appendsToSnippets() {
            let store = SnippetStore()
            let before = store.snippets.count
            let snippet = CommandSnippet(name: "test", command: "echo test")
            store.add(snippet)
            #expect(store.snippets.count == before + 1)
        }

        @Test("스니펫추가_마지막위치에삽입됨")
        func add_appendsAtEnd() {
            let store = SnippetStore()
            let snippet = CommandSnippet(name: "last", command: "echo last")
            store.add(snippet)
            #expect(store.snippets.last?.id == snippet.id)
        }

        @Test("여러스니펫추가_순서보존됨")
        func addMultiple_orderPreserved() {
            let store = SnippetStore()
            let initialCount = store.snippets.count
            let s1 = CommandSnippet(name: "first", command: "cmd1")
            let s2 = CommandSnippet(name: "second", command: "cmd2")
            store.add(s1)
            store.add(s2)
            #expect(store.snippets[initialCount].id == s1.id)
            #expect(store.snippets[initialCount + 1].id == s2.id)
        }

        @Test("빈이름스니펫_추가는가능_저장소에반영됨")
        func addEmptyName_storeAcceptsIt() {
            // Store 자체는 유효성 검사를 하지 않음 — View 레이어에서 처리
            let store = SnippetStore()
            let before = store.snippets.count
            let snippet = CommandSnippet(name: "", command: "echo test")
            store.add(snippet)
            #expect(store.snippets.count == before + 1)
        }

        @Test("빈명령어스니펫_추가는가능_저장소에반영됨")
        func addEmptyCommand_storeAcceptsIt() {
            let store = SnippetStore()
            let before = store.snippets.count
            let snippet = CommandSnippet(name: "no-op", command: "")
            store.add(snippet)
            #expect(store.snippets.count == before + 1)
        }
    }

    // MARK: - 제거

    @Suite("스니펫 제거")
    @MainActor
    struct RemoveTests {

        @Test("ID로제거_해당스니펫삭제됨")
        func removeByID_deletesCorrectSnippet() {
            let store = SnippetStore()
            let snippet = CommandSnippet(name: "to-remove", command: "rm")
            store.add(snippet)
            store.remove(id: snippet.id)
            let found = store.snippets.contains { $0.id == snippet.id }
            #expect(!found)
        }

        @Test("ID로제거_다른스니펫유지됨")
        func removeByID_otherSnippetsPreserved() {
            let store = SnippetStore()
            let keep = CommandSnippet(name: "keep", command: "ls")
            let remove = CommandSnippet(name: "remove", command: "rm")
            store.add(keep)
            store.add(remove)
            store.remove(id: remove.id)
            let found = store.snippets.contains { $0.id == keep.id }
            #expect(found)
        }

        @Test("존재하지않는ID로제거_목록변화없음")
        func removeNonExistentID_noChange() {
            let store = SnippetStore()
            let before = store.snippets.count
            store.remove(id: UUID())
            #expect(store.snippets.count == before)
        }

        @Test("오프셋으로제거_해당위치삭제됨")
        func removeByOffsets_deletesAtIndex() {
            let store = SnippetStore()
            // 기존 스니펫 모두 제거 후 새 스니펫 2개 추가
            let ids = store.snippets.map { $0.id }
            for id in ids { store.remove(id: id) }
            let s1 = CommandSnippet(name: "one", command: "cmd1")
            let s2 = CommandSnippet(name: "two", command: "cmd2")
            store.add(s1)
            store.add(s2)
            store.remove(at: IndexSet(integer: 0))
            #expect(store.snippets.count == 1)
            #expect(store.snippets[0].id == s2.id)
        }

        @Test("전체오프셋으로제거_빈배열됨")
        func removeAllOffsets_emptyArray() {
            let store = SnippetStore()
            let all = IndexSet(integersIn: 0..<store.snippets.count)
            store.remove(at: all)
            #expect(store.snippets.isEmpty)
        }
    }

    // MARK: - 순서 변경

    @Suite("스니펫 순서 변경")
    @MainActor
    struct ReorderTests {

        @Test("앞으로이동_순서변경됨")
        func moveToFront_reordersCorrectly() {
            let store = SnippetStore()
            // 모든 기존 항목 제거 후 3개 추가
            let ids = store.snippets.map { $0.id }
            for id in ids { store.remove(id: id) }
            let s1 = CommandSnippet(name: "A", command: "a")
            let s2 = CommandSnippet(name: "B", command: "b")
            let s3 = CommandSnippet(name: "C", command: "c")
            store.add(s1)
            store.add(s2)
            store.add(s3)
            // C(index 2)를 맨 앞(0)으로
            store.reorder(from: IndexSet(integer: 2), to: 0)
            #expect(store.snippets[0].id == s3.id)
            #expect(store.snippets[1].id == s1.id)
            #expect(store.snippets[2].id == s2.id)
        }

        @Test("뒤로이동_순서변경됨")
        func moveToBack_reordersCorrectly() {
            let store = SnippetStore()
            let ids = store.snippets.map { $0.id }
            for id in ids { store.remove(id: id) }
            let s1 = CommandSnippet(name: "A", command: "a")
            let s2 = CommandSnippet(name: "B", command: "b")
            let s3 = CommandSnippet(name: "C", command: "c")
            store.add(s1)
            store.add(s2)
            store.add(s3)
            // A(index 0)를 맨 뒤(3)로
            store.reorder(from: IndexSet(integer: 0), to: 3)
            #expect(store.snippets[0].id == s2.id)
            #expect(store.snippets[1].id == s3.id)
            #expect(store.snippets[2].id == s1.id)
        }

        @Test("동일위치이동_순서불변")
        func moveSamePosition_noChange() {
            let store = SnippetStore()
            let ids = store.snippets.map { $0.id }
            for id in ids { store.remove(id: id) }
            let s1 = CommandSnippet(name: "A", command: "a")
            let s2 = CommandSnippet(name: "B", command: "b")
            store.add(s1)
            store.add(s2)
            let before = store.snippets.map { $0.id }
            store.reorder(from: IndexSet(integer: 0), to: 1)
            let after = store.snippets.map { $0.id }
            #expect(before == after)
        }
    }

    // MARK: - 업데이트

    @Suite("스니펫 업데이트")
    @MainActor
    struct UpdateTests {

        @Test("업데이트_기존스니펫변경됨")
        func update_modifiesExistingSnippet() {
            let store = SnippetStore()
            let snippet = CommandSnippet(name: "old name", command: "old cmd")
            store.add(snippet)
            var updated = snippet
            updated.name = "new name"
            updated.command = "new cmd"
            store.update(updated)
            let found = store.snippets.first { $0.id == snippet.id }
            #expect(found?.name == "new name")
            #expect(found?.command == "new cmd")
        }

        @Test("업데이트_개수변화없음")
        func update_countUnchanged() {
            let store = SnippetStore()
            let snippet = CommandSnippet(name: "name", command: "cmd")
            store.add(snippet)
            let before = store.snippets.count
            var updated = snippet
            updated.name = "changed"
            store.update(updated)
            #expect(store.snippets.count == before)
        }

        @Test("존재하지않는ID업데이트_목록변화없음")
        func updateNonExistent_noChange() {
            let store = SnippetStore()
            let before = store.snippets.count
            let ghost = CommandSnippet(id: UUID(), name: "ghost", command: "ghost cmd")
            store.update(ghost)
            #expect(store.snippets.count == before)
        }

        @Test("카테고리업데이트_변경됨")
        func updateCategory_categoryChanged() {
            let store = SnippetStore()
            let snippet = CommandSnippet(name: "s", command: "c", category: "Old")
            store.add(snippet)
            var updated = snippet
            updated.category = "New"
            store.update(updated)
            let found = store.snippets.first { $0.id == snippet.id }
            #expect(found?.category == "New")
        }

        @Test("카테고리nil로업데이트_nil됨")
        func updateCategoryToNil_becomesNil() {
            let store = SnippetStore()
            let snippet = CommandSnippet(name: "s", command: "c", category: "Cat")
            store.add(snippet)
            var updated = snippet
            updated.category = nil
            store.update(updated)
            let found = store.snippets.first { $0.id == snippet.id }
            #expect(found?.category == nil)
        }
    }

    // MARK: - JSON 파일 직렬화 / 역직렬화

    @Suite("JSON 파일 직렬화")
    @MainActor
    struct JSONPersistenceTests {

        @Test("스니펫인코딩후디코딩_동일내용반환")
        func encodeDecodeSnippets_sameContent() throws {
            let snippets = [
                CommandSnippet(name: "git status", command: "git status", category: "Git"),
                CommandSnippet(name: "ls", command: "ls -la")
            ]
            let data = try JSONEncoder().encode(snippets)
            let decoded = try JSONDecoder().decode([CommandSnippet].self, from: data)
            #expect(decoded.count == snippets.count)
            for (orig, dec) in zip(snippets, decoded) {
                #expect(orig.id == dec.id)
                #expect(orig.name == dec.name)
                #expect(orig.command == dec.command)
                #expect(orig.category == dec.category)
            }
        }

        @Test("임시파일에저장후읽기_동일내용반환")
        func writeReadFile_sameContent() throws {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }

            let url = dir.appendingPathComponent("snippets.json")
            let snippets = [
                CommandSnippet(name: "docker ps", command: "docker ps", category: "Docker")
            ]
            let data = try JSONEncoder().encode(snippets)
            try data.write(to: url, options: .atomic)

            let loaded = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([CommandSnippet].self, from: loaded)
            #expect(decoded.count == 1)
            #expect(decoded[0].name == "docker ps")
        }

        @Test("빈배열저장후읽기_빈배열반환")
        func writeEmptyArray_readReturnsEmptyArray() throws {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }

            let url = dir.appendingPathComponent("snippets.json")
            let empty: [CommandSnippet] = []
            try JSONEncoder().encode(empty).write(to: url, options: .atomic)

            let loaded = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([CommandSnippet].self, from: loaded)
            #expect(decoded.isEmpty)
        }

        @Test("잘못된JSON파일_디코딩실패")
        func invalidJSONFile_decodingFails() throws {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }

            let url = dir.appendingPathComponent("snippets.json")
            try Data("{invalid}".utf8).write(to: url)

            let loaded = try Data(contentsOf: url)
            #expect(throws: (any Error).self) {
                _ = try JSONDecoder().decode([CommandSnippet].self, from: loaded)
            }
        }
    }

    // MARK: - 엣지 케이스

    @Suite("엣지 케이스")
    @MainActor
    struct EdgeCaseTests {

        @Test("특수문자이름스니펫_저장및조회됨")
        func specialCharName_storedAndRetrieved() {
            let store = SnippetStore()
            let snippet = CommandSnippet(name: "!@#$%^&*()", command: "echo special")
            store.add(snippet)
            let found = store.snippets.first { $0.id == snippet.id }
            #expect(found?.name == "!@#$%^&*()")
        }

        @Test("매우긴명령어_저장및조회됨")
        func veryLongCommand_storedAndRetrieved() {
            let store = SnippetStore()
            let longCmd = String(repeating: "a", count: 10_000)
            let snippet = CommandSnippet(name: "long", command: longCmd)
            store.add(snippet)
            let found = store.snippets.first { $0.id == snippet.id }
            #expect(found?.command.count == 10_000)
        }

        @Test("같은이름여러스니펫_모두저장됨")
        func duplicateNames_allStored() {
            let store = SnippetStore()
            let initialCount = store.snippets.count
            let s1 = CommandSnippet(name: "dup", command: "cmd1")
            let s2 = CommandSnippet(name: "dup", command: "cmd2")
            store.add(s1)
            store.add(s2)
            #expect(store.snippets.count == initialCount + 2)
        }

        @Test("같은명령어여러스니펫_모두저장됨")
        func duplicateCommands_allStored() {
            let store = SnippetStore()
            let initialCount = store.snippets.count
            let s1 = CommandSnippet(name: "name1", command: "same cmd")
            let s2 = CommandSnippet(name: "name2", command: "same cmd")
            store.add(s1)
            store.add(s2)
            #expect(store.snippets.count == initialCount + 2)
        }

        @Test("공백만있는카테고리_저장됨")
        func whitespaceCategoryStored() {
            let store = SnippetStore()
            let snippet = CommandSnippet(name: "ws", command: "cmd", category: "   ")
            store.add(snippet)
            let found = store.snippets.first { $0.id == snippet.id }
            #expect(found?.category == "   ")
        }

        @Test("한글이름및명령어_저장및조회됨")
        func koreanNameAndCommand_storedAndRetrieved() {
            let store = SnippetStore()
            let snippet = CommandSnippet(name: "배포 스크립트", command: "echo '배포 중...'", category: "운영")
            store.add(snippet)
            let found = store.snippets.first { $0.id == snippet.id }
            #expect(found?.name == "배포 스크립트")
            #expect(found?.command == "echo '배포 중...'")
            #expect(found?.category == "운영")
        }
    }

    // MARK: - 네거티브 테스트

    @Suite("네거티브 테스트")
    @MainActor
    struct NegativeTests {

        @Test("빈저장소에서오프셋제거_크래시없음")
        func removeFromEmpty_noCrash() {
            let store = SnippetStore()
            let all = IndexSet(integersIn: 0..<store.snippets.count)
            store.remove(at: all)
            // 이미 빈 상태에서 빈 IndexSet 제거 — 크래시 없음
            store.remove(at: IndexSet())
            #expect(store.snippets.isEmpty)
        }

        @Test("동일스니펫두번추가_두개모두저장됨")
        func addSameSnippetTwice_bothStored() {
            let store = SnippetStore()
            let initialCount = store.snippets.count
            let snippet = CommandSnippet(id: UUID(), name: "dup", command: "cmd")
            store.add(snippet)
            store.add(snippet)
            // Store는 중복 ID를 허용함 (de-dup은 View 레이어 책임)
            #expect(store.snippets.count == initialCount + 2)
        }

        @Test("존재하지않는ID업데이트_목록크기불변")
        func updateMissingID_countUnchanged() {
            let store = SnippetStore()
            let before = store.snippets.count
            let ghost = CommandSnippet(id: UUID(), name: "ghost", command: "ghost")
            store.update(ghost)
            #expect(store.snippets.count == before)
        }

        @Test("랜덤UUID로제거_목록크기불변")
        func removeRandomUUID_countUnchanged() {
            let store = SnippetStore()
            let before = store.snippets.count
            store.remove(id: UUID())
            #expect(store.snippets.count == before)
        }
    }
}
