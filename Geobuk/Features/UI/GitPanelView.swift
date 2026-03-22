import SwiftUI

/// Git 상태 패널 — 브랜치, 변경 파일, 최근 커밋, PR, 브랜치 그래프 표시
struct GitPanelView: View {
    var currentDirectory: String?

    // MARK: - State

    @State private var branchName: String = ""
    @State private var changedFiles: [GitFileStatus] = []
    @State private var recentCommits: [GitCommit] = []
    @State private var remoteURL: String = ""
    @State private var isGitRepo: Bool = true
    @State private var isLoading: Bool = false

    @State private var pullRequests: [GitPR] = []
    @State private var prError: String? = nil
    @State private var isPRLoading: Bool = false

    @State private var branchGraphLines: [BranchGraphLine] = []
    @State private var isGraphLoading: Bool = false

    @State private var branchSectionExpanded: Bool = true
    @State private var changesSectionExpanded: Bool = true
    @State private var commitsSectionExpanded: Bool = true
    @State private var prSectionExpanded: Bool = true
    @State private var graphSectionExpanded: Bool = true

    @State private var pollTask: Task<Void, Never>? = nil
    @State private var prPollTask: Task<Void, Never>? = nil

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack(spacing: 6) {
                Text("Git")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                if isGitRepo && !branchName.isEmpty {
                    Text(branchName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(4)
                }

                Spacer()

                if isLoading || isPRLoading || isGraphLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if !isGitRepo {
                // Git 저장소 아님
                VStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Not a git repository")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 32)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Branch Info 섹션
                        collapsibleSection(
                            title: "Branch Info",
                            systemImage: "arrow.triangle.branch",
                            isExpanded: $branchSectionExpanded
                        ) {
                            branchInfoContent
                        }

                        Divider().padding(.horizontal, 12)

                        // Changed Files 섹션
                        collapsibleSection(
                            title: "Changed Files",
                            systemImage: "doc.badge.ellipsis",
                            isExpanded: $changesSectionExpanded,
                            badge: changedFiles.isEmpty ? nil : "\(changedFiles.count)"
                        ) {
                            changedFilesContent
                        }

                        Divider().padding(.horizontal, 12)

                        // Pull Requests 섹션
                        collapsibleSection(
                            title: "Pull Requests",
                            systemImage: "arrow.triangle.merge",
                            isExpanded: $prSectionExpanded,
                            badge: pullRequests.isEmpty ? nil : "\(pullRequests.count)"
                        ) {
                            pullRequestsContent
                        }

                        Divider().padding(.horizontal, 12)

                        // Recent Commits 섹션
                        collapsibleSection(
                            title: "Recent Commits",
                            systemImage: "clock.arrow.circlepath",
                            isExpanded: $commitsSectionExpanded
                        ) {
                            recentCommitsContent
                        }

                        Divider().padding(.horizontal, 12)

                        // Branch Graph 섹션
                        collapsibleSection(
                            title: "Branch Graph",
                            systemImage: "point.3.connected.trianglepath.dotted",
                            isExpanded: $graphSectionExpanded
                        ) {
                            branchGraphContent
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .onAppear {
            refresh()
            refreshPRs()
            refreshBranchGraph()
            startPolling()
            startPRPolling()
        }
        .onDisappear {
            pollTask?.cancel()
            pollTask = nil
            prPollTask?.cancel()
            prPollTask = nil
        }
        .onChange(of: currentDirectory) { _ in
            refresh()
            refreshPRs()
            refreshBranchGraph()
        }
    }

    // MARK: - Section Views

    @ViewBuilder
    private var branchInfoContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            infoRow(label: "Branch", value: branchName.isEmpty ? "—" : branchName)

            if !remoteURL.isEmpty {
                infoRow(label: "Remote", value: remoteURL)
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var changedFilesContent: some View {
        if changedFiles.isEmpty {
            Text("No changes")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(changedFiles) { file in
                    fileStatusRow(file)
                }
            }
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var pullRequestsContent: some View {
        if let error = prError {
            VStack(alignment: .leading, spacing: 4) {
                if error.contains("not installed") || error.contains("not found") {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("Install GitHub CLI: brew install gh")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                } else {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
            }
            .padding(.bottom, 4)
        } else if pullRequests.isEmpty && !isPRLoading {
            Text("No open pull requests")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(pullRequests) { pr in
                    prRow(pr)
                }
            }
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var recentCommitsContent: some View {
        if recentCommits.isEmpty {
            Text("No commits")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(recentCommits) { commit in
                    commitRow(commit)
                }
            }
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var branchGraphContent: some View {
        if branchGraphLines.isEmpty {
            Text("No graph data")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(branchGraphLines) { line in
                    graphLineRow(line)
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Row Helpers

    private func fileStatusRow(_ file: GitFileStatus) -> some View {
        HStack(spacing: 6) {
            Text(file.statusSymbol)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(file.statusColor)
                .frame(width: 14, alignment: .center)

            Text(file.filename)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            }
        }
    }

    private func prRow(_ pr: GitPR) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("#\(pr.number)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                Text(pr.title)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(spacing: 6) {
                Text(pr.headRefName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("@\(pr.authorLogin)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Open in Browser") {
                if let url = URL(string: pr.url) {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(pr.url, forType: .string)
            }
        }
    }

    private func commitRow(_ commit: GitCommit) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(commit.hash)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.blue)
                .fixedSize()

            Text(commit.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Hash") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.hash, forType: .string)
            }
            Button("Copy Message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.message, forType: .string)
            }
        }
    }

    private func graphLineRow(_ line: BranchGraphLine) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Render the graph line as attributed segments
            graphLineText(line)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func graphLineText(_ line: BranchGraphLine) -> some View {
        // Build inline styled text from segments
        line.segments.reduce(Text("")) { result, segment in
            result + Text(segment.text)
                .foregroundColor(segment.color)
                .font(.system(size: 11, design: .monospaced))
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    // MARK: - Collapsible Section

    @ViewBuilder
    private func collapsibleSection<Content: View>(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        badge: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.wrappedValue.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.5))
                            .cornerRadius(4)
                    }

                    Spacer()

                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
            }
        }
    }

    // MARK: - Data Loading

    private func refresh() {
        guard let dir = currentDirectory, !dir.isEmpty else {
            isGitRepo = false
            return
        }

        isLoading = true

        Task.detached(priority: .background) {
            let branch = Self.runGit(args: ["rev-parse", "--abbrev-ref", "HEAD"], in: dir)
            let statusOutput = Self.runGit(args: ["status", "--porcelain"], in: dir)
            let logOutput = Self.runGit(args: ["log", "--oneline", "-10"], in: dir)
            let remote = Self.runGit(args: ["remote", "get-url", "origin"], in: dir)

            let isRepo = branch != nil
            let parsedBranch = branch?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let parsedFiles = Self.parseStatus(statusOutput ?? "")
            let parsedCommits = Self.parseLog(logOutput ?? "")
            let parsedRemote = remote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            await MainActor.run {
                self.isGitRepo = isRepo
                self.branchName = parsedBranch
                self.changedFiles = parsedFiles
                self.recentCommits = parsedCommits
                self.remoteURL = parsedRemote
                self.isLoading = false
            }
        }
    }

    private func refreshPRs() {
        guard let dir = currentDirectory, !dir.isEmpty else { return }

        isPRLoading = true

        Task.detached(priority: .background) {
            let result = Self.runGHPRList(in: dir)
            await MainActor.run {
                self.isPRLoading = false
                switch result {
                case .success(let prs):
                    self.pullRequests = prs
                    self.prError = nil
                case .failure(let error):
                    self.pullRequests = []
                    self.prError = error.message
                }
            }
        }
    }

    private func refreshBranchGraph() {
        guard let dir = currentDirectory, !dir.isEmpty else { return }

        isGraphLoading = true

        Task.detached(priority: .background) {
            let output = Self.runGit(
                args: ["log", "--oneline", "--graph", "--all", "--decorate", "-20"],
                in: dir
            ) ?? ""
            let lines = Self.parseBranchGraph(output)
            await MainActor.run {
                self.branchGraphLines = lines
                self.isGraphLoading = false
            }
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                guard !Task.isCancelled else { break }
                refresh()
                refreshBranchGraph()
            }
        }
    }

    private func startPRPolling() {
        prPollTask?.cancel()
        prPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                guard !Task.isCancelled else { break }
                refreshPRs()
            }
        }
    }

    // MARK: - Git Command Helpers (nonisolated)

    nonisolated static func runGit(args: [String], in directory: String) -> String? {
        ProcessRunner.output(
            "/usr/bin/git",
            arguments: ["--no-optional-locks"] + args,
            currentDirectory: directory,
            environment: ["GIT_TERMINAL_PROMPT": "0"]
        )
    }

    /// Runs `gh pr list` and returns parsed PRs or an error string.
    nonisolated static func runGHPRList(in directory: String) -> Result<[GitPR], GHError> {
        // Locate gh CLI
        let ghPaths = ["/usr/local/bin/gh", "/opt/homebrew/bin/gh"]
        guard let ghPath = ghPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return .failure(GHError("gh not installed"))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["pr", "list", "--json", "number,title,headRefName,author,state,url", "--limit", "10"]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        var env = ProcessInfo.processInfo.environment
        // Ensure PATH includes common brew locations for any gh dependencies
        env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(GHError("Failed to run gh: \(error.localizedDescription)"))
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errMsg = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "gh failed"
            // If not in a git repo or not authenticated, surface a concise message
            return .failure(GHError(errMsg.isEmpty ? "gh pr list failed" : errMsg))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return .failure(GHError("Failed to parse gh output"))
        }

        let prs = json.compactMap { item -> GitPR? in
            guard
                let number = item["number"] as? Int,
                let title = item["title"] as? String,
                let headRefName = item["headRefName"] as? String,
                let author = item["author"] as? [String: Any],
                let authorLogin = author["login"] as? String,
                let state = item["state"] as? String,
                let url = item["url"] as? String
            else { return nil }
            return GitPR(number: number, title: title, headRefName: headRefName, authorLogin: authorLogin, state: state, url: url)
        }

        return .success(prs)
    }

    nonisolated static func parseStatus(_ output: String) -> [GitFileStatus] {
        output
            .components(separatedBy: "\n")
            .compactMap { line -> GitFileStatus? in
                guard line.count >= 3 else { return nil }
                let x = line[line.startIndex]          // index status
                let y = line[line.index(line.startIndex, offsetBy: 1)]  // worktree status
                let path = String(line.dropFirst(3))
                guard !path.isEmpty else { return nil }

                return GitFileStatus(x: x, y: y, path: path)
            }
    }

    nonisolated static func parseLog(_ output: String) -> [GitCommit] {
        output
            .components(separatedBy: "\n")
            .compactMap { line -> GitCommit? in
                let parts = line.split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return GitCommit(hash: String(parts[0]), message: String(parts[1]))
            }
    }

    /// Parses `git log --oneline --graph --all --decorate` output into colored segments.
    nonisolated static func parseBranchGraph(_ output: String) -> [BranchGraphLine] {
        let rawLines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        return rawLines.map { parseBranchGraphLine($0) }
    }

    nonisolated static func parseBranchGraphLine(_ line: String) -> BranchGraphLine {
        // Split the line into: graph part, optional hash, rest (message + decorations)
        // Example line: "* abc1234 (HEAD -> main, origin/main) commit message"
        // Or graph-only: "|"  "|\\"  "| *"

        var segments: [GraphSegment] = []

        // Find where the graph characters end and the commit info starts.
        // Graph chars: * | / \ - space
        let graphChars: Set<Character> = ["*", "|", "/", "\\", "-", " "]

        var idx = line.startIndex

        // 1. Collect graph prefix (everything before the first alphanumeric that follows a space after graph chars)
        var graphPart = ""
        var rest = ""

        // The hash starts at the first hex-char cluster after graph symbols
        // Strategy: scan until we hit a character that is NOT in graphChars, then split
        while idx < line.endIndex {
            let ch = line[idx]
            if graphChars.contains(ch) {
                graphPart.append(ch)
                idx = line.index(after: idx)
            } else {
                // From here onward: hash + message + decorations
                rest = String(line[idx...])
                break
            }
        }

        // Render graph part: color '*' and graph line chars in green
        if !graphPart.isEmpty {
            segments.append(GraphSegment(text: graphPart, color: .green))
        }

        if rest.isEmpty {
            return BranchGraphLine(segments: segments)
        }

        // 2. Extract hash (first 7+ hex chars)
        let restTokens = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let hashToken = restTokens.count > 0 ? String(restTokens[0]) : ""
        let afterHash = restTokens.count > 1 ? String(restTokens[1]) : ""

        if !hashToken.isEmpty {
            segments.append(GraphSegment(text: hashToken + " ", color: .blue))
        }

        if afterHash.isEmpty {
            return BranchGraphLine(segments: segments)
        }

        // 3. Parse decorations `(...)` and message
        // Check if afterHash starts with `(`
        if afterHash.hasPrefix("(") {
            // Find closing `)`
            if let closeIdx = afterHash.firstIndex(of: ")") {
                let decoContent = String(afterHash[afterHash.index(after: afterHash.startIndex)..<closeIdx])
                let afterDeco = String(afterHash[afterHash.index(after: closeIdx)...])
                    .trimmingCharacters(in: .init(charactersIn: " "))

                // Render each decoration token
                let decoTokens = decoContent.components(separatedBy: ", ")
                segments.append(GraphSegment(text: "(", color: .secondary))
                for (i, token) in decoTokens.enumerated() {
                    let color: Color
                    if token.hasPrefix("HEAD") {
                        color = .red
                    } else if token.hasPrefix("tag:") {
                        color = .yellow
                    } else {
                        color = .green
                    }
                    segments.append(GraphSegment(text: token, color: color))
                    if i < decoTokens.count - 1 {
                        segments.append(GraphSegment(text: ", ", color: .secondary))
                    }
                }
                segments.append(GraphSegment(text: ")", color: .secondary))

                if !afterDeco.isEmpty {
                    segments.append(GraphSegment(text: " " + afterDeco, color: .primary))
                }
            } else {
                // Malformed — just show as primary
                segments.append(GraphSegment(text: afterHash, color: .primary))
            }
        } else {
            segments.append(GraphSegment(text: afterHash, color: .primary))
        }

        return BranchGraphLine(segments: segments)
    }
}

// MARK: - Models

struct GitFileStatus: Identifiable {
    let id = UUID()
    let x: Character   // index/staged status
    let y: Character   // worktree status
    let path: String

    var filename: String {
        // Handle rename notation "old -> new"
        if path.contains(" -> ") {
            return path.components(separatedBy: " -> ").last ?? path
        }
        return (path as NSString).lastPathComponent
    }

    var statusSymbol: String {
        if x != " " && x != "?" && y == " " {
            // staged change
            return String(x)
        }
        if y != " " && y != "?" {
            return String(y)
        }
        return String(x)
    }

    var statusColor: Color {
        // staged (index column is set, worktree is clean)
        if x != " " && x != "?" && y == " " {
            return .green
        }
        // untracked
        if x == "?" {
            return .gray
        }
        // modified / deleted / conflict
        return .red
    }
}

struct GitCommit: Identifiable {
    let id = UUID()
    let hash: String
    let message: String
}

struct GitPR: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
    let headRefName: String
    let authorLogin: String
    let state: String
    let url: String
}

struct GraphSegment {
    let text: String
    let color: Color
}

struct BranchGraphLine: Identifiable {
    let id = UUID()
    let segments: [GraphSegment]
}

struct GHError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
