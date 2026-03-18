import Testing
import Foundation
@testable import Geobuk

@Suite("ProcessTreeScanner - 프로세스 트리 스캐너")
struct ProcessTreeScannerTests {

    // MARK: - ProcessInfo 모델

    @Test("ProcessInfo_초기화_정상생성")
    func processInfo_init_createsCorrectly() {
        let info = ProcInfo(pid: 123, parentPid: 1, name: "test")
        #expect(info.pid == 123)
        #expect(info.parentPid == 1)
        #expect(info.name == "test")
        #expect(info.id == 123)
    }

    @Test("ProcessInfo_Identifiable_pidをidとして使用")
    func processInfo_identifiable_usesPidAsId() {
        let info = ProcInfo(pid: 42, parentPid: 1, name: "proc")
        #expect(info.id == info.pid)
    }

    @Test("ProcessInfo_Sendable준수")
    func processInfo_sendable_conformance() {
        let info = ProcInfo(pid: 1, parentPid: 0, name: "init")
        let sendableCheck: any Sendable = info
        #expect(sendableCheck is ProcInfo)
    }

    // MARK: - allProcesses

    @Test("allProcesses_비어있지않은목록반환")
    func allProcesses_returnsNonEmptyList() {
        let processes = ProcessTreeScanner.allProcesses()
        #expect(!processes.isEmpty)
    }

    @Test("allProcesses_현재프로세스포함")
    func allProcesses_containsCurrentProcess() {
        let currentPid = getpid()
        let processes = ProcessTreeScanner.allProcesses()
        let found = processes.contains { $0.pid == currentPid }
        #expect(found, "현재 프로세스(\(currentPid))가 목록에 있어야 한다")
    }

    @Test("allProcesses_프로세스간부모자식관계존재")
    func allProcesses_parentChildRelationshipsExist() {
        let processes = ProcessTreeScanner.allProcesses()
        // 최소한 일부 프로세스는 다른 프로세스의 자식이어야 한다
        let pidSet = Set(processes.map(\.pid))
        let childrenWithKnownParent = processes.filter { $0.parentPid > 0 && pidSet.contains($0.parentPid) }
        #expect(!childrenWithKnownParent.isEmpty, "부모가 목록에 있는 자식 프로세스가 존재해야 한다")
    }

    @Test("allProcesses_프로세스이름이비어있지않음")
    func allProcesses_processNamesNotEmpty() {
        let processes = ProcessTreeScanner.allProcesses()
        // 대부분의 프로세스는 이름이 있어야 한다 (일부 커널 프로세스 제외)
        let namedProcesses = processes.filter { !$0.name.isEmpty }
        #expect(namedProcesses.count > 10, "이름이 있는 프로세스가 10개 이상이어야 한다")
    }

    // MARK: - childProcesses

    @Test("childProcesses_launchd의자식프로세스존재")
    func childProcesses_ofLaunchd_returnsProcesses() {
        let children = ProcessTreeScanner.childProcesses(of: 1)
        #expect(!children.isEmpty, "launchd(PID 1)의 자식 프로세스가 있어야 한다")
    }

    @Test("childProcesses_자식의부모PID가일치")
    func childProcesses_parentPidMatches() {
        let parentPid: pid_t = 1
        let children = ProcessTreeScanner.childProcesses(of: parentPid)
        for child in children {
            #expect(child.parentPid == parentPid,
                    "자식 프로세스 \(child.name)(\(child.pid))의 부모 PID가 \(parentPid)여야 한다")
        }
    }

    @Test("childProcesses_존재하지않는PID_빈배열반환")
    func childProcesses_nonExistentPid_returnsEmpty() {
        // 매우 큰 PID는 존재하지 않을 가능성이 높다
        let children = ProcessTreeScanner.childProcesses(of: 99999999)
        #expect(children.isEmpty)
    }

    @Test("childProcesses_PID0_빈배열또는커널프로세스")
    func childProcesses_pidZero_returnsEmptyOrKernel() {
        let children = ProcessTreeScanner.childProcesses(of: 0)
        // PID 0은 커널이므로 자식이 있을 수도 없을 수도 있다
        // 크래시하지 않으면 통과
        _ = children
    }

    // MARK: - findProcess

    @Test("findProcess_현재프로세스의부모에서검색_찾음")
    func findProcess_currentProcessUnderParent_found() {
        // 현재 프로세스는 항상 존재하므로, 현재 프로세스를 부모 아래에서 찾는다
        let currentPid = getpid()
        let allProcs = ProcessTreeScanner.allProcesses()
        guard let currentProc = allProcs.first(where: { $0.pid == currentPid }) else {
            Issue.record("현재 프로세스를 찾을 수 없다")
            return
        }
        // 현재 프로세스 이름으로 부모 아래에서 검색
        let found = ProcessTreeScanner.findProcess(named: currentProc.name, under: currentProc.parentPid)
        #expect(found != nil, "\(currentProc.name)을 부모 PID \(currentProc.parentPid) 하위에서 찾을 수 있어야 한다")
    }

    @Test("findProcess_존재하지않는프로세스_nil반환")
    func findProcess_nonExistentProcess_returnsNil() {
        let result = ProcessTreeScanner.findProcess(named: "this_process_does_not_exist_xyz", under: 1)
        #expect(result == nil)
    }

    @Test("findProcess_빈이름_nil반환")
    func findProcess_emptyName_returnsNil() {
        let result = ProcessTreeScanner.findProcess(named: "", under: 1)
        #expect(result == nil)
    }

    // MARK: - findClaudeProcess

    @Test("findClaudeProcess_Claude미실행시_nil반환")
    func findClaudeProcess_notRunning_returnsNil() {
        // 테스트 환경에서 Claude가 실행 중이지 않다면 nil
        // 이 테스트는 CI에서 Claude가 실행 중이지 않다고 가정
        let result = ProcessTreeScanner.findClaudeProcess(under: getpid())
        #expect(result == nil, "테스트 프로세스 하위에 Claude 프로세스가 없어야 한다")
    }

    @Test("findClaudeProcess_존재하지않는PID_nil반환")
    func findClaudeProcess_nonExistentPid_returnsNil() {
        let result = ProcessTreeScanner.findClaudeProcess(under: 99999999)
        #expect(result == nil)
    }

    // MARK: - 네거티브 테스트

    @Test("childProcesses_음수PID_빈배열반환")
    func childProcesses_negativePid_returnsEmpty() {
        let children = ProcessTreeScanner.childProcesses(of: -1)
        #expect(children.isEmpty)
    }

    @Test("findProcess_음수PID_nil반환")
    func findProcess_negativePid_returnsNil() {
        let result = ProcessTreeScanner.findProcess(named: "test", under: -1)
        #expect(result == nil)
    }

    @Test("findClaudeProcess_음수PID_nil반환")
    func findClaudeProcess_negativePid_returnsNil() {
        let result = ProcessTreeScanner.findClaudeProcess(under: -1)
        #expect(result == nil)
    }

    // MARK: - 경계값 테스트

    @Test("allProcesses_PID값이양수")
    func allProcesses_pidsArePositive() {
        let processes = ProcessTreeScanner.allProcesses()
        for proc in processes {
            #expect(proc.pid >= 0, "PID는 0 이상이어야 한다: \(proc.name)(\(proc.pid))")
        }
    }

    @Test("allProcesses_parentPid값이유효")
    func allProcesses_parentPidsAreValid() {
        let processes = ProcessTreeScanner.allProcesses()
        for proc in processes {
            #expect(proc.parentPid >= 0, "부모 PID는 0 이상이어야 한다: \(proc.name)(\(proc.pid))")
        }
    }

    // MARK: - Sendable 준수

    @Test("ProcessTreeScanner_Sendable준수")
    func processTreeScanner_isSendable() {
        let scanner = ProcessTreeScanner()
        let sendableCheck: any Sendable = scanner
        #expect(sendableCheck is ProcessTreeScanner)
    }
}
