import SwiftUI
import Foundation

// MARK: - Model

struct CommandSnippet: Identifiable, Codable, Sendable {
    var id: UUID
    var name: String
    var command: String
    var category: String?
    var createdAt: Date

    init(id: UUID = UUID(), name: String, command: String, category: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.command = command
        self.category = category
        self.createdAt = createdAt
    }
}

// MARK: - Store

@Observable
final class SnippetStore {
    var snippets: [CommandSnippet] = []

    private static let storageURL: URL = {
        return AppPath.appSupport.appendingPathComponent("snippets.json")
    }()

    init() {
        load()
        if snippets.isEmpty {
            snippets = Self.defaultSnippets
            save()
        }
    }

    // MARK: Mutations

    func add(_ snippet: CommandSnippet) {
        snippets.append(snippet)
        save()
    }

    func remove(at offsets: IndexSet) {
        snippets.remove(atOffsets: offsets)
        save()
    }

    func remove(id: UUID) {
        snippets.removeAll { $0.id == id }
        save()
    }

    func reorder(from source: IndexSet, to destination: Int) {
        snippets.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func update(_ snippet: CommandSnippet) {
        if let idx = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[idx] = snippet
            save()
        }
    }

    // MARK: Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.storageURL)
            snippets = try JSONDecoder().decode([CommandSnippet].self, from: data)
        } catch {
            GeobukLogger.error(.app, "Snippet load failed", error: error)
            snippets = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(snippets)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            GeobukLogger.error(.app, "Snippet save failed", error: error)
        }
    }

    // MARK: Defaults

    private static let defaultSnippets: [CommandSnippet] = [
        // Git
        CommandSnippet(name: "git status", command: "git status", category: "Git"),
        CommandSnippet(name: "git log (oneline)", command: "git log --oneline -20", category: "Git"),
        CommandSnippet(name: "git pull", command: "git pull", category: "Git"),
        CommandSnippet(name: "git push", command: "git push", category: "Git"),
        CommandSnippet(name: "git stash", command: "git stash", category: "Git"),
        CommandSnippet(name: "git stash pop", command: "git stash pop", category: "Git"),
        CommandSnippet(name: "git diff staged", command: "git diff --staged", category: "Git"),
        CommandSnippet(name: "git branch list", command: "git branch -a", category: "Git"),
        // npm
        CommandSnippet(name: "npm install", command: "npm install", category: "npm"),
        CommandSnippet(name: "npm run dev", command: "npm run dev", category: "npm"),
        CommandSnippet(name: "npm run build", command: "npm run build", category: "npm"),
        CommandSnippet(name: "npm run test", command: "npm run test", category: "npm"),
        CommandSnippet(name: "npm outdated", command: "npm outdated", category: "npm"),
        // Docker
        CommandSnippet(name: "docker ps", command: "docker ps", category: "Docker"),
        CommandSnippet(name: "docker compose up", command: "docker compose up -d", category: "Docker"),
        CommandSnippet(name: "docker compose down", command: "docker compose down", category: "Docker"),
        CommandSnippet(name: "docker images", command: "docker images", category: "Docker"),
        // System
        CommandSnippet(name: "disk usage", command: "df -h", category: "System"),
        CommandSnippet(name: "list ports", command: "lsof -i -P -n | grep LISTEN", category: "System"),
        CommandSnippet(name: "top processes", command: "ps aux --sort=-%cpu | head -20", category: "System"),
    ]
}

// MARK: - View

struct SnippetPanelView: View {
    var onExecute: ((String) -> Void)?

    @State private var store = SnippetStore()
    @State private var searchText: String = ""
    @State private var isAdding: Bool = false
    @State private var newName: String = ""
    @State private var newCommand: String = ""
    @State private var newCategory: String = ""
    @State private var editingSnippet: CommandSnippet? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()

            if isAdding {
                addForm
                Divider()
            }

            snippetList
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Snippets")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Spacer()

            Text(verbatim: "\(store.snippets.count)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isAdding.toggle()
                    if !isAdding { resetAddForm() }
                }
            } label: {
                Image(systemName: isAdding ? "xmark" : "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isAdding ? .secondary : .accentColor)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(isAdding ? "Cancel" : "Add Snippet")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextField("Filter snippets...", text: $searchText)
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
    }

    // MARK: - Add Form

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New Snippet")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            TextField("Command", text: $newCommand)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

            TextField("Category (optional)", text: $newCategory)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            HStack {
                Spacer()
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isAdding = false
                        resetAddForm()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

                Button("Add") {
                    commitAdd()
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 12))
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty ||
                          newCommand.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.05))
    }

    // MARK: - Snippet List

    private var snippetList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let filtered = filteredSnippets()

                if filtered.isEmpty {
                    Text(searchText.isEmpty ? "No snippets yet" : "No matching snippets")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    let grouped = groupedSnippets(filtered)

                    ForEach(grouped, id: \.0) { category, items in
                        if let cat = category {
                            sectionHeader(cat)
                        }
                        ForEach(items) { snippet in
                            snippetRow(snippet)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Snippet Row

    @ViewBuilder
    private func snippetRow(_ snippet: CommandSnippet) -> some View {
        if editingSnippet?.id == snippet.id {
            editRowView(snippet)
        } else {
            normalRowView(snippet)
        }
    }

    private func normalRowView(_ snippet: CommandSnippet) -> some View {
        Button {
            onExecute?(snippet.command)
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(snippet.command)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Execute") {
                onExecute?(snippet.command)
            }
            Button("Edit") {
                editingSnippet = snippet
            }
            Button("Copy Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(snippet.command, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) {
                store.remove(id: snippet.id)
            }
        }
    }

    private func editRowView(_ snippet: CommandSnippet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name", text: Binding(
                get: { editingSnippet?.name ?? snippet.name },
                set: { editingSnippet?.name = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12))

            TextField("Command", text: Binding(
                get: { editingSnippet?.command ?? snippet.command },
                set: { editingSnippet?.command = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12, design: .monospaced))

            TextField("Category (optional)", text: Binding(
                get: { editingSnippet?.category ?? "" },
                set: { editingSnippet?.category = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12))

            HStack {
                Spacer()
                Button("Cancel") {
                    editingSnippet = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

                Button("Save") {
                    if let edited = editingSnippet {
                        store.update(edited)
                    }
                    editingSnippet = nil
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 12))
                .disabled(editingSnippet?.name.trimmingCharacters(in: .whitespaces).isEmpty ?? true ||
                          editingSnippet?.command.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.05))
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    // MARK: - Data Helpers

    private func filteredSnippets() -> [CommandSnippet] {
        guard !searchText.isEmpty else { return store.snippets }
        let query = searchText.lowercased()
        return store.snippets.filter {
            $0.name.lowercased().contains(query) ||
            $0.command.lowercased().contains(query) ||
            ($0.category?.lowercased().contains(query) ?? false)
        }
    }

    /// Returns [(category, snippets)] — uncategorized items appear under nil key last.
    private func groupedSnippets(_ snippets: [CommandSnippet]) -> [(String?, [CommandSnippet])] {
        // Check whether any snippet has a category
        let hasCategorized = snippets.contains { $0.category != nil }
        guard hasCategorized else {
            return [(nil, snippets)]
        }

        var order: [String] = []
        var dict: [String: [CommandSnippet]] = [:]
        var uncategorized: [CommandSnippet] = []

        for snippet in snippets {
            if let cat = snippet.category, !cat.isEmpty {
                if dict[cat] == nil {
                    order.append(cat)
                    dict[cat] = []
                }
                dict[cat]!.append(snippet)
            } else {
                uncategorized.append(snippet)
            }
        }

        var result: [(String?, [CommandSnippet])] = order.map { ($0, dict[$0] ?? []) }
        if !uncategorized.isEmpty {
            result.append((nil, uncategorized))
        }
        return result
    }

    // MARK: - Add Form Helpers

    private func commitAdd() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        let command = newCommand.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !command.isEmpty else { return }
        let category = newCategory.trimmingCharacters(in: .whitespaces)
        let snippet = CommandSnippet(
            name: name,
            command: command,
            category: category.isEmpty ? nil : category
        )
        withAnimation(.easeInOut(duration: 0.15)) {
            store.add(snippet)
            isAdding = false
            resetAddForm()
        }
    }

    private func resetAddForm() {
        newName = ""
        newCommand = ""
        newCategory = ""
    }
}
