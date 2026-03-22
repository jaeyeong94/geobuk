<p align="center">
  <a href="../README.md">English</a> |
  <a href="README.ko.md">한국어</a> |
  <a href="README.ja.md">日本語</a> |
  <a href="README.zh.md">中文</a>
</p>

# Geobuk (거북)

**Claude Code를 위한 macOS 네이티브 터미널**

> 느리지만 단단하게. 거북이처럼.

![geobuk 스크린샷](../assets/screenshot.png)

---

Claude Code 에이전트 작업에 필요한 모든 것 — 세션 모니터링, 토큰/비용 추적, 멀티 워크스페이스, 분할 패널 — 을 하나의 터미널 앱에 담았다. [Ghostty](https://ghostty.org)의 libghostty를 터미널 엔진으로 사용하고, SwiftUI로 UI를 구성한다. Swift 파일 76개, 약 16,000줄. 외부 패키지 의존성 없음.

Warp 스타일 블록 입력, 명령어 자동 완성, 셸 상태 추적이 기본 탑재되어 있다. Claude Code 세션을 실행하면 사이드바에서 모델명, 토큰 사용량, 비용, 실행 단계를 실시간으로 확인할 수 있다.

## 기능

**터미널**
- libghostty를 통한 Metal 기반 GPU 렌더링
- 한글 IME 지원 (preedit 조합 입력)
- 완전한 VT100/ANSI 호환

**블록 입력**
- Warp 스타일 하단 입력 바 — 명령어와 출력이 블록으로 시각적으로 분리됨
- 파일 경로 / 히스토리 / 명령어 자동 완성 (인라인 힌트 + 제안 목록)
- CWD 기반 파일 이름 완성 — `~/WebstormProjects`에서 `Web`을 입력하면 힌트 제공

**워크스페이스 & 패널**
- 멀티 워크스페이스 (`Cmd+T`, `Cmd+1~9`)
- 좌우/상하 분할 (`Cmd+D`, `Cmd+Shift+D`)
- 방향키 패널 탐색 (`Cmd+Option+↑↓←→`)
- 패널 최대화 토글 (`Cmd+Shift+Enter`)
- 패널별 CWD 저장 및 재시작 시 복원 (세션 지속성)

**우측 사이드바 패널**
- `Ctrl+0~9`로 접근 가능한 10개의 탭 패널:
  - **프로세스** (`Ctrl+1`) — 패널별 프로세스 트리 및 리스닝 포트
  - **시스템** (`Ctrl+2`) — CPU 코어 히트맵, GPU 사용량, RAM/Swap 바, 디스크 I/O, 네트워크 버블
  - **Git** (`Ctrl+3`) — 브랜치, staged/unstaged 변경, PR, 브랜치 그래프, GitHub Actions 상태
  - **스크립트** (`Ctrl+4`) — `package.json`, `Makefile`, `Cargo.toml`, `go.mod`, Python 스크립트의 실행 가능 항목
  - **Docker** (`Ctrl+5`) — 컨테이너 및 이미지 개요
  - **SSH** (`Ctrl+6`) — `~/.ssh/config`의 SSH 호스트 목록
  - **스니펫** (`Ctrl+7`) — 저장된 명령어 스니펫
  - **Claude** (`Ctrl+8`) — Claude Code 타임라인 및 설정 뷰어
  - **환경 변수** (`Ctrl+9`) — 활성 패널의 환경 변수
  - **알림** (`Ctrl+0`) — 알림 히스토리 패널
- 패널 열기/닫기 토글: `Cmd+Shift+B`

**알림**
- Claude 세션 이벤트에 대한 macOS 데스크톱 알림
- 앱 내 알림 링 — 윈도우 테두리 색상 애니메이션
- 미읽음 개수를 표시하는 Dock 배지
- 알림 탭 아이콘의 사이드바 배지
- 전체 히스토리가 있는 알림 패널

**커스텀 타이틀 바**
- JetBrains 스타일 타이틀 바: 앱 정보는 가운데, 액션 아이콘은 오른쪽
- `.hiddenTitleBar` 윈도우 스타일에서 `NSTitlebarAccessoryViewController`로 구현

**Claude Code 통합**
- `~/.claude/sessions/` 감시로 활성 세션 자동 감지 — 별도 설정 불필요
- 사이드바 및 타이틀 바에서 모델명, 토큰 사용량, 비용(USD), 실행 단계 표시
- [platform.claude.com](https://platform.claude.com)에서 실시간 가격 정보 fetch
- `Cmd+Shift+C`로 새 Claude 세션 시작

**시스템 모니터링**
- 왼쪽 사이드바에서 CPU / 메모리 / 네트워크 I/O 확인
- 오른쪽 사이드바 시스템 패널에서 상세 정보 확인 (CPU 코어 히트맵, GPU, RAM/Swap 바, 디스크, 네트워크)

## 설치

### 요구사항

| | 버전 |
|------|------|
| macOS | 14.0+ (Sonoma) |
| Xcode | 16.0+ |
| Swift | 6.0 |
| Zig | 0.15.2+ |
| xcodegen | latest |

### 설정

```bash
# zig와 xcodegen 설치 (Homebrew)
brew install zig xcodegen

# 서브모듈 포함 클론
git clone --recursive https://github.com/jaeyeong94/geobuk.git
cd geobuk

# Xcode 프로젝트 생성
xcodegen generate

# 빌드 (libghostty가 자동 빌드됨 — 첫 빌드는 5~10분 소요)
xcodebuild -scheme Geobuk -configuration Debug build

# 또는 Xcode에서 열기
open Geobuk.xcodeproj
```

> **참고**: 첫 빌드 시 `Scripts/build-libghostty.sh`가 Zig로 libghostty를 컴파일한다. 이후에는 캐시된 `.a` 파일을 사용하므로 빠르다.

### 서브모듈 누락?

```bash
git submodule update --init --recursive
```

## 빠른 시작

1. **Xcode에서 `Cmd+R`** — 터미널 패널이 열린다
2. **명령어 입력** — 하단 블록 입력 바 사용. `Tab`으로 자동 완성, `Enter`로 실행
3. **패널 분할** — `Cmd+D`로 좌우 분할, `Cmd+Shift+D`로 상하 분할

### Claude Code 사용하기

```bash
# 패널에서 Claude Code 실행
claude

# 또는 Cmd+Shift+C로 새 세션 시작 (stream-json 모드 자동 적용)
```

사이드바(`Cmd+B`)를 열어 Claude 세션 상태 확인:
- 모델 (opus, sonnet 등)
- 토큰 사용량 (입력/출력)
- 누적 비용 (USD)
- 현재 단계 (thinking, coding, idle 등)

우측 패널(`Cmd+Shift+B` 또는 `Ctrl+8`)에서 Claude 타임라인 및 설정 확인.

## Claude 통합

Geobuk은 Claude Code의 세션 파일(`~/.claude/sessions/*.json`)을 감시하여 활성 세션을 자동 감지한다. 별도 설정이나 Claude Code 수정이 필요 없다.

```
┌─ 왼쪽 사이드바 ──────────────┐     ┌─ 우측 패널 (Ctrl+8) ─────────┐
│ 워크스페이스                  │     │ Claude 타임라인               │
│  ▼ Workspace 1               │     │  opus · coding               │
│    1. zsh ~/project           │     │  12.4K 토큰 · $0.42          │
│    2. claude (coding)         │     │  ~/WebstormProjects/geobuk   │
│                               │     │                              │
│ Claude 세션                   │     │ Claude 설정                  │
│  opus · coding                │     │  model, max tokens 등        │
│  12.4K 토큰 · $0.42           │     └──────────────────────────────┘
│  ~/WebstormProjects/geobuk    │
│                               │
│ 시스템                        │
│  CPU 23% · MEM 14.2/32 GB    │
│  NET ↓ 1.2 MB/s ↑ 0.3 MB/s  │
└───────────────────────────────┘
```

가격 데이터는 `platform.claude.com`에서 HTML 파싱을 통해 fetch되며 `~/Library/Application Support/Geobuk/pricing.json`에 캐시된다.

## 셸 통합

Geobuk은 zsh에 통합 스크립트를 자동 로드한다. 이 스크립트는 셸 상태(idle / 실행 중)를 앱에 보고하여 블록 입력 모드 전환 및 명령 완료 감지를 가능하게 한다.

**동작 방식:**
1. 터미널 생성 시 `ZDOTDIR` 환경 변수로 커스텀 `.zshrc` 로드
2. `precmd`/`preexec` zsh 훅이 Unix 소켓을 통해 JSON-RPC 메시지 전송
3. 앱이 메시지를 수신하여 블록 입력 ↔ TUI 모드로 전환

**소켓 경로:** `~/Library/Application Support/Geobuk/geobuk.sock`

통합 스크립트는 기존 `.zshrc` 이후에 로드되므로 현재 설정과 충돌하지 않는다.

## 프로젝트 구조

```
geobuk/
├── Geobuk/
│   ├── App/                    # 진입점, ContentView, AppDelegate, AppState
│   ├── Features/
│   │   ├── Terminal/           # GhosttyApp, SurfaceView, Metal 렌더링
│   │   ├── Splits/             # 분할 트리, 패널 뷰
│   │   ├── Claude/             # 세션 모니터, 가격, 파일 감시
│   │   ├── UI/                 # 블록 입력, 설정, 우측 패널 뷰
│   │   │   └── Components/     # 재사용 UI 컴포넌트
│   │   ├── Notification/       # NotificationCoordinator
│   │   ├── Workspace/          # 워크스페이스 매니저, 세션 지속성
│   │   ├── Session/            # 셸 상태 매니저
│   │   ├── Sidebar/            # 왼쪽 사이드바 뷰
│   │   ├── Process/            # 프로세스 트리 스캐너, 포트 감시
│   │   ├── Browser/            # 인앱 브라우저
│   │   └── API/                # 소켓 서버, JSON-RPC
│   ├── Shared/                 # 로거, 시스템 모니터, 완성 프로바이더 등
│   ├── Protocols/              # 추상화 인터페이스
│   └── Resources/              # 설정, 셸 스크립트, 엔타이틀먼트
├── GeobukTests/                # 13개 테스트 파일, 약 43개 유닛 테스트
├── Scripts/                    # libghostty 빌드 스크립트
├── Vendor/ghostty/             # libghostty 서브모듈
└── project.yml                 # xcodegen 설정
```

## 설정

### 터미널 기본값

`Geobuk/Resources/geobuk-default.conf`:

```
cursor-style = bar
cursor-style-blink = true
window-padding-x = 8
window-padding-y = 4
```

`~/.config/ghostty/config`가 먼저 로드된 후, 이 기본값이 위에 적용된다.

### 런타임 설정

`Cmd+,`로 설정 열기:
- 폰트 패밀리 (한글 추천: D2Coding, Pretendard, Sarasa Gothic)
- 폰트 크기 (`Cmd++`, `Cmd+-`, `Cmd+0`)
- 줄 간격, 패딩

## 개발

### 빌드

```bash
xcodegen generate
xcodebuild -scheme Geobuk -configuration Debug build
```

### 테스트

```bash
xcodebuild test -scheme Geobuk GENERATE_INFOPLIST_FILE=YES
```

유닛 + 네거티브 + 퍼즈 테스트. TDD로 개발됨.

### 로그

```bash
tail -f ~/Library/Application\ Support/Geobuk/geobuk.log
```

컴포넌트별 태그 (`[Terminal]`, `[Claude]`, `[Shell]`, `[Socket]` 등). 5MB에서 자동 교체.

## 아키텍처

```
┌──────────────────────────────────────────────────────────────┐
│                          SwiftUI                             │
│  ContentView → WorkspaceManager → SplitTree                  │
│       ↓              ↓              ↓              ↓         │
│  SidebarView    BlockInputBar   SplitPaneView  RightSidebar  │
└──────┬───────────────┬──────────────┬──────────────┬─────────┘
       │               │              │              │
┌──────┴───────┐ ┌─────┴─────┐ ┌─────┴──────────┐ ┌┴────────────────┐
│ Claude       │ │ Completion│ │ Terminal        │ │ Notification    │
│ Monitor      │ │ Provider  │ │ (libghostty)    │ │ Coordinator     │
│ · FileWatcher│ │ · File    │ │ · Metal render  │ │ · Desktop notif │
│ · Pricing    │ │ · History │ │ · PTY mgmt      │ │ · Ring animation│
│ · Transcript │ │ · Command │ │ · Keyboard/IME  │ │ · Dock badge    │
└──────────────┘ └───────────┘ └────────┬────────┘ └─────────────────┘
                                        │
                               ┌────────┴────────┐
                               │  셸 통합         │
                               │ · Unix Socket    │
                               │ · zsh hooks      │
                               │ · JSON-RPC       │
                               └─────────────────┘
```

- **libghostty** — Ghostty의 터미널 엔진. C API를 통해 Swift에서 호출. Metal로 GPU 렌더링.
- **SplitTree** — 재귀적 불변 값 타입. 분할/병합/방향 탐색 지원.
- **Socket Server** — Unix 도메인 소켓을 통한 양방향 셸 ↔ 앱 통신.
- **NotificationCoordinator** — 통합 알림 허브: macOS `UNUserNotificationCenter`, 앱 내 색상 링 테두리, Dock 배지, 사이드바 미읽음 카운트.

## 키보드 단축키

### 워크스페이스

| 단축키 | 동작 |
|----------|--------|
| `Cmd+T` | 새 워크스페이스 |
| `Cmd+Option+W` | 워크스페이스 닫기 |
| `Cmd+1` ~ `Cmd+9` | 워크스페이스 전환 |

### 패널

| 단축키 | 동작 |
|----------|--------|
| `Cmd+D` | 좌우 분할 |
| `Cmd+Shift+D` | 상하 분할 |
| `Cmd+W` | 패널 닫기 |
| `Cmd+Shift+Enter` | 최대화 토글 |
| `Cmd+Option+↑↓←→` | 방향 포커스 |

### 보기

| 단축키 | 동작 |
|----------|--------|
| `Cmd+B` | 왼쪽 사이드바 토글 |
| `Cmd+Shift+B` | 우측 패널 토글 |
| `Cmd+,` | 설정 |

### 폰트

| 단축키 | 동작 |
|----------|--------|
| `Cmd++` | 폰트 크기 증가 |
| `Cmd+-` | 폰트 크기 감소 |
| `Cmd+0` | 폰트 크기 초기화 |

### Claude

| 단축키 | 동작 |
|----------|--------|
| `Cmd+Shift+C` | 새 Claude 세션 |

### 우측 패널 탭

| 단축키 | 패널 |
|----------|-------|
| `Ctrl+1` | 프로세스 |
| `Ctrl+2` | 시스템 |
| `Ctrl+3` | Git |
| `Ctrl+4` | 스크립트 |
| `Ctrl+5` | Docker |
| `Ctrl+6` | SSH |
| `Ctrl+7` | 스니펫 |
| `Ctrl+8` | Claude 타임라인 + 설정 |
| `Ctrl+9` | 환경 변수 |
| `Ctrl+0` | 알림 |

같은 `Ctrl+N` 단축키를 해당 탭이 활성화된 상태에서 다시 누르면 패널이 닫힌다.

## 라이선스

MIT
