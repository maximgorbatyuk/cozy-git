//
//  ChangesTab.swift
//  CozyGit
//

import SwiftUI

struct ChangesTab: View {
    @Bindable var viewModel: RepositoryViewModel

    @State private var selectedFile: FileStatus?
    @State private var showCommitDialog = false
    @State private var showStashSheet = false
    @State private var currentDiff: FileDiff?
    @State private var isLoadingDiff = false

    // Commit section state
    @State private var commitMessage: String = ""
    @State private var isCommitting: Bool = false
    @State private var isCommittingAndPushing: Bool = false
    @State private var amendCommit: Bool = false

    var body: some View {
        if viewModel.repository != nil {
            changesContent
                .task {
                    await viewModel.loadFileStatuses()
                }
                .sheet(isPresented: $showCommitDialog) {
                    CommitDialog(viewModel: viewModel)
                }
                .sheet(isPresented: $showStashSheet) {
                    StashChangesSheet { message, includeUntracked in
                        await viewModel.createStash(message: message, includeUntracked: includeUntracked)
                    }
                }
        } else {
            noRepositoryView
        }
    }

    // MARK: - Changes Content

    private var changesContent: some View {
        HSplitView {
            // File List
            VStack(alignment: .leading, spacing: 0) {
                // Search and Filter Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search files...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)

                    Picker("Filter", selection: $viewModel.fileFilter) {
                        ForEach(RepositoryViewModel.FileFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)

                    if !viewModel.fileStatuses.isEmpty {
                        Divider()
                            .frame(height: 16)

                        Button {
                            showStashSheet = true
                        } label: {
                            Image(systemName: "tray.and.arrow.down")
                        }
                        .buttonStyle(.borderless)
                        .help("Stash all changes")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

                Divider()

                // Unstaged Files Section
                unstagedFilesSection

                Divider()

                // Staged Files Section
                stagedFilesSection

                Divider()

                // Commit Section
                commitSection
            }
            .frame(minWidth: 280, maxWidth: 400)

            // Diff View
            diffView
        }
    }

    // MARK: - Diff View

    @State private var diffViewMode: DiffViewMode = .sideBySide

    private var diffView: some View {
        VStack(spacing: 0) {
            // View mode toggle
            if currentDiff != nil || isLoadingDiff {
                diffViewModeToggle
                Divider()
            }

            if isLoadingDiff {
                ProgressView("Loading diff...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let diff = currentDiff {
                switch diffViewMode {
                case .unified:
                    UnifiedDiffView(fileDiff: diff)
                case .sideBySide:
                    SideBySideDiffView(fileDiff: diff)
                }
            } else if selectedFile != nil {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No changes to display")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Select a file to view changes")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: selectedFile) { _, newFile in
            Task {
                await loadDiff(for: newFile)
            }
        }
    }

    private func loadDiff(for file: FileStatus?) async {
        guard let file = file else {
            currentDiff = nil
            return
        }

        isLoadingDiff = true
        currentDiff = await viewModel.getDiffForFile(path: file.path, staged: file.isStaged)
        isLoadingDiff = false
    }

    private var diffViewModeToggle: some View {
        HStack {
            Spacer()

            Picker("View Mode", selection: $diffViewMode) {
                ForEach(DiffViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Staged Files Section

    private var stagedFilesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Staged Changes")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.filteredStagedFiles.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())

                if !viewModel.stagedFiles.isEmpty {
                    Button {
                        Task {
                            await viewModel.unstageAllFiles()
                        }
                    } label: {
                        Text("Unstage All")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            // File List
            if viewModel.filteredStagedFiles.isEmpty {
                VStack {
                    Text("No staged changes")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredStagedFiles) { file in
                            FileStatusRow(
                                file: file,
                                isStaged: true,
                                onStageToggle: {
                                    Task {
                                        await viewModel.unstageFile(file)
                                    }
                                }
                            )
                            .background(selectedFile?.id == file.id ? Color.accentColor.opacity(0.2) : Color.clear)
                            .onTapGesture {
                                selectedFile = file
                            }
                            .contextMenu {
                                Button("Unstage") {
                                    Task {
                                        await viewModel.unstageFile(file)
                                    }
                                }

                                Divider()

                                Button("Copy Path") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(file.path, forType: .string)
                                }
                            }

                            if file.id != viewModel.filteredStagedFiles.last?.id {
                                Divider()
                                    .padding(.leading, 34)
                            }
                        }
                    }
                }
                .frame(minHeight: 60, maxHeight: 200)
            }
        }
    }

    // MARK: - Unstaged Files Section

    private var unstagedFilesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Unstaged Changes")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.filteredUnstagedFiles.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())

                if !viewModel.unstagedFiles.isEmpty {
                    Button {
                        Task {
                            await viewModel.stageAllFiles()
                        }
                    } label: {
                        Text("Stage All")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            // File List
            if viewModel.filteredUnstagedFiles.isEmpty {
                VStack {
                    if viewModel.unstagedFiles.isEmpty {
                        Text("No unstaged changes")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        Text("No files match filter")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredUnstagedFiles) { file in
                            FileStatusRow(
                                file: file,
                                isStaged: false,
                                onStageToggle: {
                                    Task {
                                        await viewModel.stageFile(file)
                                    }
                                },
                                onDiscard: {
                                    Task {
                                        await viewModel.discardChanges(file)
                                    }
                                }
                            )
                            .background(selectedFile?.id == file.id ? Color.accentColor.opacity(0.2) : Color.clear)
                            .onTapGesture {
                                selectedFile = file
                            }
                            .contextMenu {
                                Button("Stage") {
                                    Task {
                                        await viewModel.stageFile(file)
                                    }
                                }

                                Button("Discard Changes") {
                                    Task {
                                        await viewModel.discardChanges(file)
                                    }
                                }

                                Divider()

                                Menu("Add to .gitignore") {
                                    Button("Ignore This File") {
                                        Task {
                                            try? await viewModel.ignoreFile(at: file.path)
                                        }
                                    }

                                    let ext = URL(fileURLWithPath: file.path).pathExtension
                                    if !ext.isEmpty {
                                        Button("Ignore *.\(ext) Files") {
                                            Task {
                                                try? await viewModel.ignoreFileExtension(file.path)
                                            }
                                        }
                                    }

                                    if file.path.contains("/") {
                                        let dir = (file.path as NSString).deletingLastPathComponent
                                        Button("Ignore Directory \(dir)/") {
                                            Task {
                                                try? await viewModel.ignoreDirectory(dir)
                                            }
                                        }
                                    }
                                }

                                Divider()

                                Button("Copy Path") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(file.path, forType: .string)
                                }
                            }

                            if file.id != viewModel.filteredUnstagedFiles.last?.id {
                                Divider()
                                    .padding(.leading, 34)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Commit Section

    private var commitSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Commit")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            // Content
            VStack(spacing: 12) {
                // Commit message field
                TextField("Commit message...", text: $commitMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)

                // Amend checkbox
                Toggle("Amend last commit", isOn: $amendCommit)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                // Buttons
                HStack(spacing: 8) {
                    Button {
                        Task {
                            await performCommit()
                        }
                    } label: {
                        if isCommitting {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Commit")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCommitDisabled)

                    Button {
                        Task {
                            await performCommitAndPush()
                        }
                    } label: {
                        if isCommittingAndPushing {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Commit & Push")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCommitDisabled)
                }

                // Helper text
                if viewModel.stagedFiles.isEmpty && !amendCommit {
                    Text("Stage changes to commit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
        }
    }

    private var isCommitDisabled: Bool {
        let messageEmpty = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let noStagedChanges = viewModel.stagedFiles.isEmpty
        let isOperationInProgress = isCommitting || isCommittingAndPushing

        // When amending, we can commit even without staged changes (just to change the message)
        if amendCommit {
            return messageEmpty || isOperationInProgress
        }

        return messageEmpty || noStagedChanges || isOperationInProgress
    }

    private func performCommit() async {
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        guard amendCommit || !viewModel.stagedFiles.isEmpty else { return }

        isCommitting = true
        await viewModel.commit(message: message, amend: amendCommit)
        isCommitting = false
        commitMessage = ""
        amendCommit = false
    }

    private func performCommitAndPush() async {
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        guard amendCommit || !viewModel.stagedFiles.isEmpty else { return }

        isCommittingAndPushing = true
        await viewModel.commit(message: message, amend: amendCommit)
        await viewModel.push(force: amendCommit) // Force push if amending
        isCommittingAndPushing = false
        commitMessage = ""
        amendCommit = false
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        EmptyStateView(
            icon: "doc.badge.plus",
            title: "No Repository Open",
            message: "Open a repository to view changes"
        )
    }
}

// MARK: - Stash Changes Sheet

private struct StashChangesSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var message: String = ""
    @State private var includeUntracked: Bool = false
    @State private var isCreating: Bool = false

    let onCreate: (String?, Bool) async -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Stash Changes")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Describe your changes...", text: $message)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Include untracked files", isOn: $includeUntracked)
                    .help("Also stash files that are not yet tracked by git")

                Text("This will save your current working directory changes and revert to a clean state.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    isCreating = true
                    Task {
                        await onCreate(message.isEmpty ? nil : message, includeUntracked)
                        isCreating = false
                        dismiss()
                    }
                } label: {
                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Stash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreating)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400)
    }
}

// MARK: - Preview

#Preview("With Changes") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    viewModel.fileStatuses = [
        FileStatus(path: "src/main.swift", status: .modified, isStaged: true),
        FileStatus(path: "README.md", status: .modified, isStaged: false),
        FileStatus(path: "Package.swift", status: .added, isStaged: false),
        FileStatus(path: "old-file.txt", status: .deleted, isStaged: false),
        FileStatus(path: "new-file.swift", status: .untracked, isStaged: false),
    ]
    return ChangesTab(viewModel: viewModel)
        .frame(width: 800, height: 500)
}

#Preview("No Changes") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    return ChangesTab(viewModel: viewModel)
        .frame(width: 800, height: 500)
}

#Preview("No Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    return ChangesTab(viewModel: viewModel)
        .frame(width: 800, height: 500)
}
