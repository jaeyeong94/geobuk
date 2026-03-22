# Geobuk (거북)

**A macOS-native terminal built for Claude Code**

> Slow but steady. Like a turtle. (느리지만 단단하게. 거북이처럼.)

![geobuk screenshot](assets/screenshot.png)

<!-- additional image slots:
![sidebar](assets/sidebar.png)
![block input](assets/block-input.png)
![split panes](assets/split-panes.png)
![claude monitor](assets/claude-monitor.png)
![completion list](assets/completion-list.png)
-->

---

Everything you need when working with Claude Code agents — session monitoring, token/cost tracking, multi-workspace, split panes — packed into a single terminal app. Uses [Ghostty](https://ghostty.org)'s libghostty as the terminal engine and SwiftUI for the UI. 76 Swift files, ~16,000 lines. Zero external package dependencies.

Warp-style block input, command auto-completion, and shell state tracking are built in. When you run a Claude Code session, the sidebar shows the model, token usage, cost, and execution phase in real-time.

(Claude Code 에이전트 작업에 필요한 모든 것 — 세션 모니터링, 토큰/비용 추적, 멀티 워크스페이스, 분할 패널 — 을 하나의 터미널 앱에 담았다.)

## features

**terminal (터미널)**
- Metal-based GPU rendering via libghostty
- Korean IME support (한글 preedit composition)
- Full VT100/ANSI compatibility

**block input (블록 입력)**
- Warp-style bottom input bar — commands and output are visually separated into blocks
- File path / history / command auto-completion (inline hints + suggestion list)
- CWD-based file name completion — type `Web` in `~/WebstormProjects` and get a hint

**workspaces & panes (워크스페이스 & 패널)**
- Multiple workspaces (`Cmd+T`, `Cmd+1~9`)
- Horizontal / vertical splits (`Cmd+D`, `Cmd+Shift+D`)
- Directional pane navigation (`Cmd+Option+↑↓←→`)
- Pane maximize toggle (`Cmd+Shift+Enter`)
- Per-pane CWD saved and restored on restart (session persistence)

**right sidebar panels (우측 사이드바 패널)**
- 10 tabbed panels accessible via `Ctrl+0~9`:
  - **Processes** (`Ctrl+1`) — per-pane process tree and listening ports
  - **System** (`Ctrl+2`) — CPU cores heatmap, GPU usage, RAM/Swap bars, disk I/O, network bubbles
  - **Git** (`Ctrl+3`) — branch name, staged/unstaged changes, PRs, branch graph, GitHub Actions status
  - **Scripts** (`Ctrl+4`) — runnable entries from `package.json`, `Makefile`, `Cargo.toml`, `go.mod`, Python scripts
  - **Docker** (`Ctrl+5`) — container and image overview
  - **SSH** (`Ctrl+6`) — SSH host list from `~/.ssh/config`
  - **Snippets** (`Ctrl+7`) — saved command snippets
  - **Claude** (`Ctrl+8`) — Claude Code timeline and config viewer
  - **Environment** (`Ctrl+9`) — environment variables for the active pane
  - **Notifications** (`Ctrl+0`) — notification history panel
- Toggle the panel open/closed: `Cmd+Shift+B`

**notifications (알림)**
- macOS desktop notifications for Claude session events
- In-app notification ring — colored border animation around the window
- Dock badge showing unread count
- Sidebar badge on the Notifications tab icon
- Notification panel with full history

**custom title bar (커스텀 타이틀 바)**
- JetBrains-style title bar: app info centered, action icons on the right
- Implemented via `NSTitlebarAccessoryViewController` with `.hiddenTitleBar` window style

**claude code integration (Claude Code 통합)**
- Watches `~/.claude/sessions/` to auto-detect active sessions — no config needed
- Shows model name, token usage, cost (USD), and execution phase in sidebar & title bar
- Fetches live pricing from [platform.claude.com](https://platform.claude.com)
- `Cmd+Shift+C` to start a new Claude session

**system monitoring (시스템 모니터링)**
- CPU / memory / network I/O in the left sidebar
- Detailed system panel in the right sidebar (CPU core heatmap, GPU, RAM/Swap bars, disk, network)

## install

### requirements (요구사항)

| | version |
|------|------|
| macOS | 14.0+ (Sonoma) |
| Xcode | 16.0+ |
| Swift | 6.0 |
| Zig | 0.15.2+ |
| xcodegen | latest |

### setup

```bash
# install zig and xcodegen (Homebrew)
brew install zig xcodegen

# clone with submodules
git clone --recursive https://github.com/jaeyeong94/geobuk.git
cd geobuk

# generate Xcode project
xcodegen generate

# build (libghostty builds automatically — first build takes 5-10 min)
xcodebuild -scheme Geobuk -configuration Debug build

# or open in Xcode
open Geobuk.xcodeproj
```

> **Note**: On first build, `Scripts/build-libghostty.sh` compiles libghostty with Zig. Subsequent builds use the cached `.a` file and are fast.
>
> (첫 빌드 시 Zig로 libghostty를 컴파일한다. 이후에는 캐시된 파일을 사용하므로 빠르다.)

### missing submodule?

```bash
git submodule update --init --recursive
```

## quick start

1. **`Cmd+R` in Xcode** — a terminal pane opens
2. **Type a command** — use the block input bar at the bottom. `Tab` to auto-complete, `Enter` to run
3. **Split panes** — `Cmd+D` for left/right, `Cmd+Shift+D` for top/bottom

### using claude code

```bash
# run Claude Code in a pane
claude

# or Cmd+Shift+C to start a new session (auto stream-json mode)
```

Open the sidebar (`Cmd+B`) to see Claude session status:
- Model (opus, sonnet, etc.)
- Token usage (input/output)
- Cumulative cost (USD)
- Current phase (thinking, coding, idle, etc.)

Open the right panel (`Cmd+Shift+B` or `Ctrl+8`) for the Claude timeline and config.

## claude integration

Geobuk watches Claude Code's session files (`~/.claude/sessions/*.json`) to auto-detect active sessions. No configuration or Claude Code modification required.

(Geobuk은 Claude Code의 세션 파일을 감시하여 활성 세션을 자동 감지한다. 별도 설정이나 Claude Code 수정 불필요.)

```
┌─ Left Sidebar ─────────────┐     ┌─ Right Panel (Ctrl+8) ─────┐
│ Workspaces                 │     │ Claude Timeline            │
│  ▼ Workspace 1             │     │  opus · coding             │
│    1. zsh ~/project        │     │  12.4K tokens · $0.42      │
│    2. claude (coding)      │     │  ~/WebstormProjects/geobuk  │
│                            │     │                            │
│ Claude Sessions            │     │ Claude Config              │
│  opus · coding             │     │  model, max tokens, etc.   │
│  12.4K tokens · $0.42      │     └────────────────────────────┘
│  ~/WebstormProjects/geobuk │
│                            │
│ System                     │
│  CPU 23% · MEM 14.2/32 GB │
│  NET ↓ 1.2 MB/s ↑ 0.3 MB/s│
└────────────────────────────┘
```

Pricing data is fetched from `platform.claude.com` via HTML parsing and cached at `~/Library/Application Support/Geobuk/pricing.json`.

## shell integration

Geobuk auto-loads an integration script into zsh. This script reports shell state (idle / running) to the app, enabling block input mode switching and command completion detection.

(Geobuk은 zsh에 통합 스크립트를 자동 로드하여 셸 상태를 앱에 보고한다.)

**how it works:**
1. On terminal creation, `ZDOTDIR` env var loads a custom `.zshrc`
2. `precmd`/`preexec` zsh hooks send JSON-RPC messages over a Unix socket
3. The app receives messages and switches between block input ↔ TUI mode

**socket path:** `~/Library/Application Support/Geobuk/geobuk.sock`

The integration loads after your existing `.zshrc`, so it won't conflict with your current setup.

## project structure

```
geobuk/
├── Geobuk/
│   ├── App/                    # entry point, ContentView, AppDelegate, AppState
│   ├── Features/
│   │   ├── Terminal/           # GhosttyApp, SurfaceView, Metal rendering
│   │   ├── Splits/             # split tree, pane views
│   │   ├── Claude/             # session monitor, pricing, file watcher
│   │   ├── UI/                 # block input, settings, right panel views
│   │   │   └── Components/     # reusable UI components (CollapsibleSectionView, …)
│   │   ├── Notification/       # NotificationCoordinator (desktop, ring, badge)
│   │   ├── Workspace/          # workspace manager, persistence
│   │   ├── Session/            # shell state manager
│   │   ├── Sidebar/            # left sidebar view
│   │   ├── Process/            # process tree scanner, port watcher
│   │   ├── Browser/            # in-app browser
│   │   └── API/                # socket server, JSON-RPC
│   ├── Shared/                 # logger, system monitor, completion provider,
│   │                           #   AppPath, ProcessRunner, GitRunner,
│   │                           #   ColorHelpers, ClaudeConfigReader,
│   │                           #   NonDraggableButtonArea, RingBuffer, …
│   ├── Protocols/              # abstraction interfaces
│   └── Resources/              # config, shell scripts, entitlements
├── GeobukTests/                # 13 test files, ~43 unit tests
├── Scripts/                    # libghostty build script
├── Vendor/ghostty/             # libghostty submodule
└── project.yml                 # xcodegen config
```

## configuration

### terminal defaults

`Geobuk/Resources/geobuk-default.conf`:

```
cursor-style = bar
cursor-style-blink = true
window-padding-x = 8
window-padding-y = 4
```

Your `~/.config/ghostty/config` is loaded first, then these defaults are applied on top.

### runtime settings (런타임 설정)

Open settings with `Cmd+,`:
- Font family (Korean recommendations: D2Coding, Pretendard, Sarasa Gothic)
- Font size (`Cmd++`, `Cmd+-`, `Cmd+0`)
- Line height, padding

## development

### build

```bash
xcodegen generate
xcodebuild -scheme Geobuk -configuration Debug build
```

### test

```bash
xcodebuild test -scheme Geobuk GENERATE_INFOPLIST_FILE=YES
```

Unit + negative + fuzz tests. Developed with TDD.

### logs

```bash
tail -f ~/Library/Application\ Support/Geobuk/geobuk.log
```

Tagged by component (`[Terminal]`, `[Claude]`, `[Shell]`, `[Socket]`, etc.). Auto-rotated at 5 MB.

## architecture

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
                               │ Shell Integration│
                               │ · Unix Socket    │
                               │ · zsh hooks      │
                               │ · JSON-RPC       │
                               └─────────────────┘
```

- **libghostty** — Ghostty's terminal engine. Called from Swift via C API. GPU rendering with Metal.
- **SplitTree** — Recursive immutable value type. Supports split/merge/directional navigation.
- **Socket Server** — Bidirectional shell ↔ app communication over Unix domain socket.
- **NotificationCoordinator** — Unified notification hub: macOS `UNUserNotificationCenter`, in-app colored ring border, Dock badge, and sidebar unread count.

## keyboard shortcuts

### workspaces

| shortcut | action |
|----------|--------|
| `Cmd+T` | new workspace |
| `Cmd+Option+W` | close workspace |
| `Cmd+1` ~ `Cmd+9` | switch workspace |

### panes

| shortcut | action |
|----------|--------|
| `Cmd+D` | split horizontal (left/right) |
| `Cmd+Shift+D` | split vertical (top/bottom) |
| `Cmd+W` | close pane |
| `Cmd+Shift+Enter` | toggle maximize |
| `Cmd+Option+↑↓←→` | directional focus |

### view

| shortcut | action |
|----------|--------|
| `Cmd+B` | toggle left sidebar |
| `Cmd+Shift+B` | toggle right panel |
| `Cmd+,` | settings |

### font

| shortcut | action |
|----------|--------|
| `Cmd++` | increase font size |
| `Cmd+-` | decrease font size |
| `Cmd+0` | reset font size |

### claude

| shortcut | action |
|----------|--------|
| `Cmd+Shift+C` | new Claude session |

### right panel tabs

| shortcut | panel |
|----------|-------|
| `Ctrl+1` | Processes |
| `Ctrl+2` | System |
| `Ctrl+3` | Git |
| `Ctrl+4` | Scripts |
| `Ctrl+5` | Docker |
| `Ctrl+6` | SSH |
| `Ctrl+7` | Snippets |
| `Ctrl+8` | Claude Timeline + Config |
| `Ctrl+9` | Environment |
| `Ctrl+0` | Notifications |

Pressing the same `Ctrl+N` shortcut again while that tab is active closes the panel.

## license

MIT
