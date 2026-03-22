import SwiftUI

// MARK: - Model

/// 프로젝트 스크립트 항목
struct ProjectScript: Identifiable {
    let id = UUID()
    let name: String
    let command: String
    let source: String  // 소스 파일명 (e.g. "package.json", "Makefile")
}

// MARK: - View

/// 프로젝트 스크립트 패널 — package.json, Makefile 등에서 실행 가능한 스크립트 표시
struct ScriptsPanelView: View {
    var currentDirectory: String?
    var onExecute: ((String) -> Void)?

    @State private var scripts: [ProjectScript] = []
    @State private var searchText: String = ""
    @State private var collapsedSections: Set<String> = []
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("Scripts")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                let sourceCount = Set(scripts.map(\.source)).count
                if sourceCount > 0 {
                    Text(verbatim: "\(sourceCount) file\(sourceCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // 검색
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Filter scripts...", text: $searchText)
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

            // 스크립트 목록
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let filtered = filteredScripts()

                    if isLoading {
                        Text("Scanning...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    } else if filtered.isEmpty && scripts.isEmpty {
                        Text("No project scripts found")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    } else if filtered.isEmpty {
                        Text("No matching scripts")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    } else {
                        let grouped = groupedScripts(filtered)
                        ForEach(grouped.keys.sorted(), id: \.self) { source in
                            if let group = grouped[source] {
                                scriptGroup(source: source, scripts: group)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            loadScripts()
        }
        .onChange(of: currentDirectory) { _ in
            loadScripts()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func scriptGroup(source: String, scripts: [ProjectScript]) -> some View {
        let isCollapsed = collapsedSections.contains(source)

        VStack(alignment: .leading, spacing: 0) {
            // 섹션 헤더 (접기/펼치기)
            Button(action: { toggleSection(source) }) {
                HStack(spacing: 4) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(source)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.none)
                    Spacer()
                    Text("\(scripts.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 3)

            if !isCollapsed {
                ForEach(scripts) { script in
                    scriptRow(script)
                }
            }
        }
    }

    private func scriptRow(_ script: ProjectScript) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(script.name)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(script.command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onExecute?(script.command)
        }
        .contextMenu {
            Button("Run") {
                onExecute?(script.command)
            }
            Button("Copy Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(script.command, forType: .string)
            }
        }
    }

    // MARK: - Data

    private func toggleSection(_ source: String) {
        if collapsedSections.contains(source) {
            collapsedSections.remove(source)
        } else {
            collapsedSections.insert(source)
        }
    }

    private func filteredScripts() -> [ProjectScript] {
        guard !searchText.isEmpty else { return scripts }
        let query = searchText.lowercased()
        return scripts.filter {
            $0.name.lowercased().contains(query) ||
            $0.command.lowercased().contains(query) ||
            $0.source.lowercased().contains(query)
        }
    }

    private func groupedScripts(_ scripts: [ProjectScript]) -> [String: [ProjectScript]] {
        var result: [String: [ProjectScript]] = [:]
        for script in scripts {
            result[script.source, default: []].append(script)
        }
        return result
    }

    private func loadScripts() {
        guard let dir = currentDirectory, !dir.isEmpty else {
            scripts = []
            return
        }

        isLoading = true
        let directory = dir

        Task.detached(priority: .userInitiated) {
            let found = Self.scanScripts(in: directory)
            await MainActor.run {
                scripts = found
                isLoading = false
            }
        }
    }

    // MARK: - Parsing (nonisolated static)

    nonisolated static func scanScripts(in directory: String) -> [ProjectScript] {
        var result: [ProjectScript] = []

        // package.json
        let packageJsonPath = directory + "/package.json"
        if FileManager.default.fileExists(atPath: packageJsonPath) {
            result += parsePackageJson(at: packageJsonPath)
        }

        // Makefile
        let makefilePath = directory + "/Makefile"
        if FileManager.default.fileExists(atPath: makefilePath) {
            result += parseMakefile(at: makefilePath)
        }

        // Cargo.toml
        let cargoTomlPath = directory + "/Cargo.toml"
        if FileManager.default.fileExists(atPath: cargoTomlPath) {
            result += cargoScripts()
        }

        // pyproject.toml
        let pyprojectPath = directory + "/pyproject.toml"
        if FileManager.default.fileExists(atPath: pyprojectPath) {
            result += parsePyprojectToml(at: pyprojectPath)
        }

        // go.mod
        let goModPath = directory + "/go.mod"
        if FileManager.default.fileExists(atPath: goModPath) {
            result += goScripts()
        }

        return result
    }

    /// package.json의 "scripts" 객체를 파싱하여 `npm run <name>` 커맨드 생성
    nonisolated static func parsePackageJson(at path: String) -> [ProjectScript] {
        guard
            let data = FileManager.default.contents(atPath: path),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let scriptsDict = json["scripts"] as? [String: Any]
        else { return [] }

        return scriptsDict.keys.sorted().map { name in
            ProjectScript(name: name, command: "npm run \(name)", source: "package.json")
        }
    }

    /// Makefile의 타겟 라인(`^[a-zA-Z_-]+:`)을 파싱하여 `make <target>` 커맨드 생성
    nonisolated static func parseMakefile(at path: String) -> [ProjectScript] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }

        // 내부 타겟으로 취급하여 제외할 키워드
        let internalTargets: Set<String> = ["all", "clean", "install", "uninstall", "dist", "distclean"]

        var targets: [String] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            // `.PHONY`, `.DEFAULT` 등 점으로 시작하는 타겟 제외
            guard !line.hasPrefix(".") else { continue }

            // 타겟 라인: `target:` 또는 `target: deps`
            let pattern = #"^([a-zA-Z_][a-zA-Z0-9_\-]*):"#
            if let range = line.range(of: pattern, options: .regularExpression) {
                let target = String(line[range].dropLast()) // 콜론 제거
                // 내부 타겟 및 중복 제외
                if !internalTargets.contains(target) && !targets.contains(target) {
                    targets.append(target)
                }
            }
        }

        return targets.map { target in
            ProjectScript(name: target, command: "make \(target)", source: "Makefile")
        }
    }

    /// Cargo.toml 존재 시 기본 cargo 커맨드 반환
    nonisolated static func cargoScripts() -> [ProjectScript] {
        [
            ProjectScript(name: "build", command: "cargo build", source: "Cargo.toml"),
            ProjectScript(name: "run", command: "cargo run", source: "Cargo.toml"),
            ProjectScript(name: "test", command: "cargo test", source: "Cargo.toml"),
            ProjectScript(name: "bench", command: "cargo bench", source: "Cargo.toml"),
        ]
    }

    /// pyproject.toml의 [tool.poetry.scripts] 또는 [project.scripts] 섹션 파싱
    nonisolated static func parsePyprojectToml(at path: String) -> [ProjectScript] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }

        var scripts: [ProjectScript] = []
        var inScriptsSection = false
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 섹션 헤더 감지
            if trimmed.hasPrefix("[") {
                let header = trimmed.lowercased()
                inScriptsSection = header == "[tool.poetry.scripts]" || header == "[project.scripts]"
                continue
            }

            // 스크립트 섹션 내 항목 파싱: `name = "module:func"` 형식
            if inScriptsSection {
                if trimmed.isEmpty { break }
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    let name = parts[0].trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty && !name.hasPrefix("#") {
                        scripts.append(ProjectScript(name: name, command: name, source: "pyproject.toml"))
                    }
                }
            }
        }

        // 스크립트 항목이 없으면 기본 커맨드 제공
        if scripts.isEmpty {
            scripts = [
                ProjectScript(name: "install", command: "pip install -e .", source: "pyproject.toml"),
                ProjectScript(name: "test", command: "pytest", source: "pyproject.toml"),
            ]
        }

        return scripts
    }

    /// go.mod 존재 시 기본 go 커맨드 반환
    nonisolated static func goScripts() -> [ProjectScript] {
        [
            ProjectScript(name: "build", command: "go build", source: "go.mod"),
            ProjectScript(name: "test", command: "go test", source: "go.mod"),
            ProjectScript(name: "run", command: "go run .", source: "go.mod"),
        ]
    }
}
