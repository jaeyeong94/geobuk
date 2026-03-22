# Geobuk Keyboard Shortcuts

## Workspaces

| Shortcut | Action |
|----------|--------|
| `Cmd + T` | New Workspace |
| `Cmd + Option + W` | Close Workspace |
| `Cmd + 1` ~ `Cmd + 9` | Switch to Workspace by Number |

## Pane

| Shortcut | Action |
|----------|--------|
| `Cmd + D` | Split Horizontally (Left/Right) |
| `Cmd + Shift + D` | Split Vertically (Top/Bottom) |
| `Cmd + W` | Close Focused Pane |
| `Cmd + Shift + Enter` | Toggle Maximize Pane |

## Pane Navigation

| Shortcut | Action |
|----------|--------|
| `Cmd + Option + ←` | Focus Left Pane |
| `Cmd + Option + →` | Focus Right Pane |
| `Cmd + Option + ↑` | Focus Pane Above |
| `Cmd + Option + ↓` | Focus Pane Below |

## View

| Shortcut | Action |
|----------|--------|
| `Cmd + B` | Toggle Left Sidebar |
| `Cmd + Shift + B` | Toggle Right Panel |
| `Cmd + ,` | Terminal Settings (Font, Padding, Line Height) |

## Font Size

| Shortcut | Action |
|----------|--------|
| `Cmd + +` | Increase Font Size |
| `Cmd + -` | Decrease Font Size |
| `Cmd + 0` | Reset Font Size |

## Claude Code

| Shortcut | Action |
|----------|--------|
| `Cmd + Shift + C` | New Claude Session (`claude --output-format stream-json`) |

## Right Panel (우측 패널 탭)

Pressing the active tab's shortcut again closes the panel.
(활성 탭의 단축키를 다시 누르면 패널이 닫힌다.)

| Shortcut | Panel |
|----------|-------|
| `Ctrl + 1` | Processes — per-pane process tree and listening ports |
| `Ctrl + 2` | System — CPU core heatmap, GPU, RAM/Swap bars, disk, network bubbles |
| `Ctrl + 3` | Git — branch, changes, PRs, branch graph, GitHub Actions |
| `Ctrl + 4` | Scripts — package.json, Makefile, Cargo, Go, Python scripts |
| `Ctrl + 5` | Docker — containers and images |
| `Ctrl + 6` | SSH — hosts from `~/.ssh/config` |
| `Ctrl + 7` | Snippets — saved command snippets |
| `Ctrl + 8` | Claude — Timeline and Config |
| `Ctrl + 9` | Environment — env vars for active pane |
| `Ctrl + 0` | Notifications — notification history |

## Terminal

| Shortcut | Action |
|----------|--------|
| Type normally | Text input to shell |
| Arrow keys | Cursor movement |
| `Cmd + C` | Copy (when text selected) |
| `Cmd + V` | Paste |
| Korean IME | Supported (preedit composition) |

## Notes

- Pane navigation is **directional** — it follows the spatial layout, not linear order.
- When only one pane remains, `Cmd + W` quits the app.
- Workspace names auto-increment: Workspace 1, 2, 3...
- Session layout (pane splits + CWD per pane) is auto-saved and restored on app restart.
- Right panel tab shortcuts open the panel if closed, or close it if the same tab is already active.
