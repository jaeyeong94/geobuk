<p align="center">
  <a href="../README.md">English</a> |
  <a href="README.ko.md">한국어</a> |
  <a href="README.ja.md">日本語</a> |
  <a href="README.zh.md">中文</a>
</p>

# Geobuk (거북)

**专为 Claude Code 打造的 macOS 原生终端**

> 慢而稳健。如乌龟一般。

![geobuk 截图](../assets/screenshot.png)

---

Claude Code 代理工作所需的一切 — 会话监控、Token/费用追踪、多工作区、分割窗格 — 尽在一个终端应用中。使用 [Ghostty](https://ghostty.org) 的 libghostty 作为终端引擎，SwiftUI 构建界面。76 个 Swift 文件，约 16,000 行代码。零外部包依赖。

内置 Warp 风格块输入、命令自动补全和 Shell 状态追踪。运行 Claude Code 会话时，侧边栏实时显示模型名称、Token 使用量、费用和执行阶段。

## 功能

**终端**
- 通过 libghostty 实现基于 Metal 的 GPU 渲染
- 支持中文/韩文 IME（preedit 组合输入）
- 完全兼容 VT100/ANSI

**块输入**
- Warp 风格的底部输入栏 — 命令和输出以块的形式可视化分隔
- 文件路径 / 历史记录 / 命令自动补全（内联提示 + 建议列表）
- 基于 CWD 的文件名补全 — 在 `~/WebstormProjects` 中输入 `Web` 即可获得提示

**工作区 & 窗格**
- 多工作区（`Cmd+T`、`Cmd+1~9`）
- 左右/上下分割（`Cmd+D`、`Cmd+Shift+D`）
- 方向键窗格导航（`Cmd+Option+↑↓←→`）
- 窗格最大化切换（`Cmd+Shift+Enter`）
- 每个窗格的 CWD 保存并在重启时恢复（会话持久化）

**右侧边栏面板**
- 通过 `Ctrl+0~9` 访问的 10 个标签面板:
  - **进程**（`Ctrl+1`）— 每个窗格的进程树和监听端口
  - **系统**（`Ctrl+2`）— CPU 核心热力图、GPU 使用率、RAM/Swap 进度条、磁盘 I/O、网络气泡图
  - **Git**（`Ctrl+3`）— 分支名称、staged/unstaged 更改、PR、分支图、GitHub Actions 状态
  - **脚本**（`Ctrl+4`）— `package.json`、`Makefile`、`Cargo.toml`、`go.mod`、Python 脚本中的可运行条目
  - **Docker**（`Ctrl+5`）— 容器和镜像概览
  - **SSH**（`Ctrl+6`）— `~/.ssh/config` 中的 SSH 主机列表
  - **片段**（`Ctrl+7`）— 保存的命令片段
  - **Claude**（`Ctrl+8`）— Claude Code 时间线和配置查看器
  - **环境变量**（`Ctrl+9`）— 活动窗格的环境变量
  - **通知**（`Ctrl+0`）— 通知历史面板
- 面板开/关切换: `Cmd+Shift+B`

**通知**
- Claude 会话事件的 macOS 桌面通知
- 应用内通知环 — 窗口边框颜色动画
- 显示未读数量的 Dock 徽章
- 通知标签图标上的侧边栏徽章
- 带完整历史记录的通知面板

**自定义标题栏**
- JetBrains 风格标题栏：应用信息居中，操作图标在右侧
- 使用 `.hiddenTitleBar` 窗口样式通过 `NSTitlebarAccessoryViewController` 实现

**Claude Code 集成**
- 监控 `~/.claude/sessions/` 自动检测活动会话 — 无需配置
- 在侧边栏和标题栏显示模型名称、Token 使用量、费用（USD）和执行阶段
- 从 [platform.claude.com](https://platform.claude.com) 实时获取定价信息
- `Cmd+Shift+C` 开始新的 Claude 会话

**系统监控**
- 在左侧边栏查看 CPU / 内存 / 网络 I/O
- 在右侧边栏系统面板查看详细信息（CPU 核心热力图、GPU、RAM/Swap 进度条、磁盘、网络）

## 安装

### 系统要求

| | 版本 |
|------|------|
| macOS | 14.0+（Sonoma） |
| Xcode | 16.0+ |
| Swift | 6.0 |
| Zig | 0.15.2+ |
| xcodegen | latest |

### 设置

```bash
# 安装 zig 和 xcodegen（Homebrew）
brew install zig xcodegen

# 包含子模块克隆
git clone --recursive https://github.com/jaeyeong94/geobuk.git
cd geobuk

# 生成 Xcode 项目
xcodegen generate

# 构建（libghostty 自动构建 — 首次构建需 5~10 分钟）
xcodebuild -scheme Geobuk -configuration Debug build

# 或在 Xcode 中打开
open Geobuk.xcodeproj
```

> **注意**: 首次构建时，`Scripts/build-libghostty.sh` 使用 Zig 编译 libghostty。之后使用缓存的 `.a` 文件，构建速度很快。

### 子模块缺失？

```bash
git submodule update --init --recursive
```

## 快速开始

1. **在 Xcode 中按 `Cmd+R`** — 终端窗格打开
2. **输入命令** — 使用底部的块输入栏。`Tab` 自动补全，`Enter` 运行
3. **分割窗格** — `Cmd+D` 左右分割，`Cmd+Shift+D` 上下分割

### 使用 Claude Code

```bash
# 在窗格中运行 Claude Code
claude

# 或使用 Cmd+Shift+C 开始新会话（自动 stream-json 模式）
```

打开侧边栏（`Cmd+B`）查看 Claude 会话状态:
- 模型（opus、sonnet 等）
- Token 使用量（输入/输出）
- 累计费用（USD）
- 当前阶段（thinking、coding、idle 等）

打开右侧面板（`Cmd+Shift+B` 或 `Ctrl+8`）查看 Claude 时间线和配置。

## Claude 集成

Geobuk 监控 Claude Code 的会话文件（`~/.claude/sessions/*.json`）自动检测活动会话。无需任何配置或修改 Claude Code。

```
┌─ 左侧边栏 ─────────────────────┐     ┌─ 右侧面板 (Ctrl+8) ──────────┐
│ 工作区                          │     │ Claude 时间线                │
│  ▼ Workspace 1                │     │  opus · coding               │
│    1. zsh ~/project           │     │  12.4K Token · $0.42         │
│    2. claude (coding)         │     │  ~/WebstormProjects/geobuk   │
│                               │     │                              │
│ Claude 会话                    │     │ Claude 配置                  │
│  opus · coding                │     │  model、max tokens 等        │
│  12.4K Token · $0.42          │     └──────────────────────────────┘
│  ~/WebstormProjects/geobuk    │
│                               │
│ 系统                           │
│  CPU 23% · MEM 14.2/32 GB    │
│  NET ↓ 1.2 MB/s ↑ 0.3 MB/s  │
└───────────────────────────────┘
```

定价数据通过 HTML 解析从 `platform.claude.com` 获取，并缓存在 `~/Library/Application Support/Geobuk/pricing.json`。

## Shell 集成

Geobuk 自动向 zsh 加载集成脚本。该脚本向应用报告 Shell 状态（空闲 / 运行中），实现块输入模式切换和命令完成检测。

**工作原理:**
1. 创建终端时，`ZDOTDIR` 环境变量加载自定义 `.zshrc`
2. `precmd`/`preexec` zsh 钩子通过 Unix 套接字发送 JSON-RPC 消息
3. 应用接收消息并在块输入 ↔ TUI 模式之间切换

**套接字路径:** `~/Library/Application Support/Geobuk/geobuk.sock`

集成脚本在现有 `.zshrc` 之后加载，不会与当前配置冲突。

## 项目结构

```
geobuk/
├── Geobuk/
│   ├── App/                    # 入口点、ContentView、AppDelegate、AppState
│   ├── Features/
│   │   ├── Terminal/           # GhosttyApp、SurfaceView、Metal 渲染
│   │   ├── Splits/             # 分割树、窗格视图
│   │   ├── Claude/             # 会话监控、定价、文件监控
│   │   ├── UI/                 # 块输入、设置、右侧面板视图
│   │   │   └── Components/     # 可复用 UI 组件
│   │   ├── Notification/       # NotificationCoordinator
│   │   ├── Workspace/          # 工作区管理器、会话持久化
│   │   ├── Session/            # Shell 状态管理器
│   │   ├── Sidebar/            # 左侧边栏视图
│   │   ├── Process/            # 进程树扫描器、端口监控
│   │   ├── Browser/            # 应用内浏览器
│   │   └── API/                # 套接字服务器、JSON-RPC
│   ├── Shared/                 # 日志、系统监控、补全提供者等
│   ├── Protocols/              # 抽象接口
│   └── Resources/              # 配置、Shell 脚本、权限
├── GeobukTests/                # 13 个测试文件，约 43 个单元测试
├── Scripts/                    # libghostty 构建脚本
├── Vendor/ghostty/             # libghostty 子模块
└── project.yml                 # xcodegen 配置
```

## 配置

### 终端默认值

`Geobuk/Resources/geobuk-default.conf`:

```
cursor-style = bar
cursor-style-blink = true
window-padding-x = 8
window-padding-y = 4
```

`~/.config/ghostty/config` 先加载，然后在其上应用这些默认值。

### 运行时设置

使用 `Cmd+,` 打开设置:
- 字体家族（中文推荐: Sarasa Gothic、Noto Sans Mono CJK SC）
- 字体大小（`Cmd++`、`Cmd+-`、`Cmd+0`）
- 行高、内边距

## 开发

### 构建

```bash
xcodegen generate
xcodebuild -scheme Geobuk -configuration Debug build
```

### 测试

```bash
xcodebuild test -scheme Geobuk GENERATE_INFOPLIST_FILE=YES
```

单元测试 + 负面测试 + 模糊测试。使用 TDD 开发。

### 日志

```bash
tail -f ~/Library/Application\ Support/Geobuk/geobuk.log
```

按组件标记（`[Terminal]`、`[Claude]`、`[Shell]`、`[Socket]` 等）。5MB 自动轮转。

## 架构

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
                               │ Shell 集成        │
                               │ · Unix Socket    │
                               │ · zsh hooks      │
                               │ · JSON-RPC       │
                               └─────────────────┘
```

- **libghostty** — Ghostty 的终端引擎。通过 C API 从 Swift 调用。使用 Metal 进行 GPU 渲染。
- **SplitTree** — 递归不可变值类型。支持分割/合并/方向导航。
- **Socket Server** — 通过 Unix 域套接字实现的双向 Shell ↔ 应用通信。
- **NotificationCoordinator** — 统一通知中心: macOS `UNUserNotificationCenter`、应用内彩色环形边框、Dock 徽章和侧边栏未读计数。

## 键盘快捷键

### 工作区

| 快捷键 | 操作 |
|----------|--------|
| `Cmd+T` | 新建工作区 |
| `Cmd+Option+W` | 关闭工作区 |
| `Cmd+1` ~ `Cmd+9` | 按编号切换工作区 |

### 窗格

| 快捷键 | 操作 |
|----------|--------|
| `Cmd+D` | 左右分割 |
| `Cmd+Shift+D` | 上下分割 |
| `Cmd+W` | 关闭窗格 |
| `Cmd+Shift+Enter` | 最大化切换 |
| `Cmd+Option+↑↓←→` | 方向焦点 |

### 视图

| 快捷键 | 操作 |
|----------|--------|
| `Cmd+B` | 切换左侧边栏 |
| `Cmd+Shift+B` | 切换右侧面板 |
| `Cmd+,` | 设置 |

### 字体

| 快捷键 | 操作 |
|----------|--------|
| `Cmd++` | 增大字体 |
| `Cmd+-` | 缩小字体 |
| `Cmd+0` | 重置字体大小 |

### Claude

| 快捷键 | 操作 |
|----------|--------|
| `Cmd+Shift+C` | 新建 Claude 会话 |

### 右侧面板标签

| 快捷键 | 面板 |
|----------|-------|
| `Ctrl+1` | 进程 |
| `Ctrl+2` | 系统 |
| `Ctrl+3` | Git |
| `Ctrl+4` | 脚本 |
| `Ctrl+5` | Docker |
| `Ctrl+6` | SSH |
| `Ctrl+7` | 片段 |
| `Ctrl+8` | Claude 时间线 + 配置 |
| `Ctrl+9` | 环境变量 |
| `Ctrl+0` | 通知 |

在该标签处于活动状态时再次按下相同的 `Ctrl+N` 快捷键即可关闭面板。

## 许可证

MIT
