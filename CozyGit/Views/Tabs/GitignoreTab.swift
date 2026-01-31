//
//  GitignoreTab.swift
//  CozyGit
//

import SwiftUI

struct GitignoreTab: View {
    @Bindable var viewModel: RepositoryViewModel

    @State private var editedContent: String = ""
    @State private var isEditing: Bool = false
    @State private var showAddPatternSheet: Bool = false
    @State private var showTemplateSheet: Bool = false
    @State private var selectedPattern: IgnorePattern?
    @State private var searchText: String = ""

    var body: some View {
        HSplitView {
            // Left: Pattern List
            patternListView
                .frame(minWidth: 300, idealWidth: 350)

            // Right: Editor and Actions
            VStack(spacing: 0) {
                editorToolbar
                editorView
            }
            .frame(minWidth: 400)
        }
        .onAppear {
            loadContent()
        }
        .onChange(of: viewModel.ignoreFile) { _, _ in
            if !isEditing {
                loadContent()
            }
        }
        .sheet(isPresented: $showAddPatternSheet) {
            AddPatternSheet { pattern in
                Task {
                    try? await viewModel.addIgnorePattern(pattern)
                }
            }
        }
        .sheet(isPresented: $showTemplateSheet) {
            TemplateSheet { patterns in
                Task {
                    try? await viewModel.addIgnorePatterns(patterns)
                }
            }
        }
    }

    // MARK: - Pattern List

    private var patternListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Patterns")
                    .font(.headline)
                Spacer()
                Text("\(activePatterns.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search patterns...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.background)

            Divider()

            // Pattern list
            if let ignoreFile = viewModel.ignoreFile {
                if ignoreFile.exists {
                    List(filteredPatterns, selection: $selectedPattern) { pattern in
                        PatternRow(pattern: pattern)
                            .contextMenu {
                                Button("Remove Pattern") {
                                    Task {
                                        try? await viewModel.removeIgnorePattern(pattern.pattern)
                                    }
                                }
                                .disabled(pattern.isComment || pattern.isBlank)

                                Divider()

                                Button("Copy Pattern") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(pattern.pattern, forType: .string)
                                }
                            }
                    }
                } else {
                    ContentUnavailableView {
                        Label("No .gitignore", systemImage: "doc.text")
                    } description: {
                        Text("Create a .gitignore file to start ignoring files")
                    } actions: {
                        Button("Create .gitignore") {
                            Task {
                                try? await viewModel.setIgnoreContent("# .gitignore\n")
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Editor

    private var editorToolbar: some View {
        HStack {
            if isEditing {
                Text("Editing .gitignore")
                    .font(.headline)
            } else {
                Text(".gitignore Editor")
                    .font(.headline)
            }

            Spacer()

            if isEditing {
                Button("Cancel") {
                    loadContent()
                    isEditing = false
                }

                Button("Save") {
                    saveContent()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    showTemplateSheet = true
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Add from Template")

                Button {
                    showAddPatternSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Pattern")

                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .help("Edit")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var editorView: some View {
        Group {
            if let ignoreFile = viewModel.ignoreFile, ignoreFile.exists {
                TextEditor(text: $editedContent)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(.textBackgroundColor))
                    .disabled(!isEditing)
                    .onChange(of: editedContent) { _, _ in
                        if !isEditing {
                            isEditing = true
                        }
                    }
            } else {
                ContentUnavailableView {
                    Label("No .gitignore", systemImage: "doc.text")
                } description: {
                    Text("Create a .gitignore file to edit")
                }
            }
        }
    }

    // MARK: - Helpers

    private var activePatterns: [IgnorePattern] {
        viewModel.ignoreFile?.activePatterns ?? []
    }

    private var filteredPatterns: [IgnorePattern] {
        guard let patterns = viewModel.ignoreFile?.patterns else { return [] }
        if searchText.isEmpty {
            return patterns
        }
        return patterns.filter { $0.pattern.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadContent() {
        editedContent = viewModel.ignoreFile?.content ?? ""
    }

    private func saveContent() {
        Task {
            try? await viewModel.setIgnoreContent(editedContent)
            isEditing = false
        }
    }
}

// MARK: - Pattern Row

struct PatternRow: View {
    let pattern: IgnorePattern

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.pattern)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(textColor)

                if !pattern.isBlank && !pattern.isComment {
                    Text(pattern.patternDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("L\(pattern.lineNumber)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        if pattern.isComment {
            return "number"
        }
        if pattern.isBlank {
            return "minus"
        }
        if pattern.isNegation {
            return "checkmark.circle"
        }
        if pattern.isDirectoryOnly {
            return "folder"
        }
        return "doc"
    }

    private var iconColor: Color {
        if pattern.isComment {
            return .secondary
        }
        if pattern.isBlank {
            return .secondary
        }
        if pattern.isNegation {
            return .green
        }
        return .orange
    }

    private var textColor: Color {
        if pattern.isComment || pattern.isBlank {
            return .secondary
        }
        if pattern.isNegation {
            return .green
        }
        return .primary
    }
}

// MARK: - Add Pattern Sheet

struct AddPatternSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String) -> Void

    @State private var pattern: String = ""
    @State private var patternType: PatternType = .file

    enum PatternType: String, CaseIterable, Identifiable {
        case file = "File"
        case extension_ = "Extension"
        case directory = "Directory"
        case custom = "Custom"

        var id: String { rawValue }

        var placeholder: String {
            switch self {
            case .file: return "filename.txt"
            case .extension_: return "txt"
            case .directory: return "dirname"
            case .custom: return "*.log"
            }
        }

        var prefix: String {
            switch self {
            case .file: return ""
            case .extension_: return "*."
            case .directory: return ""
            case .custom: return ""
            }
        }

        var suffix: String {
            switch self {
            case .directory: return "/"
            default: return ""
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Ignore Pattern")
                .font(.headline)

            Picker("Type", selection: $patternType) {
                ForEach(PatternType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text(patternType.prefix)
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))

                TextField(patternType.placeholder, text: $pattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Text(patternType.suffix)
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }

            Text("Result: \(finalPattern)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    onAdd(finalPattern)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pattern.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private var finalPattern: String {
        patternType.prefix + pattern + patternType.suffix
    }
}

// MARK: - Template Sheet

struct TemplateSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: ([String]) -> Void

    @State private var selectedTemplates: Set<UUID> = []

    var body: some View {
        VStack(spacing: 16) {
            Text("Add from Templates")
                .font(.headline)

            List(IgnoreTemplate.commonTemplates, selection: $selectedTemplates) { template in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.headline)
                        Text(template.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(template.patterns.joined(separator: ", "))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .tag(template.id)
            }
            .frame(height: 300)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text("\(selectedTemplates.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Add Selected") {
                    let patterns = IgnoreTemplate.commonTemplates
                        .filter { selectedTemplates.contains($0.id) }
                        .flatMap { $0.patterns }
                    onAdd(patterns)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedTemplates.isEmpty)
            }
        }
        .padding()
        .frame(width: 500)
    }
}

// MARK: - Preview

#Preview {
    GitignoreTab(viewModel: DependencyContainer.shared.repositoryViewModel)
        .frame(width: 800, height: 600)
}
