//
//  AutomateTab.swift
//  CozyGit
//

import SwiftUI
import UniformTypeIdentifiers

struct AutomateTab: View {
    let repository: Repository?

    @State private var config: AutomationConfig = AutomationConfig()
    @State private var selectedSection: AutomationSection = .prefixes
    @State private var showAddPrefixSheet: Bool = false
    @State private var showEditPrefixSheet: Bool = false
    @State private var showConfigureHookSheet: Bool = false
    @State private var selectedPrefix: CommitPrefix?
    @State private var selectedHook: ScriptHook?
    @State private var testResult: ScriptResult?
    @State private var showTestResult: Bool = false
    @State private var isSaving: Bool = false

    private let automationService = AutomationService(shellExecutor: DependencyContainer.shared.shellExecutor)

    enum AutomationSection: String, CaseIterable, Identifiable {
        case prefixes = "Commit Prefixes"
        case hooks = "Script Hooks"
        case settings = "Settings"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .prefixes: return "text.badge.plus"
            case .hooks: return "terminal"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        if let repo = repository {
            HSplitView {
                // Sidebar
                sectionSidebar
                    .frame(minWidth: 180, maxWidth: 220)

                // Content
                contentView(for: repo)
            }
            .onAppear {
                config = automationService.loadConfig(for: repo)
            }
            .onChange(of: repository) { _, newRepo in
                if let repo = newRepo {
                    config = automationService.loadConfig(for: repo)
                }
            }
            .sheet(isPresented: $showAddPrefixSheet) {
                AddPrefixSheet { newPrefix in
                    config.prefixes.append(newPrefix)
                    saveConfig()
                }
            }
            .sheet(isPresented: $showEditPrefixSheet) {
                if let prefix = selectedPrefix {
                    EditPrefixSheet(prefix: prefix) { updatedPrefix in
                        config.updatePrefix(updatedPrefix)
                        saveConfig()
                    }
                }
            }
            .sheet(isPresented: $showConfigureHookSheet) {
                if let hook = selectedHook, let repo = repository {
                    ConfigureHookSheet(hook: hook, repository: repo, automationService: automationService) { updatedHook in
                        config.updateHook(updatedHook)
                        saveConfig()
                    }
                }
            }
            .alert("Script Test Result", isPresented: $showTestResult) {
                Button("OK") { }
            } message: {
                if let result = testResult {
                    if result.success {
                        Text("Script executed successfully in \(String(format: "%.2f", result.executionTime))s\n\nOutput:\n\(result.output.isEmpty ? "(no output)" : result.output)")
                    } else {
                        Text("Script failed with exit code \(result.exitCode)\n\nError:\n\(result.error.isEmpty ? result.output : result.error)")
                    }
                }
            }
        } else {
            noRepositoryView
        }
    }

    // MARK: - Section Sidebar

    private var sectionSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Automation")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 12)

            Divider()

            List(AutomationSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.iconName)
                    .tag(section)
            }
            .listStyle(.sidebar)
        }
        .background(.bar)
    }

    // MARK: - Content View

    @ViewBuilder
    private func contentView(for repo: Repository) -> some View {
        switch selectedSection {
        case .prefixes:
            prefixesSection
        case .hooks:
            hooksSection(for: repo)
        case .settings:
            settingsSection
        }
    }

    // MARK: - Prefixes Section

    private var prefixesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Commit Prefixes")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Menu {
                    Button("Add Custom Prefix") {
                        showAddPrefixSheet = true
                    }

                    Divider()

                    Button("Load Conventional Commits") {
                        config.prefixes = CommitPrefix.conventionalCommits
                        saveConfig()
                    }

                    Button("Load Emoji Prefixes") {
                        config.prefixes = CommitPrefix.emojiPrefixes
                        saveConfig()
                    }

                    Divider()

                    Button("Clear All", role: .destructive) {
                        config.prefixes.removeAll()
                        config.selectedPrefixId = nil
                        saveConfig()
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding()
            .background(.bar)

            Divider()

            // Prefix List
            if config.prefixes.isEmpty {
                ContentUnavailableView {
                    Label("No Prefixes", systemImage: "text.badge.plus")
                } description: {
                    Text("Add commit prefixes to automatically format your commit messages")
                } actions: {
                    Button("Add Prefix") {
                        showAddPrefixSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(config.prefixes) { prefix in
                        PrefixRow(
                            prefix: prefix,
                            isSelected: config.selectedPrefixId == prefix.id,
                            onSelect: {
                                if config.selectedPrefixId == prefix.id {
                                    config.selectedPrefixId = nil
                                } else {
                                    config.selectedPrefixId = prefix.id
                                }
                                saveConfig()
                            },
                            onEdit: {
                                selectedPrefix = prefix
                                showEditPrefixSheet = true
                            },
                            onDelete: {
                                config.prefixes.removeAll { $0.id == prefix.id }
                                if config.selectedPrefixId == prefix.id {
                                    config.selectedPrefixId = nil
                                }
                                saveConfig()
                            },
                            onToggle: { enabled in
                                if let index = config.prefixes.firstIndex(where: { $0.id == prefix.id }) {
                                    config.prefixes[index].isEnabled = enabled
                                    saveConfig()
                                }
                            }
                        )
                    }
                    .onMove { from, to in
                        config.prefixes.move(fromOffsets: from, toOffset: to)
                        saveConfig()
                    }
                }
            }
        }
    }

    // MARK: - Hooks Section

    private func hooksSection(for repo: Repository) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Script Hooks")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text("Configure scripts to run at various Git events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.bar)

            Divider()

            // Hooks List
            List {
                ForEach(HookEvent.allCases) { event in
                    if let hook = config.hook(for: event) {
                        HookRow(
                            hook: hook,
                            onConfigure: {
                                selectedHook = hook
                                showConfigureHookSheet = true
                            },
                            onToggle: { enabled in
                                var updatedHook = hook
                                updatedHook.isEnabled = enabled
                                config.updateHook(updatedHook)
                                saveConfig()
                            },
                            onTest: {
                                Task {
                                    if let scriptPath = hook.scriptPath {
                                        testResult = await automationService.testScript(at: scriptPath, in: repo)
                                        showTestResult = true
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Automation Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(.bar)

            Divider()

            Form {
                Section("Commit Prefixes") {
                    Toggle("Auto-apply selected prefix", isOn: $config.autoApplyPrefix)
                        .onChange(of: config.autoApplyPrefix) { _, _ in saveConfig() }

                    Toggle("Show prefix selector in commit dialog", isOn: $config.showPrefixInCommitDialog)
                        .onChange(of: config.showPrefixInCommitDialog) { _, _ in saveConfig() }
                }

                Section("Configuration File") {
                    HStack {
                        Text("Config location:")
                        Spacer()
                        Text(AutomationConfig.configFileName)
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }

                    Text("Configuration is stored in the repository root as a JSON file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        ContentUnavailableView {
            Label("No Repository Open", systemImage: "gearshape.2")
        } description: {
            Text("Open a repository to configure automation")
        }
    }

    // MARK: - Helpers

    private func saveConfig() {
        guard let repo = repository else { return }
        isSaving = true
        do {
            try automationService.saveConfig(config, for: repo)
        } catch {
            // Log error but don't show alert for every save
            print("Failed to save automation config: \(error)")
        }
        isSaving = false
    }
}

// MARK: - Prefix Row

private struct PrefixRow: View {
    let prefix: CommitPrefix
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: (Bool) -> Void

    @State private var isEnabled: Bool

    init(prefix: CommitPrefix, isSelected: Bool, onSelect: @escaping () -> Void, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void, onToggle: @escaping (Bool) -> Void) {
        self.prefix = prefix
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggle = onToggle
        self._isEnabled = State(initialValue: prefix.isEnabled)
    }

    var body: some View {
        HStack {
            // Selection indicator
            Button {
                onSelect()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(isSelected ? "Default prefix" : "Set as default")

            // Prefix badge
            Text(prefix.prefix)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(prefixColor.opacity(0.2))
                .foregroundStyle(prefixColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(prefix.name)
                    .fontWeight(.medium)

                if !prefix.description.isEmpty {
                    Text(prefix.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { _, newValue in
                    onToggle(newValue)
                }

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var prefixColor: Color {
        switch prefix.color {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .cyan: return .cyan
        case .indigo: return .indigo
        case .brown: return .brown
        case .gray: return .gray
        }
    }
}

// MARK: - Hook Row

private struct HookRow: View {
    let hook: ScriptHook
    let onConfigure: () -> Void
    let onToggle: (Bool) -> Void
    let onTest: () -> Void

    @State private var isEnabled: Bool

    init(hook: ScriptHook, onConfigure: @escaping () -> Void, onToggle: @escaping (Bool) -> Void, onTest: @escaping () -> Void) {
        self.hook = hook
        self.onConfigure = onConfigure
        self.onToggle = onToggle
        self.onTest = onTest
        self._isEnabled = State(initialValue: hook.isEnabled)
    }

    var body: some View {
        HStack {
            Image(systemName: hook.event.iconName)
                .foregroundStyle(hook.event.isPre ? .orange : .green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(hook.event.displayName)
                    .fontWeight(.medium)

                Text(hook.event.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if hook.isConfigured {
                Text(hook.scriptPath?.lastPathComponent ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if hook.blockOnError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help("Blocks operation on error")
                }

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .onChange(of: isEnabled) { _, newValue in
                        onToggle(newValue)
                    }

                Button {
                    onTest()
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .disabled(!hook.isEnabled)
                .help("Test script")
            } else {
                Text("Not configured")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                onConfigure()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Configure hook")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Prefix Sheet

private struct AddPrefixSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (CommitPrefix) -> Void

    @State private var name: String = ""
    @State private var prefix: String = ""
    @State private var description: String = ""
    @State private var color: PrefixColor = .gray

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Commit Prefix")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                TextField("Prefix", text: $prefix)
                    .font(.system(.body, design: .monospaced))
                TextField("Description", text: $description)

                Picker("Color", selection: $color) {
                    ForEach(PrefixColor.allCases) { c in
                        HStack {
                            Circle()
                                .fill(colorFor(c))
                                .frame(width: 12, height: 12)
                            Text(c.rawValue.capitalized)
                        }
                        .tag(c)
                    }
                }
            }

            // Preview
            if !prefix.isEmpty {
                HStack {
                    Text("Preview:")
                        .foregroundStyle(.secondary)
                    Text("\(prefix) Your commit message")
                        .font(.system(.body, design: .monospaced))
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    let newPrefix = CommitPrefix(
                        name: name,
                        prefix: prefix,
                        description: description,
                        color: color
                    )
                    onAdd(newPrefix)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || prefix.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func colorFor(_ c: PrefixColor) -> Color {
        switch c {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .cyan: return .cyan
        case .indigo: return .indigo
        case .brown: return .brown
        case .gray: return .gray
        }
    }
}

// MARK: - Edit Prefix Sheet

private struct EditPrefixSheet: View {
    @Environment(\.dismiss) private var dismiss
    let prefix: CommitPrefix
    let onSave: (CommitPrefix) -> Void

    @State private var name: String
    @State private var prefixText: String
    @State private var description: String
    @State private var color: PrefixColor

    init(prefix: CommitPrefix, onSave: @escaping (CommitPrefix) -> Void) {
        self.prefix = prefix
        self.onSave = onSave
        self._name = State(initialValue: prefix.name)
        self._prefixText = State(initialValue: prefix.prefix)
        self._description = State(initialValue: prefix.description)
        self._color = State(initialValue: prefix.color)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Commit Prefix")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                TextField("Prefix", text: $prefixText)
                    .font(.system(.body, design: .monospaced))
                TextField("Description", text: $description)

                Picker("Color", selection: $color) {
                    ForEach(PrefixColor.allCases) { c in
                        HStack {
                            Circle()
                                .fill(colorFor(c))
                                .frame(width: 12, height: 12)
                            Text(c.rawValue.capitalized)
                        }
                        .tag(c)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let updatedPrefix = CommitPrefix(
                        id: prefix.id,
                        name: name,
                        prefix: prefixText,
                        description: description,
                        color: color,
                        isEnabled: prefix.isEnabled
                    )
                    onSave(updatedPrefix)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || prefixText.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func colorFor(_ c: PrefixColor) -> Color {
        switch c {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .cyan: return .cyan
        case .indigo: return .indigo
        case .brown: return .brown
        case .gray: return .gray
        }
    }
}

// MARK: - Configure Hook Sheet

private struct ConfigureHookSheet: View {
    @Environment(\.dismiss) private var dismiss
    let hook: ScriptHook
    let repository: Repository
    let automationService: AutomationService
    let onSave: (ScriptHook) -> Void

    @State private var scriptPath: URL?
    @State private var isEnabled: Bool
    @State private var blockOnError: Bool
    @State private var timeout: TimeInterval
    @State private var description: String
    @State private var validationError: String?
    @State private var testResult: ScriptResult?
    @State private var isTesting: Bool = false

    init(hook: ScriptHook, repository: Repository, automationService: AutomationService, onSave: @escaping (ScriptHook) -> Void) {
        self.hook = hook
        self.repository = repository
        self.automationService = automationService
        self.onSave = onSave
        self._scriptPath = State(initialValue: hook.scriptPath)
        self._isEnabled = State(initialValue: hook.isEnabled)
        self._blockOnError = State(initialValue: hook.blockOnError)
        self._timeout = State(initialValue: hook.timeout)
        self._description = State(initialValue: hook.description)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: hook.event.iconName)
                    .foregroundStyle(hook.event.isPre ? .orange : .green)
                Text(hook.event.displayName)
                    .font(.headline)
            }

            Text(hook.event.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Form {
                // Script Path
                HStack {
                    if let path = scriptPath {
                        Text(path.path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("No script selected")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Browse...") {
                        selectScript()
                    }

                    if scriptPath != nil {
                        Button {
                            scriptPath = nil
                            validationError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Toggle("Enable hook", isOn: $isEnabled)

                Toggle("Block operation on error", isOn: $blockOnError)
                    .help("If the script fails, prevent the Git operation from continuing")

                HStack {
                    Text("Timeout:")
                    TextField("", value: $timeout, format: .number)
                        .frame(width: 60)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }

                TextField("Description (optional)", text: $description)
            }

            // Test Section
            if scriptPath != nil {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button {
                            testScript()
                        } label: {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Test Script", systemImage: "play.fill")
                            }
                        }
                        .disabled(isTesting)

                        Spacer()
                    }

                    if let result = testResult {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(result.success ? .green : .red)
                                    Text(result.success ? "Success" : "Failed (exit code \(result.exitCode))")
                                    Spacer()
                                    Text("\(String(format: "%.2f", result.executionTime))s")
                                        .foregroundStyle(.secondary)
                                }

                                if !result.output.isEmpty || !result.error.isEmpty {
                                    Divider()
                                    ScrollView {
                                        Text(result.error.isEmpty ? result.output : result.error)
                                            .font(.system(.caption, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(maxHeight: 100)
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let updatedHook = ScriptHook(
                        id: hook.id,
                        event: hook.event,
                        scriptPath: scriptPath,
                        isEnabled: isEnabled,
                        blockOnError: blockOnError,
                        timeout: timeout,
                        description: description
                    )
                    onSave(updatedHook)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500)
    }

    private func selectScript() {
        let panel = NSOpenPanel()
        panel.title = "Select Script"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.shellScript, .pythonScript, .unixExecutable, .item]

        if panel.runModal() == .OK, let url = panel.url {
            let validation = automationService.validateScript(at: url)
            if validation.isValid {
                scriptPath = url
                validationError = nil
            } else {
                validationError = validation.error
                scriptPath = url // Still set path so user can see it
            }
        }
    }

    private func testScript() {
        guard let path = scriptPath else { return }

        isTesting = true
        Task {
            testResult = await automationService.testScript(at: path, in: repository)
            isTesting = false
        }
    }
}

// MARK: - Preview

#Preview("With Repository") {
    AutomateTab(repository: Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    ))
    .frame(width: 800, height: 600)
}

#Preview("No Repository") {
    AutomateTab(repository: nil)
        .frame(width: 800, height: 600)
}
