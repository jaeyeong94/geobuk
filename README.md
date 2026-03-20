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

Everything you need when working with Claude Code agents — session monitoring, token/cost tracking, multi-workspace, split panes — packed into a single terminal app. Uses [Ghostty](https://ghostty.org)'s libghostty as the terminal engine and SwiftUI for the UI. 90 Swift files, ~16,000 lines. Zero external package dependencies.

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
- Auto-save / restore session layout (every 30 seconds)

**claude code integration (Claude Code 통합)**
- Watches `~/.claude/sessions/` to auto-detect active sessions — no config needed
- Shows model name, token usage, cost (USD), and execution phase in sidebar & title bar
- Fetches live pricing from [platform.claude.com](https://platform.claude.com)
- `Cmd+Shift+C` to start a new Claude session

**system monitoring (시스템 모니터링)**
- CPU / memory / network I/O in the sidebar
- Per-pane process list and listening port tracking

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

## claude integration

Geobuk watches Claude Code's session files (`~/.claude/sessions/*.json`) to auto-detect active sessions. No configuration or Claude Code modification required.

(Geobuk은 Claude Code의 세션 파일을 감시하여 활성 세션을 자동 감지한다. 별도 설정이나 Claude Code 수정 불필요.)

```
┌─ Sidebar ──────────────────┐
│ Workspaces                 │
│  ▼ Workspace 1             │
│    1. zsh ~/project        │
│    2. claude (coding)      │
│                            │
│ Claude Sessions            │
│  opus · coding             │
│  12.4K tokens · $0.42      │
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
│   ├── App/                    # entry point, ContentView
│   ├── Features/
│   │   ├── Terminal/           # GhosttyApp, SurfaceView, Metal rendering
│   │   ├── Splits/             # split tree, pane views
│   │   ├── Claude/             # session monitor, pricing, file watcher
│   │   ├── UI/                 # block input, settings, completion hints
│   │   ├── Workspace/          # workspace manager, persistence
│   │   ├── Session/            # shell state manager
│   │   ├── Sidebar/            # sidebar view
│   │   ├── Process/            # process tree scanner
│   │   └── API/                # socket server, JSON-RPC
│   ├── Shared/                 # logger, system monitor, completion provider
│   ├── Protocols/              # abstraction interfaces
│   └── Resources/              # config, shell scripts, entitlements
├── GeobukTests/                # 77 unit tests
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

77 tests (unit + negative + fuzz). Developed with TDD.

### logs

```bash
tail -f ~/Library/Application\ Support/Geobuk/geobuk.log
```

Tagged by component (`[Terminal]`, `[Claude]`, `[Shell]`, `[Socket]`, etc.). Auto-rotated at 5 MB.

## architecture

```
┌──────────────────────────────────────────────────┐
│                     SwiftUI                      │
│  ContentView → WorkspaceManager → SplitTree      │
│       ↓              ↓              ↓            │
│  SidebarView    BlockInputBar   SplitPaneView    │
└──────┬───────────────┬──────────────┬────────────┘
       │               │              │
┌──────┴───────┐ ┌─────┴─────┐ ┌─────┴──────────┐
│ Claude       │ │ Completion│ │ Terminal        │
│ Monitor      │ │ Provider  │ │ (libghostty)    │
│ · FileWatcher│ │ · File    │ │ · Metal render  │
│ · Pricing    │ │ · History │ │ · PTY mgmt      │
│ · Transcript │ │ · Command │ │ · Keyboard/IME  │
└──────────────┘ └───────────┘ └────────┬────────┘
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
| `Cmd+B` | toggle sidebar |
| `Cmd+,` | settings |
| `Cmd++` / `Cmd+-` / `Cmd+0` | font size |

### claude

| shortcut | action |
|----------|--------|
| `Cmd+Shift+C` | new Claude session |

## license

MIT
