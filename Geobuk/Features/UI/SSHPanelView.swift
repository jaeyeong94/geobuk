import SwiftUI

struct SSHHostInfo: Identifiable {
    let id = UUID()
    let host: String
    let hostname: String
    let user: String
    let port: String
    let identityFile: String
}

struct SSHPanelView: View {
    var onConnect: ((String) -> Void)?

    @State private var hosts: [SSHHostInfo] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false

    private var filteredHosts: [SSHHostInfo] {
        if searchText.isEmpty {
            return hosts
        }
        return hosts.filter {
            $0.host.localizedCaseInsensitiveContains(searchText)
            || $0.hostname.localizedCaseInsensitiveContains(searchText)
            || $0.user.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()
            searchField
            Divider()
            contentView
        }
        .onAppear {
            loadHosts()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 6) {
            Text("SSH Hosts")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            if !hosts.isEmpty {
                Text("\(hosts.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            Button(action: loadHosts) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reload SSH config")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextField("Filter hosts…", text: $searchText)
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.plain)

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
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.6)
                Spacer()
            }
        } else if filteredHosts.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredHosts) { host in
                        SSHHostRowView(host: host, onConnect: onConnect)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "server.rack")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            if hosts.isEmpty {
                Text("No SSH hosts configured")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Edit ~/.ssh/config to add hosts")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            } else {
                Text("No matching hosts")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }

    // MARK: - Parsing

    private func loadHosts() {
        isLoading = true
        hosts = parseSSHConfig()
        isLoading = false
    }

    private func parseSSHConfig() -> [SSHHostInfo] {
        let configPath = NSString(string: "~/.ssh/config").expandingTildeInPath
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return []
        }
        return SSHPanelView.parseSSHConfigContent(content)
    }

    /// Parses the text content of an SSH config file and returns the list of hosts.
    /// Extracted as a static method to enable unit testing without filesystem access.
    static func parseSSHConfigContent(_ content: String) -> [SSHHostInfo] {
        var results: [SSHHostInfo] = []

        var currentHost: String?
        var currentHostname: String?
        var currentUser: String?
        var currentPort: String?
        var currentIdentityFile: String?

        func flushCurrent() {
            guard let host = currentHost, host != "*", !host.contains("*") else {
                return
            }
            results.append(SSHHostInfo(
                host: host,
                hostname: currentHostname ?? host,
                user: currentUser ?? "",
                port: currentPort ?? "22",
                identityFile: currentIdentityFile ?? ""
            ))
        }

        let lines = content.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }

            let keyword = parts[0].lowercased()
            let value = parts[1...].joined(separator: " ")

            switch keyword {
            case "host":
                flushCurrent()
                currentHost = value
                currentHostname = nil
                currentUser = nil
                currentPort = nil
                currentIdentityFile = nil
            case "hostname":
                currentHostname = value
            case "user":
                currentUser = value
            case "port":
                currentPort = value
            case "identityfile":
                currentIdentityFile = value
            default:
                break
            }
        }
        flushCurrent()

        return results
    }
}

// MARK: - Row View

private struct SSHHostRowView: View {
    let host: SSHHostInfo
    var onConnect: ((String) -> Void)?

    @State private var isHovered = false

    private var sshCommand: String {
        if host.user.isEmpty {
            return "ssh \(host.hostname)"
        }
        return "ssh \(host.user)@\(host.hostname)"
    }

    private var displayAddress: String {
        let userPart = host.user.isEmpty ? "" : "\(host.user)@"
        let portPart = host.port == "22" ? "" : ":\(host.port)"
        return "\(userPart)\(host.hostname)\(portPart)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(host.host)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(displayAddress)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)

            if !host.identityFile.isEmpty {
                Text(host.identityFile)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.gray.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onConnect?(sshCommand)
        }
        .contextMenu {
            Button("Connect") {
                onConnect?(sshCommand)
            }
            Button("Copy SSH Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(sshCommand, forType: .string)
            }
            Button("Copy Host") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(host.host, forType: .string)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SSHPanelView { command in
        print("Connect: \(command)")
    }
    .frame(width: 220, height: 400)
}
