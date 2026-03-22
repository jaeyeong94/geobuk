<p align="center">
  <a href="../README.md">English</a> |
  <a href="README.ko.md">한국어</a> |
  <a href="README.ja.md">日本語</a> |
  <a href="README.zh.md">中文</a>
</p>

# Geobuk (거북)

**Claude Code のための macOS ネイティブターミナル**

> ゆっくりでも、着実に。亀のように。

![geobuk スクリーンショット](../assets/screenshot.png)

---

Claude Code エージェント作業に必要なすべてのもの — セッション監視、トークン/コスト追跡、マルチワークスペース、分割ペイン — を一つのターミナルアプリに詰め込んだ。[Ghostty](https://ghostty.org) の libghostty をターミナルエンジンとして使用し、SwiftUI で UI を構築。Swift ファイル 76 個、約 16,000 行。外部パッケージ依存なし。

Warp スタイルのブロック入力、コマンドオートコンプリート、シェル状態追跡が組み込まれている。Claude Code セッションを実行すると、サイドバーにモデル名、トークン使用量、コスト、実行フェーズがリアルタイムで表示される。

## 機能

**ターミナル**
- libghostty による Metal ベース GPU レンダリング
- 日本語 IME サポート（韓国語 preedit 組み合わせ入力）
- 完全な VT100/ANSI 互換

**ブロック入力**
- Warp スタイルの下部入力バー — コマンドと出力がブロックとして視覚的に分離
- ファイルパス / 履歴 / コマンドオートコンプリート（インラインヒント + 候補リスト）
- CWD ベースのファイル名補完 — `~/WebstormProjects` で `Web` と入力するとヒントが表示

**ワークスペース & ペイン**
- マルチワークスペース（`Cmd+T`、`Cmd+1~9`）
- 左右/上下分割（`Cmd+D`、`Cmd+Shift+D`）
- 方向キーによるペイン移動（`Cmd+Option+↑↓←→`）
- ペイン最大化トグル（`Cmd+Shift+Enter`）
- ペインごとの CWD 保存と再起動時の復元（セッション永続化）

**右サイドバーパネル**
- `Ctrl+0~9` でアクセスできる 10 個のタブパネル:
  - **プロセス**（`Ctrl+1`）— ペインごとのプロセスツリーとリスニングポート
  - **システム**（`Ctrl+2`）— CPU コアヒートマップ、GPU 使用率、RAM/Swap バー、ディスク I/O、ネットワークバブル
  - **Git**（`Ctrl+3`）— ブランチ名、staged/unstaged 変更、PR、ブランチグラフ、GitHub Actions 状態
  - **スクリプト**（`Ctrl+4`）— `package.json`、`Makefile`、`Cargo.toml`、`go.mod`、Python スクリプトの実行可能エントリ
  - **Docker**（`Ctrl+5`）— コンテナとイメージの概要
  - **SSH**（`Ctrl+6`）— `~/.ssh/config` の SSH ホストリスト
  - **スニペット**（`Ctrl+7`）— 保存したコマンドスニペット
  - **Claude**（`Ctrl+8`）— Claude Code タイムラインと設定ビューアー
  - **環境変数**（`Ctrl+9`）— アクティブペインの環境変数
  - **通知**（`Ctrl+0`）— 通知履歴パネル
- パネルの開閉トグル: `Cmd+Shift+B`

**通知**
- Claude セッションイベントに対する macOS デスクトップ通知
- アプリ内通知リング — ウィンドウ境界の色アニメーション
- 未読数を表示する Dock バッジ
- 通知タブアイコンのサイドバーバッジ
- 全履歴を持つ通知パネル

**カスタムタイトルバー**
- JetBrains スタイルのタイトルバー: アプリ情報は中央、アクションアイコンは右側
- `.hiddenTitleBar` ウィンドウスタイルで `NSTitlebarAccessoryViewController` を使用して実装

**Claude Code 統合**
- `~/.claude/sessions/` を監視してアクティブセッションを自動検出 — 設定不要
- サイドバー及びタイトルバーでモデル名、トークン使用量、コスト（USD）、実行フェーズを表示
- [platform.claude.com](https://platform.claude.com) からリアルタイムで価格情報を取得
- `Cmd+Shift+C` で新しい Claude セッションを開始

**システム監視**
- 左サイドバーで CPU / メモリ / ネットワーク I/O を確認
- 右サイドバーのシステムパネルで詳細情報を確認（CPU コアヒートマップ、GPU、RAM/Swap バー、ディスク、ネットワーク）

## インストール

### 要件

| | バージョン |
|------|------|
| macOS | 14.0+ (Sonoma) |
| Xcode | 16.0+ |
| Swift | 6.0 |
| Zig | 0.15.2+ |
| xcodegen | latest |

### セットアップ

```bash
# zig と xcodegen をインストール（Homebrew）
brew install zig xcodegen

# サブモジュールを含めてクローン
git clone --recursive https://github.com/jaeyeong94/geobuk.git
cd geobuk

# Xcode プロジェクトを生成
xcodegen generate

# ビルド（libghostty が自動ビルドされる — 初回ビルドは 5〜10 分かかる）
xcodebuild -scheme Geobuk -configuration Debug build

# または Xcode で開く
open Geobuk.xcodeproj
```

> **注意**: 初回ビルド時、`Scripts/build-libghostty.sh` が Zig で libghostty をコンパイルする。以降はキャッシュされた `.a` ファイルを使用するので高速。

### サブモジュールが見つからない場合

```bash
git submodule update --init --recursive
```

## クイックスタート

1. **Xcode で `Cmd+R`** — ターミナルペインが開く
2. **コマンドを入力** — 下部のブロック入力バーを使用。`Tab` でオートコンプリート、`Enter` で実行
3. **ペインを分割** — `Cmd+D` で左右分割、`Cmd+Shift+D` で上下分割

### Claude Code を使う

```bash
# ペインで Claude Code を実行
claude

# または Cmd+Shift+C で新しいセッションを開始（stream-json モード自動適用）
```

サイドバー（`Cmd+B`）を開いて Claude セッション状態を確認:
- モデル（opus、sonnet など）
- トークン使用量（入力/出力）
- 累積コスト（USD）
- 現在のフェーズ（thinking、coding、idle など）

右パネル（`Cmd+Shift+B` または `Ctrl+8`）で Claude タイムラインと設定を確認。

## Claude 統合

Geobuk は Claude Code のセッションファイル（`~/.claude/sessions/*.json`）を監視してアクティブセッションを自動検出する。設定変更や Claude Code の修正は不要。

```
┌─ 左サイドバー ─────────────────┐     ┌─ 右パネル (Ctrl+8) ───────────┐
│ ワークスペース                  │     │ Claude タイムライン            │
│  ▼ Workspace 1                │     │  opus · coding               │
│    1. zsh ~/project           │     │  12.4K トークン · $0.42       │
│    2. claude (coding)         │     │  ~/WebstormProjects/geobuk   │
│                               │     │                              │
│ Claude セッション               │     │ Claude 設定                  │
│  opus · coding                │     │  model、max tokens など       │
│  12.4K トークン · $0.42        │     └──────────────────────────────┘
│  ~/WebstormProjects/geobuk    │
│                               │
│ システム                       │
│  CPU 23% · MEM 14.2/32 GB    │
│  NET ↓ 1.2 MB/s ↑ 0.3 MB/s  │
└───────────────────────────────┘
```

価格データは `platform.claude.com` から HTML パーシングで取得され、`~/Library/Application Support/Geobuk/pricing.json` にキャッシュされる。

## シェル統合

Geobuk は zsh に統合スクリプトを自動ロードする。このスクリプトはシェル状態（アイドル / 実行中）をアプリに報告し、ブロック入力モードの切り替えとコマンド完了検出を可能にする。

**動作の仕組み:**
1. ターミナル作成時に `ZDOTDIR` 環境変数でカスタム `.zshrc` をロード
2. `precmd`/`preexec` zsh フックが Unix ソケットを通じて JSON-RPC メッセージを送信
3. アプリがメッセージを受信してブロック入力 ↔ TUI モードを切り替え

**ソケットパス:** `~/Library/Application Support/Geobuk/geobuk.sock`

統合スクリプトは既存の `.zshrc` の後にロードされるため、現在の設定と競合しない。

## プロジェクト構造

```
geobuk/
├── Geobuk/
│   ├── App/                    # エントリーポイント、ContentView、AppDelegate、AppState
│   ├── Features/
│   │   ├── Terminal/           # GhosttyApp、SurfaceView、Metal レンダリング
│   │   ├── Splits/             # 分割ツリー、ペインビュー
│   │   ├── Claude/             # セッションモニター、価格、ファイル監視
│   │   ├── UI/                 # ブロック入力、設定、右パネルビュー
│   │   │   └── Components/     # 再利用可能な UI コンポーネント
│   │   ├── Notification/       # NotificationCoordinator
│   │   ├── Workspace/          # ワークスペースマネージャー、セッション永続化
│   │   ├── Session/            # シェル状態マネージャー
│   │   ├── Sidebar/            # 左サイドバービュー
│   │   ├── Process/            # プロセスツリースキャナー、ポート監視
│   │   ├── Browser/            # インアプリブラウザ
│   │   └── API/                # ソケットサーバー、JSON-RPC
│   ├── Shared/                 # ロガー、システムモニター、補完プロバイダーなど
│   ├── Protocols/              # 抽象化インターフェース
│   └── Resources/              # 設定、シェルスクリプト、エンタイトルメント
├── GeobukTests/                # 13 テストファイル、約 43 ユニットテスト
├── Scripts/                    # libghostty ビルドスクリプト
├── Vendor/ghostty/             # libghostty サブモジュール
└── project.yml                 # xcodegen 設定
```

## 設定

### ターミナルデフォルト

`Geobuk/Resources/geobuk-default.conf`:

```
cursor-style = bar
cursor-style-blink = true
window-padding-x = 8
window-padding-y = 4
```

`~/.config/ghostty/config` が先にロードされ、その後これらのデフォルト値が適用される。

### ランタイム設定

`Cmd+,` で設定を開く:
- フォントファミリー（日本語推奨: D2Coding、Sarasa Gothic、Noto Sans Mono）
- フォントサイズ（`Cmd++`、`Cmd+-`、`Cmd+0`）
- 行間、パディング

## 開発

### ビルド

```bash
xcodegen generate
xcodebuild -scheme Geobuk -configuration Debug build
```

### テスト

```bash
xcodebuild test -scheme Geobuk GENERATE_INFOPLIST_FILE=YES
```

ユニット + ネガティブ + ファズテスト。TDD で開発。

### ログ

```bash
tail -f ~/Library/Application\ Support/Geobuk/geobuk.log
```

コンポーネント別タグ（`[Terminal]`、`[Claude]`、`[Shell]`、`[Socket]` など）。5MB で自動ローテーション。

## アーキテクチャ

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
                               │ シェル統合        │
                               │ · Unix Socket    │
                               │ · zsh hooks      │
                               │ · JSON-RPC       │
                               └─────────────────┘
```

- **libghostty** — Ghostty のターミナルエンジン。C API を通じて Swift から呼び出し。Metal で GPU レンダリング。
- **SplitTree** — 再帰的な不変値型。分割/マージ/方向ナビゲーションをサポート。
- **Socket Server** — Unix ドメインソケットを通じた双方向シェル ↔ アプリ通信。
- **NotificationCoordinator** — 統合通知ハブ: macOS `UNUserNotificationCenter`、アプリ内カラーリング境界、Dock バッジ、サイドバー未読カウント。

## キーボードショートカット

### ワークスペース

| ショートカット | 操作 |
|----------|--------|
| `Cmd+T` | 新しいワークスペース |
| `Cmd+Option+W` | ワークスペースを閉じる |
| `Cmd+1` ~ `Cmd+9` | ワークスペースを番号で切り替え |

### ペイン

| ショートカット | 操作 |
|----------|--------|
| `Cmd+D` | 左右に分割 |
| `Cmd+Shift+D` | 上下に分割 |
| `Cmd+W` | ペインを閉じる |
| `Cmd+Shift+Enter` | 最大化トグル |
| `Cmd+Option+↑↓←→` | 方向フォーカス |

### 表示

| ショートカット | 操作 |
|----------|--------|
| `Cmd+B` | 左サイドバートグル |
| `Cmd+Shift+B` | 右パネルトグル |
| `Cmd+,` | 設定 |

### フォント

| ショートカット | 操作 |
|----------|--------|
| `Cmd++` | フォントサイズを大きく |
| `Cmd+-` | フォントサイズを小さく |
| `Cmd+0` | フォントサイズをリセット |

### Claude

| ショートカット | 操作 |
|----------|--------|
| `Cmd+Shift+C` | 新しい Claude セッション |

### 右パネルタブ

| ショートカット | パネル |
|----------|-------|
| `Ctrl+1` | プロセス |
| `Ctrl+2` | システム |
| `Ctrl+3` | Git |
| `Ctrl+4` | スクリプト |
| `Ctrl+5` | Docker |
| `Ctrl+6` | SSH |
| `Ctrl+7` | スニペット |
| `Ctrl+8` | Claude タイムライン + 設定 |
| `Ctrl+9` | 環境変数 |
| `Ctrl+0` | 通知 |

同じ `Ctrl+N` ショートカットをそのタブがアクティブな状態で再度押すとパネルが閉じる。

## ライセンス

MIT
