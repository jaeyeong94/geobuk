import Testing
import Foundation
@testable import Geobuk

// MARK: - SSHHostInfo 모델 테스트

@Suite("SSHHostInfo - 모델 속성")
struct SSHHostInfoModelTests {

    @Test("기본_속성_접근_가능")
    func basicProperties_accessible() {
        let info = SSHHostInfo(
            host: "myserver",
            hostname: "192.168.1.1",
            user: "admin",
            port: "22",
            identityFile: "~/.ssh/id_rsa"
        )
        #expect(info.host == "myserver")
        #expect(info.hostname == "192.168.1.1")
        #expect(info.user == "admin")
        #expect(info.port == "22")
        #expect(info.identityFile == "~/.ssh/id_rsa")
    }

    @Test("각_인스턴스_고유한_UUID_보유")
    func eachInstance_hasUniqueId() {
        let a = SSHHostInfo(host: "a", hostname: "1.2.3.4", user: "", port: "22", identityFile: "")
        let b = SSHHostInfo(host: "a", hostname: "1.2.3.4", user: "", port: "22", identityFile: "")
        #expect(a.id != b.id)
    }

    @Test("빈문자열_사용자_및_identityFile_허용")
    func emptyUserAndIdentityFile_allowed() {
        let info = SSHHostInfo(host: "host", hostname: "host.example.com", user: "", port: "22", identityFile: "")
        #expect(info.user == "")
        #expect(info.identityFile == "")
    }
}

// MARK: - SSH Config 파싱 테스트

@Suite("SSHPanelView.parseSSHConfigContent - 파싱")
struct SSHConfigParsingTests {

    // MARK: 정상 경로

    @Test("단일_호스트_모든_필드_파싱")
    func singleHost_allFields_parsed() {
        let config = """
        Host myserver
            HostName 192.168.1.100
            User deploy
            Port 2222
            IdentityFile ~/.ssh/deploy_key
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        let h = hosts[0]
        #expect(h.host == "myserver")
        #expect(h.hostname == "192.168.1.100")
        #expect(h.user == "deploy")
        #expect(h.port == "2222")
        #expect(h.identityFile == "~/.ssh/deploy_key")
    }

    @Test("다중_호스트_모두_파싱")
    func multipleHosts_allParsed() {
        let config = """
        Host alpha
            HostName 10.0.0.1
            User alice
        Host beta
            HostName 10.0.0.2
            User bob
        Host gamma
            HostName 10.0.0.3
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 3)
        #expect(hosts[0].host == "alpha")
        #expect(hosts[1].host == "beta")
        #expect(hosts[2].host == "gamma")
    }

    @Test("HostName_없으면_host값을_hostname으로_사용")
    func missingHostName_fallsBackToHostAlias() {
        let config = """
        Host myalias
            User ubuntu
            Port 22
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].hostname == "myalias")
    }

    @Test("User_없으면_빈문자열_기본값")
    func missingUser_defaultsToEmptyString() {
        let config = """
        Host server
            HostName server.example.com
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].user == "")
    }

    @Test("Port_없으면_22_기본값")
    func missingPort_defaultsTo22() {
        let config = """
        Host server
            HostName server.example.com
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].port == "22")
    }

    @Test("IdentityFile_없으면_빈문자열_기본값")
    func missingIdentityFile_defaultsToEmptyString() {
        let config = """
        Host server
            HostName server.example.com
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].identityFile == "")
    }

    // MARK: 와일드카드 스킵

    @Test("와일드카드_호스트_별표만_건너뜀")
    func wildcardHost_asteriskOnly_skipped() {
        let config = """
        Host *
            ServerAliveInterval 60
        Host real
            HostName 1.2.3.4
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].host == "real")
    }

    @Test("와일드카드_포함_패턴_건너뜀")
    func wildcardHost_patternWithAsterisk_skipped() {
        let config = """
        Host *.example.com
            User git
        Host concrete
            HostName concrete.example.com
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].host == "concrete")
    }

    // MARK: 공백 및 탭 처리

    @Test("탭_들여쓰기_정상_파싱")
    func tabIndentation_parsedCorrectly() {
        let config = "Host tabserver\n\tHostName 10.10.10.10\n\tUser root\n\tPort 22\n"
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].hostname == "10.10.10.10")
        #expect(hosts[0].user == "root")
    }

    @Test("혼합_공백_탭_들여쓰기_정상_파싱")
    func mixedWhitespaceIndentation_parsedCorrectly() {
        let config = "Host mixedserver\n  \t  HostName mixed.example.com\n"
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].hostname == "mixed.example.com")
    }

    @Test("키워드_대소문자_구분_없이_파싱")
    func keywords_caseInsensitive_parsed() {
        let config = """
        HOST myserver
            HOSTNAME 1.2.3.4
            USER admin
            PORT 2222
            IDENTITYFILE ~/.ssh/key
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].hostname == "1.2.3.4")
        #expect(hosts[0].user == "admin")
        #expect(hosts[0].port == "2222")
        #expect(hosts[0].identityFile == "~/.ssh/key")
    }

    // MARK: 주석 처리

    @Test("주석_라인_무시")
    func commentLines_ignored() {
        let config = """
        # 이것은 주석입니다
        Host server
            # 인라인 주석
            HostName server.example.com
            User admin
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].host == "server")
    }

    @Test("빈_라인_무시")
    func emptyLines_ignored() {
        let config = "\n\nHost server\n\n    HostName 1.2.3.4\n\n"
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
    }

    // MARK: 경계값

    @Test("빈_설정_파일_빈배열_반환")
    func emptyConfig_returnsEmptyArray() {
        let hosts = SSHPanelView.parseSSHConfigContent("")
        #expect(hosts.isEmpty)
    }

    @Test("주석만_있는_설정_빈배열_반환")
    func onlyComments_returnsEmptyArray() {
        let config = "# nothing here\n# just comments\n"
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.isEmpty)
    }

    @Test("Host_블록_없이_나타나는_지시어_무시")
    func directivesWithoutHostBlock_ignored() {
        let config = """
        ServerAliveInterval 60
        ServerAliveCountMax 3
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.isEmpty)
    }

    @Test("마지막_호스트_블록_정상_플러시")
    func lastHostBlock_properlyFlushed() {
        let config = """
        Host first
            HostName 1.1.1.1
        Host last
            HostName 9.9.9.9
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 2)
        #expect(hosts[1].host == "last")
        #expect(hosts[1].hostname == "9.9.9.9")
    }

    @Test("identityFile_공백_포함_경로_보존")
    func identityFile_pathWithSpaces_preserved() {
        let config = "Host server\n    HostName 1.2.3.4\n    IdentityFile /Users/my user/my key\n"
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].identityFile == "/Users/my user/my key")
    }

    @Test("호스트_순서_유지")
    func hostOrder_preserved() {
        let config = """
        Host z-server
            HostName z.example.com
        Host a-server
            HostName a.example.com
        Host m-server
            HostName m.example.com
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 3)
        #expect(hosts[0].host == "z-server")
        #expect(hosts[1].host == "a-server")
        #expect(hosts[2].host == "m-server")
    }
}

// MARK: - 네거티브 테스트

@Suite("SSHPanelView.parseSSHConfigContent - 네거티브 테스트")
struct SSHConfigParsingNegativeTests {

    @Test("잘못된_형식_단독_키워드만_있는_라인_무시")
    func malformedLine_singleKeywordOnly_ignored() {
        let config = """
        Host
        Host validserver
            HostName 1.2.3.4
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        // 값 없는 단독 "Host" 라인은 무시되고 유효한 호스트만 파싱됨
        #expect(hosts.count == 1)
        #expect(hosts[0].host == "validserver")
    }

    @Test("와일드카드만_있는_설정_빈배열_반환")
    func onlyWildcardHosts_returnsEmpty() {
        let config = """
        Host *
            ServerAliveInterval 30
            User default
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.isEmpty)
    }

    @Test("알수없는_키워드_무시하고_나머지_파싱")
    func unknownKeywords_ignoredAndRestParsed() {
        let config = """
        Host server
            HostName server.example.com
            UnknownDirective some_value
            AnotherUnknown foo bar
            User admin
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].user == "admin")
    }

    @Test("Host_없이_HostName_지정시_독립_호스트_생성안됨")
    func hostnameWithoutHost_doesNotCreateHost() {
        let config = """
        HostName orphan.example.com
        User orphan
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.isEmpty)
    }

    @Test("공백만_있는_설정_빈배열_반환")
    func whitespaceOnlyConfig_returnsEmptyArray() {
        let config = "   \n\t\n   \t   \n"
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.isEmpty)
    }

    @Test("다중_와일드카드_패턴_모두_건너뜀")
    func multipleWildcardPatterns_allSkipped() {
        let config = """
        Host *.internal
            User ops
        Host bastion.*
            User bastion
        Host *
            ServerAliveInterval 60
        Host concrete
            HostName 10.0.0.1
        """
        let hosts = SSHPanelView.parseSSHConfigContent(config)
        #expect(hosts.count == 1)
        #expect(hosts[0].host == "concrete")
    }
}

// MARK: - 퍼징 테스트

@Suite("SSHPanelView.parseSSHConfigContent - 퍼징 테스트")
struct SSHConfigParsingFuzzTests {

    @Test("임의_바이너리_유사_문자열_크래시_없음")
    func randomBinaryLikeString_doesNotCrash() {
        let inputs: [String] = [
            "\u{0000}\u{0001}\u{0002}",
            "\u{FFFE}\u{FFFF}",
            String(repeating: "\u{00}", count: 100),
            "\r\n\r\n\r\n",
            "\t\t\t\t",
        ]
        for input in inputs {
            let result = SSHPanelView.parseSSHConfigContent(input)
            // 크래시 없이 배열 반환 여부만 확인
            #expect(result.count >= 0)
        }
    }

    @Test("매우_긴_입력_크래시_없음")
    func veryLongInput_doesNotCrash() {
        let longHostName = String(repeating: "a", count: 10_000)
        let config = "Host \(longHostName)\n    HostName 1.2.3.4\n"
        let result = SSHPanelView.parseSSHConfigContent(config)
        #expect(result.count == 1)
        #expect(result[0].host == longHostName)
    }

    @Test("수천개_호스트_블록_크래시_없음")
    func thousandsOfHostBlocks_doesNotCrash() {
        var lines: [String] = []
        for i in 0..<1_000 {
            lines.append("Host server\(i)")
            lines.append("    HostName \(i).0.0.1")
        }
        let config = lines.joined(separator: "\n")
        let result = SSHPanelView.parseSSHConfigContent(config)
        #expect(result.count == 1_000)
    }

    @Test("유니코드_호스트명_크래시_없음")
    func unicodeHostNames_doesNotCrash() {
        let config = """
        Host 서버일호
            HostName 192.168.0.1
        Host αβγδ
            HostName 192.168.0.2
        Host 🚀rocket
            HostName 192.168.0.3
        """
        let result = SSHPanelView.parseSSHConfigContent(config)
        #expect(result.count == 3)
        #expect(result[0].host == "서버일호")
    }

    @Test("특수문자_포함_값들_크래시_없음")
    func specialCharacterValues_doesNotCrash() {
        let specialChars = ["<>\"'&;|`$\\", "!@#%^(){}[]", "/path/with/../dots"]
        for chars in specialChars {
            let config = "Host testhost\n    HostName \(chars)\n    User \(chars)\n"
            let result = SSHPanelView.parseSSHConfigContent(config)
            #expect(result.count >= 0)
        }
    }

    @Test("변이_기반_유효설정_변형_크래시_없음")
    func mutationBased_validConfigVariants_doNotCrash() {
        let baseConfig = "Host server\n    HostName 1.2.3.4\n    User admin\n    Port 22\n"
        // 다양한 변이를 시도
        let mutations: [String] = [
            baseConfig.replacingOccurrences(of: "Host", with: "host"),
            baseConfig.replacingOccurrences(of: "HostName", with: "HOSTNAME"),
            baseConfig.replacingOccurrences(of: "\n", with: "\r\n"),
            baseConfig.replacingOccurrences(of: "    ", with: "\t"),
            baseConfig + baseConfig,                         // 중복
            String(baseConfig.reversed()),                   // 완전 역순
            baseConfig.replacingOccurrences(of: "22", with: ""),  // 빈 포트
        ]
        for mutated in mutations {
            let result = SSHPanelView.parseSSHConfigContent(mutated)
            #expect(result.count >= 0)
        }
    }

    @Test("속성기반_호스트수_파싱결과_불변조건")
    func propertyBased_parsedHostCount_neverExceedsHostDirectiveCount() {
        let configs: [String] = [
            "",
            "Host a\n    HostName 1.1.1.1\n",
            "Host a\nHost b\nHost c\n",
            "Host *\nHost a\nHost *.wild\nHost b\n",
        ]
        for config in configs {
            let hostDirectiveCount = config
                .components(separatedBy: .newlines)
                .filter { $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("host ") }
                .count
            let result = SSHPanelView.parseSSHConfigContent(config)
            // 파싱된 호스트 수는 Host 지시어 수를 초과할 수 없음
            #expect(result.count <= hostDirectiveCount)
        }
    }
}
