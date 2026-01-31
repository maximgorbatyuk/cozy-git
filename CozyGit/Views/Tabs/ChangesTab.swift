//
//  ChangesTab.swift
//  CozyGit
//

import SwiftUI

struct ChangesTab: View {
    @Bindable var viewModel: RepositoryViewModel

    @State private var selectedFile: FileStatus?
    @State private var showCommitDialog = false
    @State private var currentDiff: FileDiff?
    @State private var isLoadingDiff = false

    var body: some View {
        if viewModel.repository != nil {
            changesContent
                .task {
                    await viewModel.loadFileStatuses()
                }
                .sheet(isPresented: $showCommitDialog) {
                    CommitDialog(viewModel: viewModel)
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
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

                Divider()

                // Staged Files Section
                stagedFilesSection

                Divider()

                // Unstaged Files Section
                unstagedFilesSection
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

                    Button {
                        showCommitDialog = true
                    } label: {
                        Label("Commit", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
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

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        EmptyStateView(
            icon: "doc.badge.plus",
            title: "No Repository Open",
            message: "Open a repository to view changes"
        )
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
