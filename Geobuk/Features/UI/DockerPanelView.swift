import SwiftUI

// MARK: - Model

struct ContainerInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let image: String
    let status: String
    let ports: String
    let state: String

    var statusColor: Color {
        switch state.lowercased() {
        case "running":
            return .green
        case "paused":
            return Color.yellow
        default:
            return .gray
        }
    }
}

// MARK: - View

/// Docker 컨테이너 상태 패널 — `docker ps -a` 결과를 5초마다 폴링하여 표시
struct DockerPanelView: View {

    // MARK: State

    @State private var containers: [ContainerInfo] = []
    @State private var dockerAvailable: Bool = false
    @State private var daemonRunning: Bool = false
    @State private var isLoading: Bool = true
    @State private var pollingTask: Task<Void, Never>? = nil
    @State private var logOutput: String? = nil
    @State private var logContainerName: String? = nil

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if isLoading {
                loadingView
            } else if !dockerAvailable {
                notFoundView
            } else if !daemonRunning {
                daemonNotRunningView
            } else {
                containerList
            }
        }
        .onAppear {
            startPolling()
        }
        .onDisappear {
            pollingTask?.cancel()
            pollingTask = nil
        }
        .sheet(item: Binding(
            get: { logContainerName.map { LogSheet(name: $0, output: logOutput ?? "") } },
            set: { if $0 == nil { logContainerName = nil; logOutput = nil } }
        )) { sheet in
            LogSheetView(containerName: sheet.name, output: sheet.output)
        }
    }

    // MARK: Subviews

    private var header: some View {
        HStack(spacing: 6) {
            Text("Docker")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            if dockerAvailable && daemonRunning && !isLoading {
                Text("\(containers.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.5))
                    .clipShape(Capsule())
            }

            Spacer()

            if dockerAvailable && daemonRunning && !isLoading {
                Button(action: { refreshNow() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var loadingView: some View {
        VStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.6)
            Text("Checking Docker…")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    private var notFoundView: some View {
        VStack(spacing: 6) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            Text("Docker not found")
                .font(.system(size: 12, weight: .medium))
            Text("Install Docker Desktop or Docker CLI to use this panel.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var daemonNotRunningView: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            Text("Docker daemon not running")
                .font(.system(size: 12, weight: .medium))
            Text("Start Docker Desktop or run `dockerd` to continue.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var containerList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if containers.isEmpty {
                    Text("No containers")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    ForEach(containers) { container in
                        containerRow(container)
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func containerRow(_ container: ContainerInfo) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 상태 점
            Circle()
                .fill(container.statusColor)
                .frame(width: 7, height: 7)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                // 이름
                Text(container.name)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .lineLimit(1)

                // 이미지
                Text(container.image)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // 상태 텍스트
                Text(container.status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // 포트
                if !container.ports.isEmpty {
                    Text(container.ports)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.blue)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            containerContextMenu(container)
        }
    }

    @ViewBuilder
    private func containerContextMenu(_ container: ContainerInfo) -> some View {
        if container.state.lowercased() != "running" {
            Button("Start") {
                runDockerCommand(["start", container.id])
            }
        }
        if container.state.lowercased() == "running" {
            Button("Stop") {
                runDockerCommand(["stop", container.id])
            }
        }
        Button("Restart") {
            runDockerCommand(["restart", container.id])
        }
        Divider()
        Button("View Logs") {
            fetchLogs(for: container)
        }
        Divider()
        Button("Remove", role: .destructive) {
            runDockerCommand(["rm", "-f", container.id])
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task.detached(priority: .background) {
            await checkAndFetch()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                await checkAndFetch()
            }
        }
    }

    private func refreshNow() {
        Task.detached(priority: .userInitiated) {
            await checkAndFetch()
        }
    }

    // MARK: - Docker Checks

    @MainActor
    private func checkAndFetch() async {
        let dockerPath = await resolveDockerPath()
        guard let path = dockerPath else {
            dockerAvailable = false
            daemonRunning = false
            isLoading = false
            return
        }
        dockerAvailable = true

        let (output, exitCode) = await runProcess(path, arguments: ["ps", "-a",
            "--format", "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.State}}"])

        if exitCode != 0 {
            // daemon not running typically gives a non-zero exit
            daemonRunning = false
            isLoading = false
            return
        }

        daemonRunning = true
        containers = parseContainers(output)
        isLoading = false
    }

    // MARK: - Docker Actions

    private func runDockerCommand(_ args: [String]) {
        Task.detached(priority: .background) {
            guard let path = await resolveDockerPath() else { return }
            _ = await runProcess(path, arguments: args)
            // Refresh after action
            try? await Task.sleep(nanoseconds: 500_000_000)
            await checkAndFetch()
        }
    }

    private func fetchLogs(for container: ContainerInfo) {
        Task.detached(priority: .background) {
            guard let path = await resolveDockerPath() else { return }
            let (output, _) = await runProcess(path, arguments: ["logs", "--tail", "100", container.id])
            await MainActor.run {
                logOutput = output.isEmpty ? "(no output)" : output
                logContainerName = container.name
            }
        }
    }

    // MARK: - Helpers

    /// GUI 앱은 PATH가 제한적이므로 일반적인 docker 설치 경로를 직접 탐색
    private func resolveDockerPath() async -> String? {
        let candidates = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker",
            NSHomeDirectory() + "/.docker/bin/docker",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // fallback: which
        let (output, exitCode) = await runProcess("/usr/bin/which", arguments: ["docker"])
        guard exitCode == 0 else { return nil }
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private func parseContainers(_ output: String) -> [ContainerInfo] {
        DockerPanelParser.parseContainers(output)
    }
}

// MARK: - Parser (internal for testing)

enum DockerPanelParser {
    /// `docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.State}}"` 출력을
    /// `[ContainerInfo]` 배열로 변환한다.
    static func parseContainers(_ output: String) -> [ContainerInfo] {
        output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> ContainerInfo? in
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 6 else { return nil }
                return ContainerInfo(
                    id: parts[0],
                    name: parts[1],
                    image: parts[2],
                    status: parts[3],
                    ports: parts[4],
                    state: parts[5]
                )
            }
    }
}

// MARK: - Process Helper (free function)

/// ProcessRunner를 비동기 컨텍스트에서 사용하기 위한 래퍼.
/// terminationHandler 안에서 readDataToEndOfFile()을 호출하는 패턴을 피해
/// 파이프 버퍼 초과 시 발생하는 데드락을 방지한다.
private func runProcess(_ launchPath: String, arguments: [String]) async -> (String, Int32) {
    await Task.detached(priority: .utility) {
        let result = ProcessRunner.run(launchPath, arguments: arguments)
        return (result.output ?? "", result.exitCode)
    }.value
}

// MARK: - Log Sheet

private struct LogSheet: Identifiable {
    let id = UUID()
    let name: String
    let output: String
}

private struct LogSheetView: View {
    let containerName: String
    let output: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Logs: \(containerName)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                Text(output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
        .frame(minWidth: 500, minHeight: 350)
    }
}
