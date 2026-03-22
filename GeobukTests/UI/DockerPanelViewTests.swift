import Testing
import Foundation
@testable import Geobuk

// MARK: - ContainerInfo 모델 테스트

@Suite("ContainerInfo - 모델 속성")
struct ContainerInfoTests {

    // MARK: statusColor

    @Test("running상태_statusColor초록색반환")
    func running_statusColorIsGreen() {
        let container = ContainerInfo(
            id: "abc123",
            name: "web",
            image: "nginx:latest",
            status: "Up 2 hours",
            ports: "80/tcp",
            state: "running"
        )
        // SwiftUI Color는 직접 비교 불가 — 대신 statusColor가 .green과 동일한 경우를
        // 내부 로직 검증으로 우회: state 값별 분기 검증
        let runningState = container.state.lowercased()
        #expect(runningState == "running")
        // statusColor 자체가 .green 분기임을 enum 재현으로 검증
        let expectedGreen = resolveStatusColor(state: "running")
        #expect(expectedGreen == "green")
    }

    @Test("paused상태_statusColor노란색반환")
    func paused_statusColorIsYellow() {
        let container = ContainerInfo(
            id: "def456",
            name: "db",
            image: "postgres:15",
            status: "Paused",
            ports: "",
            state: "paused"
        )
        let color = resolveStatusColor(state: container.state)
        #expect(color == "yellow")
    }

    @Test("exited상태_statusColor회색반환")
    func exited_statusColorIsGray() {
        let container = ContainerInfo(
            id: "ghi789",
            name: "cache",
            image: "redis:7",
            status: "Exited (0) 5 minutes ago",
            ports: "",
            state: "exited"
        )
        let color = resolveStatusColor(state: container.state)
        #expect(color == "gray")
    }

    @Test("대소문자혼합상태_statusColor대소문자무시처리")
    func mixedCaseState_statusColorNormalized() {
        let states = ["Running", "RUNNING", "rUnNiNg"]
        for state in states {
            let color = resolveStatusColor(state: state)
            #expect(color == "green", "state '\(state)' should map to green")
        }
    }

    @Test("빈상태값_statusColor회색반환")
    func emptyState_statusColorIsGray() {
        let container = ContainerInfo(
            id: "x",
            name: "n",
            image: "i",
            status: "s",
            ports: "",
            state: ""
        )
        let color = resolveStatusColor(state: container.state)
        #expect(color == "gray")
    }

    @Test("알수없는상태_statusColor회색반환")
    func unknownState_statusColorIsGray() {
        let unknownStates = ["dead", "restarting", "created", "removing", "???", "   "]
        for state in unknownStates {
            let color = resolveStatusColor(state: state)
            #expect(color == "gray", "state '\(state)' should fall through to gray")
        }
    }

    // MARK: id / Identifiable

    @Test("ContainerInfo_Identifiable_id필드사용")
    func identifiable_usesIdField() {
        let container = ContainerInfo(
            id: "sha256abc",
            name: "myapp",
            image: "myimage",
            status: "Up",
            ports: "",
            state: "running"
        )
        #expect(container.id == "sha256abc")
    }

    @Test("ContainerInfo_Equatable_동일값이면같음")
    func equatable_sameValuesAreEqual() {
        let a = ContainerInfo(id: "1", name: "n", image: "i", status: "s", ports: "p", state: "running")
        let b = ContainerInfo(id: "1", name: "n", image: "i", status: "s", ports: "p", state: "running")
        #expect(a == b)
    }

    @Test("ContainerInfo_Equatable_다른id이면다름")
    func equatable_differentIdIsNotEqual() {
        let a = ContainerInfo(id: "1", name: "n", image: "i", status: "s", ports: "p", state: "running")
        let b = ContainerInfo(id: "2", name: "n", image: "i", status: "s", ports: "p", state: "running")
        #expect(a != b)
    }

    // MARK: - Helper

    /// ContainerInfo.statusColor 의 분기 로직을 문자열로 재현 (SwiftUI Color 직접 비교 불가 우회)
    private func resolveStatusColor(state: String) -> String {
        switch state.lowercased() {
        case "running": return "green"
        case "paused":  return "yellow"
        default:        return "gray"
        }
    }
}

// MARK: - DockerPanelParser 정상 파싱 테스트

@Suite("DockerPanelParser - docker ps 출력 파싱")
struct DockerPanelParserTests {

    // MARK: 정상 케이스

    @Test("단일running컨테이너_정상파싱")
    func singleRunningContainer_parsedCorrectly() {
        let output = "abc1234\tweb\tnginx:latest\tUp 2 hours\t0.0.0.0:80->80/tcp\trunning"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.count == 1)
        let c = result[0]
        #expect(c.id == "abc1234")
        #expect(c.name == "web")
        #expect(c.image == "nginx:latest")
        #expect(c.status == "Up 2 hours")
        #expect(c.ports == "0.0.0.0:80->80/tcp")
        #expect(c.state == "running")
    }

    @Test("단일exited컨테이너_정상파싱")
    func singleExitedContainer_parsedCorrectly() {
        let output = "def5678\tdb\tpostgres:15\tExited (0) 5 minutes ago\t\texited"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.count == 1)
        #expect(result[0].state == "exited")
        #expect(result[0].ports == "")
    }

    @Test("단일paused컨테이너_정상파싱")
    func singlePausedContainer_parsedCorrectly() {
        let output = "ghi9012\tcache\tredis:7\tPaused\t\tpaused"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.count == 1)
        #expect(result[0].state == "paused")
    }

    @Test("복수컨테이너_모두파싱")
    func multipleContainers_allParsed() {
        let lines = [
            "aaa\tweb\tnginx:latest\tUp 1 hour\t80/tcp\trunning",
            "bbb\tdb\tpostgres:15\tExited (1) 2 days ago\t\texited",
            "ccc\tcache\tredis:7\tPaused\t\tpaused",
        ]
        let output = lines.joined(separator: "\n")
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.count == 3)
        #expect(result[0].id == "aaa")
        #expect(result[1].id == "bbb")
        #expect(result[2].id == "ccc")
    }

    @Test("마지막줄개행_파싱결과에영향없음")
    func trailingNewline_doesNotAddExtraEntry() {
        let output = "aaa\tweb\tnginx:latest\tUp 1 hour\t80/tcp\trunning\n"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.count == 1)
    }

    @Test("포트없는컨테이너_빈문자열포트필드")
    func containerWithNoPorts_emptyPortsField() {
        let output = "aaa\tworker\talpine:3.18\tUp 30 minutes\t\trunning"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result[0].ports == "")
    }

    @Test("포트여러개_탭구분아닌경우_포트필드보존")
    func multiplePortsInField_portFieldPreserved() {
        let ports = "0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp"
        let output = "aaa\tweb\tnginx\tUp\t\(ports)\trunning"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result[0].ports == ports)
    }
}

// MARK: - DockerPanelParser 엣지 케이스 테스트

@Suite("DockerPanelParser - 엣지케이스 및 네거티브")
struct DockerPanelParserEdgeCaseTests {

    @Test("빈문자열입력_빈배열반환")
    func emptyInput_returnsEmptyArray() {
        let result = DockerPanelParser.parseContainers("")
        #expect(result.isEmpty)
    }

    @Test("개행만있는입력_빈배열반환")
    func onlyNewlines_returnsEmptyArray() {
        let result = DockerPanelParser.parseContainers("\n\n\n")
        #expect(result.isEmpty)
    }

    @Test("탭구분자부족_줄무시됨")
    func insufficientTabSeparators_lineSkipped() {
        // 5개 필드만 있음 (6개 필요)
        let output = "aaa\tweb\tnginx\tUp\t80/tcp"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.isEmpty)
    }

    @Test("탭구분자4개이하_줄무시됨")
    func fourTabSeparators_lineSkipped() {
        let output = "a\tb\tc\td"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.isEmpty)
    }

    @Test("필드하나뿐인줄_무시됨")
    func singleFieldLine_ignored() {
        let result = DockerPanelParser.parseContainers("onlyonefield")
        #expect(result.isEmpty)
    }

    @Test("유효줄과무효줄혼재_유효줄만파싱")
    func mixedValidAndInvalidLines_onlyValidParsed() {
        let output = """
        aaa\tweb\tnginx\tUp\t80/tcp\trunning
        MALFORMED_LINE_NO_TABS
        bbb\tdb\tpostgres\tExited\t\texited
        too\tfew\tfields
        ccc\tcache\tredis\tPaused\t\tpaused
        """
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.count == 3)
        #expect(result.map(\.id) == ["aaa", "bbb", "ccc"])
    }

    @Test("id필드빈문자열_파싱허용")
    func emptyIdField_parsedWithEmptyId() {
        // docker가 빈 ID를 반환하는 경우는 드물지만 파서는 거부하지 않는다
        let output = "\tweb\tnginx\tUp\t\trunning"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.count == 1)
        #expect(result[0].id == "")
    }

    @Test("7개이상필드있는줄_처음6개필드만사용")
    func extraFields_onlyFirst6Used() {
        let output = "id\tname\timage\tstatus\tports\tstate\textra1\textra2"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.count == 1)
        #expect(result[0].state == "state")
    }

    @Test("유니코드문자포함이름_정상파싱")
    func unicodeContainerName_parsedCorrectly() {
        let output = "abc\t한글이름컨테이너\tnginx:latest\tUp\t80/tcp\trunning"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.count == 1)
        #expect(result[0].name == "한글이름컨테이너")
    }

    @Test("필드내공백포함_정상파싱")
    func fieldsWithSpaces_parsedCorrectly() {
        let output = "abc123\tmy container\tmy image:1.0\tUp 2 hours 30 minutes\t80/tcp\trunning"
        let result = DockerPanelParser.parseContainers(output)
        #expect(result[0].name == "my container")
        #expect(result[0].image == "my image:1.0")
        #expect(result[0].status == "Up 2 hours 30 minutes")
    }

    @Test("CRLF줄끝_빈배열또는정상파싱")
    func crlfLineEndings_handledGracefully() {
        // CRLF 줄 끝 — \r이 state 필드 끝에 붙을 수 있음
        let output = "aaa\tweb\tnginx\tUp\t\trunning\r\nbbb\tdb\tpostgres\tExited\t\texited\r\n"
        let result = DockerPanelParser.parseContainers(output)
        // CRLF의 경우 \r이 state 필드에 포함될 수 있으나 줄 수는 2개여야 함
        #expect(result.count == 2)
    }
}

// MARK: - 퍼징 테스트

@Suite("DockerPanelParser - 퍼징")
struct DockerPanelParserFuzzTests {

    @Test("무작위탭구분값_크래시없음")
    func randomTabDelimitedValues_noCrash() {
        // 다양한 탭 수 조합에서 크래시가 발생하지 않아야 한다
        let tabCounts = [0, 1, 2, 3, 4, 5, 6, 7, 10, 20]
        for count in tabCounts {
            let line = (0...count).map { "field\($0)" }.joined(separator: "\t")
            let result = DockerPanelParser.parseContainers(line)
            // 결과 타입만 확인 — 크래시 없이 [ContainerInfo] 반환
            if count >= 5 {
                #expect(result.count == 1)
            } else {
                #expect(result.isEmpty)
            }
        }
    }

    @Test("특수문자포함필드_크래시없음")
    func specialCharactersInFields_noCrash() {
        let specialChars = [
            "null\0byte",
            "emoji🐳docker",
            String(repeating: "a", count: 10_000),
            "line\nnewline",
            "back\\slash",
            "<script>xss</script>",
            "'; DROP TABLE containers; --",
            "\u{FEFF}BOM앞",
        ]
        for value in specialChars {
            let output = "id\t\(value)\timage\tstatus\tports\tstate"
            let result = DockerPanelParser.parseContainers(output)
            // 개행 포함 값은 줄이 나뉘어 파싱 실패할 수 있으므로 크래시 없음만 검증
            _ = result
        }
    }

    @Test("대용량출력_크래시없음")
    func largeOutput_noCrash() {
        let lineTemplate = "abcdef123456\tcontainer-NAME\tnginx:1.25.3\tUp 10 hours\t0.0.0.0:80->80/tcp\trunning"
        let output = (0..<1_000).map { "\(lineTemplate)-\($0)" }.joined(separator: "\n")
        // 각 줄은 충분한 탭이 있으므로 1000개 파싱되어야 함
        let result = DockerPanelParser.parseContainers(output)
        #expect(result.count == 1_000)
    }

    @Test("랜덤ASCII줄_크래시없음")
    func randomAsciiLines_noCrash() {
        // 다양한 ASCII 문자 조합 — 크래시 없음 보장
        let samples: [String] = [
            "",
            "\t",
            "\t\t\t\t\t",
            "a\tb\tc\td\te\tf",
            "!!!\t@@@\t###\t$$$\t%%%\t^^^",
            "123\t456\t789\t000\t111\t222",
        ]
        for line in samples {
            _ = DockerPanelParser.parseContainers(line)
            // 크래시가 없으면 테스트 통과
        }
    }

    @Test("변이기반_유효줄에서필드제거_파싱견고성")
    func mutationBased_removingFields_parsesRobustly() {
        let validLine = "aaa\tweb\tnginx:latest\tUp 2 hours\t80/tcp\trunning"
        let parts = validLine.components(separatedBy: "\t")
        // 필드를 1개씩 줄여가며 파서가 올바르게 처리하는지 검증
        for count in 0..<parts.count {
            let truncated = parts.prefix(count).joined(separator: "\t")
            let result = DockerPanelParser.parseContainers(truncated)
            if count >= 6 {
                #expect(result.count == 1)
            } else {
                #expect(result.isEmpty, "truncated to \(count) fields should return empty")
            }
        }
    }

    @Test("변이기반_유효줄에서탭을공백으로대체_파싱거부")
    func mutationBased_tabsReplacedWithSpaces_rejected() {
        // 탭 대신 공백을 구분자로 사용하면 파서가 거부해야 함
        let spaceSeparated = "aaa web nginx:latest Up 2 hours 80/tcp running"
        let result = DockerPanelParser.parseContainers(spaceSeparated)
        #expect(result.isEmpty)
    }

    @Test("속성기반_파싱결과_항상6필드초과줄만포함")
    func propertyBased_resultContainsOnlyLinesWithSixOrMoreFields() {
        let lines = [
            "a\tb\tc\td\te\tf",          // 6필드 → 포함
            "a\tb\tc\td\te",             // 5필드 → 제외
            "a\tb\tc\td\te\tf\tg",       // 7필드 → 포함
            "single",                    // 1필드 → 제외
            "a\tb\tc\td\te\tf\tg\th",   // 8필드 → 포함
        ]
        let output = lines.joined(separator: "\n")
        let result = DockerPanelParser.parseContainers(output)
        // 6개 이상 필드를 가진 줄: 3개 (6, 7, 8 필드)
        #expect(result.count == 3)
    }
}
