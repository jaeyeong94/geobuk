import SwiftUI

/// 환경변수 패널 — 현재 셸의 주요 환경변수 표시
struct EnvironmentPanelView: View {
    var surfaceView: GhosttySurfaceView?

    /// 검색 필터
    @State private var searchText: String = ""

    /// 주요 환경변수 (우선 표시)
    private static let highlightedKeys: Set<String> = [
        "PATH", "HOME", "SHELL", "USER", "LANG",
        "NODE_ENV", "GOPATH", "GOROOT", "JAVA_HOME", "PYTHONPATH",
        "AWS_PROFILE", "AWS_REGION", "DOCKER_HOST",
        "EDITOR", "VISUAL", "TERM", "COLORTERM",
        "XDG_CONFIG_HOME", "XDG_DATA_HOME",
        "SSH_AUTH_SOCK", "GPG_TTY",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("Environment")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // 검색
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Filter...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // 환경변수 목록
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let env = filteredEnvironment()

                    if env.isEmpty {
                        Text("No matching variables")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    } else {
                        // 주요 변수를 먼저, 나머지는 알파벳 순
                        let (highlighted, rest) = partitionEnvironment(env)

                        if !highlighted.isEmpty {
                            sectionHeader("Key Variables")
                            ForEach(highlighted, id: \.key) { item in
                                envRow(key: item.key, value: item.value, isHighlighted: true)
                            }
                        }

                        if !rest.isEmpty {
                            if !highlighted.isEmpty {
                                sectionHeader("All Variables")
                            }
                            ForEach(rest, id: \.key) { item in
                                envRow(key: item.key, value: item.value, isHighlighted: false)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func envRow(key: String, value: String, isHighlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(isHighlighted ? .accentColor : .primary)

            // PATH는 : 로 분리하여 줄바꿈 표시
            if key == "PATH" {
                let paths = value.components(separatedBy: ":")
                ForEach(Array(paths.prefix(8).enumerated()), id: \.offset) { _, path in
                    Text(path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if paths.count > 8 {
                    Text("… +\(paths.count - 8) more")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            } else {
                Text(value)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Value") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            }
            Button("Copy \(key)=\(value)") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(key)=\(value)", forType: .string)
            }
        }
    }

    // MARK: - Data

    private func filteredEnvironment() -> [(key: String, value: String)] {
        let env = ProcessInfo.processInfo.environment
        let sorted = env.sorted { $0.key < $1.key }

        if searchText.isEmpty { return sorted }
        let query = searchText.lowercased()
        return sorted.filter {
            $0.key.lowercased().contains(query) || $0.value.lowercased().contains(query)
        }
    }

    private func partitionEnvironment(_ env: [(key: String, value: String)]) -> ([(key: String, value: String)], [(key: String, value: String)]) {
        var highlighted: [(key: String, value: String)] = []
        var rest: [(key: String, value: String)] = []

        for item in env {
            if Self.highlightedKeys.contains(item.key) {
                highlighted.append(item)
            } else {
                rest.append(item)
            }
        }

        return (highlighted, rest)
    }
}
