import SwiftUI

/// 프로세스 패널 — TTY 보유 프로세스의 CPU/메모리/포트/실행 명령어 표시
struct ProcessPanelView: View {
    var provider: TerminalProcessProvider
    var systemMonitor: SystemMonitor?

    /// 섹션 접기/펼치기 상태
    @State private var expandedSections: Set<String> = ["cpu", "memory", "ports", "running"]

    /// 각 섹션 최대 표시 수
    private static let maxItemsPerSection = 8

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("Processes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text(verbatim: "\(provider.processes.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    cpuSection
                    memorySection
                    portsSection
                    runningSection
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - CPU Section

    private var cpuSection: some View {
        collapsibleSection(key: "cpu", title: "CPU", systemImage: "cpu") {
            let items = provider.topByCPU.prefix(Self.maxItemsPerSection)
            if items.isEmpty {
                emptyLabel("No active processes")
            } else {
                ForEach(Array(items)) { proc in
                    processRow(proc) {
                        HStack(spacing: 4) {
                            Text(String(format: "%.1f%%", proc.cpuPercent))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(ColorHelpers.cpuColor(proc.cpuPercent))
                            Text(proc.formattedUptime)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Memory Section

    private var memorySection: some View {
        collapsibleSection(key: "memory", title: "Memory", systemImage: "memorychip") {
            let items = provider.topByMemory.prefix(Self.maxItemsPerSection)
            if items.isEmpty {
                emptyLabel("No active processes")
            } else {
                ForEach(Array(items)) { proc in
                    processRow(proc) {
                        HStack(spacing: 4) {
                            Text(SessionFormatter.formatMB(proc.memoryMB))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(ColorHelpers.memoryColor(proc.memoryMB))
                            if !proc.listeningPorts.isEmpty {
                                if let firstPort = proc.listeningPorts.first {
                                Text(verbatim: ":\(firstPort)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ports Section

    private var portsSection: some View {
        collapsibleSection(key: "ports", title: "Ports", systemImage: "network") {
            let items = provider.withPorts
            if items.isEmpty {
                emptyLabel("No listening ports")
            } else {
                ForEach(items) { proc in
                    ForEach(proc.listeningPorts, id: \.self) { port in
                        HStack(spacing: 6) {
                            Text(verbatim: ":\(port)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.blue)

                            Text(proc.name)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                openInBrowser(port: port)
                            } label: {
                                Text("Open")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    // MARK: - Running Commands Section

    private var runningSection: some View {
        collapsibleSection(key: "running", title: "Long Running", systemImage: "clock") {
            let items = provider.longRunning.prefix(Self.maxItemsPerSection)
            if items.isEmpty {
                emptyLabel("No long-running processes")
            } else {
                ForEach(Array(items)) { proc in
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(proc.command)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Text("PID \(proc.pid) · \(proc.tty)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(proc.formattedUptime)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .contextMenu {
                        Button("Kill Process") {
                            kill(proc.pid, SIGTERM)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func collapsibleSection<Content: View>(
        key: String,
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expandedSections.contains(key) {
                        expandedSections.remove(key)
                    } else {
                        expandedSections.insert(key)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: expandedSections.contains(key) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    Image(systemName: systemImage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if expandedSections.contains(key) {
                content()
            }
        }
    }

    @ViewBuilder
    private func processRow<Trailing: View>(
        _ proc: TerminalProcess,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(proc.name)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                let execPath = extractExecPath(from: proc.command)
                if let execPath, execPath != proc.name {
                    Text(execPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .contextMenu {
            Button("Kill Process (SIGTERM)") { kill(proc.pid, SIGTERM) }
            Button("Force Kill (SIGKILL)") { kill(proc.pid, SIGKILL) }
            Divider()
            Text("PID: \(proc.pid)")
            Text("TTY: \(proc.tty)")
            Text("Command: \(proc.command)")
        }
    }

    private func extractExecPath(from command: String) -> String? {
        let firstArg = command.split(separator: " ").first.map(String.init) ?? command
        guard firstArg.contains("/") else { return nil }
        return firstArg
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(.secondary.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func openInBrowser(port: UInt16) {
        let url = URL(string: "http://localhost:\(port)")!
        NSWorkspace.shared.open(url)
    }
}
