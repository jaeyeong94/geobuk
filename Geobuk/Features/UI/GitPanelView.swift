import SwiftUI

/// Git 상태 패널 — 브랜치, 변경 파일, 최근 커밋, PR, 브랜치 그래프, 워크플로우, 최근 실행 표시
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

    @State private var workflows: [WorkflowFile] = []
    @State private var workflowsExpanded: Bool = false

    @State private var recentRuns: [WorkflowRun] = []
    @State private var runsExpanded: Bool = false
    @State private var runsError: String? = nil

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
                        CollapsibleSectionView(
                            title: "Branch Info",
                            systemImage: "arrow.triangle.branch",
                            isExpanded: $branchSectionExpanded
                        ) {
                            branchInfoContent
                        }

                        Divider().padding(.horizontal, 12)

                        // Changed Files 섹션
                        CollapsibleSectionView(
                            title: "Changed Files",
                            systemImage: "doc.badge.ellipsis",
                            isExpanded: $changesSectionExpanded,
                            badge: changedFiles.isEmpty ? nil : "\(changedFiles.count)"
                        ) {
                            changedFilesContent
                        }

                        Divider().padding(.horizontal, 12)

                        // Pull Requests 섹션
                        CollapsibleSectionView(
                            title: "Pull Requests",
                            systemImage: "arrow.triangle.merge",
                            isExpanded: $prSectionExpanded,
                            badge: pullRequests.isEmpty ? nil : "\(pullRequests.count)"
                        ) {
                            pullRequestsContent
                        }

                        Divider().padding(.horizontal, 12)

                        // Recent Commits 섹션
                        CollapsibleSectionView(
                            title: "Recent Commits",
                            systemImage: "clock.arrow.circlepath",
                            isExpanded: $commitsSectionExpanded
                        ) {
                            recentCommitsContent
                        }

                        Divider().padding(.horizontal, 12)

                        // Branch Graph 섹션
                        CollapsibleSectionView(
                            title: "Branch Graph",
                            systemImage: "point.3.connected.trianglepath.dotted",
                            isExpanded: $graphSectionExpanded
                        ) {
                            branchGraphContent
                        }

                        Divider().padding(.horizontal, 12)

                        // Workflows 섹션
                        CollapsibleSectionView(
                            title: "Workflows",
                            systemImage: "gearshape.2",
                            isExpanded: $workflowsExpanded,
                            badge: workflows.isEmpty ? nil : "\(workflows.count)"
                        ) {
                            workflowsContent
                        }

                        Divider().padding(.horizontal, 12)

                        // Recent Runs 섹션
                        CollapsibleSectionView(
                            title: "Recent Runs",
                            systemImage: "play.circle",
                            isExpanded: $runsExpanded,
                            badge: recentRuns.isEmpty ? nil : "\(recentRuns.count)"
                        ) {
                            recentRunsContent
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
            refreshWorkflows()
            refreshRuns()
            startPolling()
            startPRPolling()
        }
        .onDisappear {
            pollTask?.cancel()
            pollTask = nil
            prPollTask?.cancel()
            prPollTask = nil
        }
        .onChange(of: currentDirectory) { _, _ in
            refresh()
            refreshPRs()
            refreshBranchGraph()
            refreshWorkflows()
            refreshRuns()
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

    @ViewBuilder
    private var workflowsContent: some View {
        if workflows.isEmpty {
            Text("No workflow files found")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(workflows) { workflow in
                    workflowRow(workflow)
                }
            }
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var recentRunsContent: some View {
        if let error = runsError {
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
        } else if recentRuns.isEmpty {
            Text("No recent runs")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(recentRuns) { run in
                    runRow(run)
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

    private func workflowRow(_ workflow: WorkflowFile) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(workflow.filename)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if workflow.name != workflow.filename {
                Text(workflow.name)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if !workflow.triggers.isEmpty {
                HStack(spacing: 4) {
                    ForEach(workflow.triggers, id: \.self) { trigger in
                        Text(Self.triggerIcon(for: trigger) + trigger)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(3)
                    }
                }
            }

            if !workflow.jobs.isEmpty {
                Text(workflow.jobs.joined(separator: ", "))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Open File") {
                if let dir = currentDirectory {
                    let filePath = dir + "/.github/workflows/" + workflow.filename
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: filePath)])
                }
            }
        }
    }

    private func runRow(_ run: WorkflowRun) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(Self.runStatusIcon(status: run.status, conclusion: run.conclusion))
                    .font(.system(size: 12))

                Text(run.name)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text(Self.relativeTime(from: run.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Text(run.headBranch)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Open in Browser") {
                if let url = URL(string: run.url) {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Re-run") {
                rerunWorkflow(run)
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

    private func refreshWorkflows() {
        guard let dir = currentDirectory, !dir.isEmpty else { return }

        Task.detached(priority: .background) {
            let parsed = Self.parseWorkflowFiles(in: dir)
            await MainActor.run {
                self.workflows = parsed
            }
        }
    }

    private func refreshRuns() {
        guard let dir = currentDirectory, !dir.isEmpty else { return }

        Task.detached(priority: .background) {
            let result = Self.runGHRunList(in: dir)
            await MainActor.run {
                switch result {
                case .success(let runs):
                    self.recentRuns = runs
                    self.runsError = nil
                case .failure(let error):
                    self.recentRuns = []
                    self.runsError = error.message
                }
            }
        }
    }

    private func rerunWorkflow(_ run: WorkflowRun) {
        guard let dir = currentDirectory, !dir.isEmpty else { return }

        Task.detached(priority: .background) {
            let ghPaths = ["/usr/local/bin/gh", "/opt/homebrew/bin/gh"]
            guard let ghPath = ghPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: ghPath)
            // Extract run ID from URL: last path component
            let runId = run.url.components(separatedBy: "/").last ?? ""
            process.arguments = ["run", "rerun", runId]
            process.currentDirectoryURL = URL(fileURLWithPath: dir)

            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
            process.environment = env

            try? process.run()
            process.waitUntilExit()
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
                refreshRuns()
            }
        }
    }

    // MARK: - Git Command Helpers (nonisolated)

    nonisolated static func runGit(args: [String], in directory: String) -> String? {
        GitRunner.run(args: args, in: directory)
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

    /// Runs `gh run list` and returns parsed WorkflowRuns or an error.
    nonisolated static func runGHRunList(in directory: String) -> Result<[WorkflowRun], GHError> {
        let ghPaths = ["/usr/local/bin/gh", "/opt/homebrew/bin/gh"]
        guard let ghPath = ghPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return .failure(GHError("gh not installed"))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["run", "list", "--limit", "10", "--json", "name,status,conclusion,headBranch,createdAt,url"]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        var env = ProcessInfo.processInfo.environment
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
            return .failure(GHError(errMsg.isEmpty ? "gh run list failed" : errMsg))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return .failure(GHError("Failed to parse gh output"))
        }

        let runs = json.compactMap { item -> WorkflowRun? in
            guard
                let name = item["name"] as? String,
                let status = item["status"] as? String,
                let headBranch = item["headBranch"] as? String,
                let createdAt = item["createdAt"] as? String,
                let url = item["url"] as? String
            else { return nil }
            let conclusion = item["conclusion"] as? String
            return WorkflowRun(name: name, status: status, conclusion: conclusion, headBranch: headBranch, createdAt: createdAt, url: url)
        }

        return .success(runs)
    }

    /// Scans `.github/workflows/` for YAML files and parses them line-by-line.
    nonisolated static func parseWorkflowFiles(in directory: String) -> [WorkflowFile] {
        let workflowsDir = directory + "/.github/workflows"
        let fm = FileManager.default

        guard let entries = try? fm.contentsOfDirectory(atPath: workflowsDir) else { return [] }

        let yamlFiles = entries.filter { $0.hasSuffix(".yml") || $0.hasSuffix(".yaml") }

        return yamlFiles.compactMap { filename -> WorkflowFile? in
            let filePath = workflowsDir + "/" + filename
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return nil }
            return parseWorkflowFile(filename: filename, content: content)
        }.sorted { $0.filename < $1.filename }
    }

    nonisolated static func parseWorkflowFile(filename: String, content: String) -> WorkflowFile {
        let lines = content.components(separatedBy: "\n")
        var workflowName = filename
        var triggers: [String] = []
        var jobs: [String] = []

        var parsingOn = false
        var parsingJobs = false

        for line in lines {
            let stripped = line.trimmingCharacters(in: .whitespaces)

            // Top-level "name:" key (no leading spaces)
            if line.hasPrefix("name:") && !line.hasPrefix("name: #") {
                let value = String(line.dropFirst("name:".count)).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    workflowName = value
                }
                parsingOn = false
                parsingJobs = false
                continue
            }

            // Top-level "on:" key
            if line.hasPrefix("on:") {
                parsingOn = true
                parsingJobs = false
                // Check if value is inline: "on: push" or "on: [push, pull_request]"
                let inlineValue = String(line.dropFirst("on:".count)).trimmingCharacters(in: .whitespaces)
                if !inlineValue.isEmpty && inlineValue != "" {
                    // Could be "[push, pull_request]" or "push" or "workflow_dispatch"
                    let cleaned = inlineValue
                        .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    let parts = cleaned.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    if !parts.isEmpty {
                        triggers = parts
                        parsingOn = false
                    }
                }
                continue
            }

            // Top-level "jobs:" key
            if line.hasPrefix("jobs:") {
                parsingJobs = true
                parsingOn = false
                continue
            }

            // If we encounter another top-level key, stop parsing sub-sections
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") && !stripped.isEmpty && !stripped.hasPrefix("#") {
                // A non-indented non-empty line that isn't one of the above — end sub-parsing
                if parsingOn || parsingJobs {
                    parsingOn = false
                    parsingJobs = false
                }
                continue
            }

            // Parse trigger keys: indented lines under "on:" with pattern "  key:"
            if parsingOn {
                // Match lines like "  push:" or "  pull_request:" at 2-space indent
                if line.hasPrefix("  ") && !line.hasPrefix("   ") {
                    let key = stripped.hasSuffix(":") ? String(stripped.dropLast()) : stripped
                    let cleanKey = key.components(separatedBy: ":").first ?? key
                    if !cleanKey.isEmpty && !cleanKey.hasPrefix("#") {
                        triggers.append(cleanKey.trimmingCharacters(in: .whitespaces))
                    }
                }
            }

            // Parse job keys: indented lines under "jobs:" with pattern "  jobname:"
            if parsingJobs {
                // Match lines like "  build:" or "  test:" at 2-space indent (not deeper)
                if line.hasPrefix("  ") && !line.hasPrefix("   ") {
                    let key = stripped.hasSuffix(":") ? String(stripped.dropLast()) : stripped
                    let cleanKey = key.components(separatedBy: ":").first ?? key
                    if !cleanKey.isEmpty && !cleanKey.hasPrefix("#") {
                        jobs.append(cleanKey.trimmingCharacters(in: .whitespaces))
                    }
                }
            }
        }

        return WorkflowFile(filename: filename, name: workflowName, triggers: triggers, jobs: jobs)
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

    // MARK: - Display Helpers (nonisolated)

    nonisolated static func triggerIcon(for trigger: String) -> String {
        switch trigger {
        case "push":             return "🔀 "
        case "pull_request":     return "📋 "
        case "schedule":         return "⏰ "
        case "workflow_dispatch": return "🖱 "
        case "release":          return "🏷 "
        default:                 return ""
        }
    }

    nonisolated static func runStatusIcon(status: String, conclusion: String?) -> String {
        if status == "in_progress" { return "🔄" }
        if status == "queued"      { return "⏳" }
        switch conclusion {
        case "success":   return "✅"
        case "failure":   return "❌"
        case "cancelled": return "⏭"
        case "skipped":   return "⏭"
        default:          return "⚪"
        }
    }

    nonisolated static func relativeTime(from iso8601: String) -> String {
        // Parse ISO8601 date string like "2024-01-15T10:30:00Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso8601)

        if date == nil {
            // Try without fractional seconds
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            date = f2.date(from: iso8601)
        }

        guard let date = date else { return iso8601 }

        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60      { return "\(seconds)s ago" }
        if seconds < 3600    { return "\(seconds / 60)m ago" }
        if seconds < 86400   { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
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

struct WorkflowFile: Identifiable {
    let id = UUID()
    let filename: String
    let name: String          // from "name:" in YAML
    let triggers: [String]    // from "on:" in YAML (push, pull_request, schedule, workflow_dispatch)
    let jobs: [String]        // from "jobs:" keys in YAML
}

struct WorkflowRun: Identifiable {
    let id = UUID()
    let name: String
    let status: String        // "completed", "in_progress", "queued"
    let conclusion: String?   // "success", "failure", "cancelled", "skipped"
    let headBranch: String
    let createdAt: String
    let url: String
}
