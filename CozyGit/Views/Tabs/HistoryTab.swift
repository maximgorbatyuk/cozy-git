//
//  HistoryTab.swift
//  CozyGit
//

import SwiftUI

struct HistoryTab: View {
    @Bindable var viewModel: RepositoryViewModel

    @State private var searchText: String = ""
    @State private var selectedCommit: Commit?
    @State private var showCommitDetail = false
    @State private var showGraphView: Bool = true
    @State private var commitDiff: Diff?
    @State private var isLoadingDiff: Bool = false
    @State private var selectedFileIndex: Int = 0
    @State private var checkoutError: String?
    @State private var showCheckoutError: Bool = false
    @State private var showFileDiffSheet: Bool = false
    @State private var selectedFileDiff: FileDiff?

    // Pagination state
    @State private var currentLimit: Int = 100
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreCommits: Bool = true
    private let pageSize: Int = 50

    // Advanced operations
    @State private var showResetDialog: Bool = false
    @State private var resetTargetCommit: Commit?
    @State private var showCherryPickConfirmation: Bool = false
    @State private var cherryPickTargetCommit: Commit?
    @State private var showRevertConfirmation: Bool = false
    @State private var revertTargetCommit: Commit?
    @State private var operationError: String?
    @State private var showOperationError: Bool = false
    @State private var operationSuccess: String?
    @State private var showOperationSuccess: Bool = false
    @State private var showBlameSheet: Bool = false
    @State private var blameFilePath: String?

    // Remote operations
    @State private var isFetching: Bool = false
    @State private var isPulling: Bool = false
    @State private var isPushing: Bool = false

    // Remote operation result states
    enum OperationResult { case none, success, failure }
    @State private var fetchResult: OperationResult = .none
    @State private var pullResult: OperationResult = .none
    @State private var pushResult: OperationResult = .none

    var body: some View {
        if viewModel.repository != nil {
            historyContent
                .task {
                    await viewModel.loadCommits(limit: 100)
                }
                .sheet(isPresented: $showCommitDetail) {
                    if let commit = selectedCommit {
                        CommitDetailSheet(commit: commit)
                    }
                }
                .alert("Checkout Failed", isPresented: $showCheckoutError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(checkoutError ?? "Unknown error occurred")
                }
                .sheet(isPresented: $showFileDiffSheet) {
                    if let fileDiff = selectedFileDiff {
                        FileDiffSheet(fileDiff: fileDiff, commitHash: selectedCommit?.shortHash)
                    }
                }
                .sheet(isPresented: $showResetDialog) {
                    if let commit = resetTargetCommit {
                        ResetDialog(commit: commit) { mode in
                            await performReset(to: commit, mode: mode)
                        }
                    }
                }
                .confirmationDialog(
                    "Cherry-Pick Commit",
                    isPresented: $showCherryPickConfirmation,
                    presenting: cherryPickTargetCommit
                ) { commit in
                    Button("Cherry-Pick") {
                        Task {
                            await performCherryPick(commit: commit)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { commit in
                    Text("Apply changes from commit \(commit.shortHash) onto the current branch?")
                }
                .confirmationDialog(
                    "Revert Commit",
                    isPresented: $showRevertConfirmation,
                    presenting: revertTargetCommit
                ) { commit in
                    Button("Revert", role: .destructive) {
                        Task {
                            await performRevert(commit: commit)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { commit in
                    Text("Create a new commit that undoes the changes from \(commit.shortHash)?")
                }
                .alert("Operation Failed", isPresented: $showOperationError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(operationError ?? "Unknown error occurred")
                }
                .alert("Success", isPresented: $showOperationSuccess) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(operationSuccess ?? "Operation completed successfully")
                }
                .sheet(isPresented: $showBlameSheet) {
                    if let path = blameFilePath {
                        BlameSheet(filePath: path, viewModel: viewModel)
                    }
                }
        } else {
            noRepositoryView
        }
    }

    // MARK: - History Content

    private var historyContent: some View {
        VSplitView {
            // Top: Revision Graph
            VStack(alignment: .leading, spacing: 0) {
                // Header with title and remote operation buttons
                HStack {
                    Text("History")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    // Remote operation buttons
                    HStack(spacing: 12) {
                        Button {
                            Task { await performFetch() }
                        } label: {
                            remoteOperationIcon(
                                isLoading: isFetching,
                                result: fetchResult,
                                defaultIcon: "arrow.down.circle"
                            )
                            Text("Fetch")
                        }
                        .disabled(isFetching || isPulling || isPushing)
                        .help("Fetch changes from remote")

                        Button {
                            Task { await performPull() }
                        } label: {
                            remoteOperationIcon(
                                isLoading: isPulling,
                                result: pullResult,
                                defaultIcon: "arrow.down.to.line"
                            )
                            Text("Pull")
                        }
                        .disabled(isFetching || isPulling || isPushing)
                        .help("Pull changes from remote")

                        Button {
                            Task { await performPush() }
                        } label: {
                            remoteOperationIcon(
                                isLoading: isPushing,
                                result: pushResult,
                                defaultIcon: "arrow.up.to.line"
                            )
                            Text("Push")
                        }
                        .disabled(isFetching || isPulling || isPushing)
                        .help("Push changes to remote")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.bar)

                Divider()

                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search commits...", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .frame(height: 16)

                    // Graph view toggle
                    Button {
                        showGraphView.toggle()
                    } label: {
                        Image(systemName: showGraphView ? "point.3.connected.trianglepath.dotted" : "list.bullet")
                    }
                    .buttonStyle(.borderless)
                    .help(showGraphView ? "Switch to list view" : "Switch to graph view")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Commit List/Graph
                if filteredCommits.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        if searchText.isEmpty {
                            Text("No commits yet")
                                .foregroundColor(.secondary)
                        } else {
                            Text("No commits match '\(searchText)'")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if showGraphView {
                    // Graph View
                    CommitGraphListView(
                        commits: filteredCommits,
                        selectedCommit: $selectedCommit,
                        onDoubleClick: { commit in
                            showCommitDetail = true
                        },
                        currentBranch: viewModel.repository?.currentBranch,
                        onBranchClick: { branchName, remoteRef in
                            Task {
                                await checkoutBranch(branchName, remoteRef: remoteRef)
                            }
                        }
                    )
                } else {
                    // Simple List View with lazy loading
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredCommits.enumerated()), id: \.element.id) { index, commit in
                                CommitRow(
                                    commit: commit,
                                    isSelected: selectedCommit?.id == commit.id
                                )
                                .onTapGesture {
                                    selectedCommit = commit
                                }
                                .onTapGesture(count: 2) {
                                    selectedCommit = commit
                                    showCommitDetail = true
                                }
                                .contextMenu {
                                    commitContextMenu(for: commit)
                                }
                                .onAppear {
                                    // Trigger load more when near end
                                    if index >= filteredCommits.count - 10 {
                                        loadMoreCommits()
                                    }
                                }

                                if commit.id != filteredCommits.last?.id {
                                    Divider()
                                        .padding(.leading, 50)
                                }
                            }

                            // Load more indicator
                            if isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading more commits...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding()
                            } else if hasMoreCommits && !filteredCommits.isEmpty {
                                Button {
                                    loadMoreCommits()
                                } label: {
                                    HStack {
                                        Spacer()
                                        Text("Load More Commits")
                                            .font(.caption)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                                .padding()
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 200)

            // Bottom: Changed Files + Commit Details
            if let commit = selectedCommit {
                HSplitView {
                    // Left: Changed Files List
                    changedFilesList
                        .frame(minWidth: 200, maxWidth: 350)

                    // Right: Commit Details
                    commitPreview(commit)
                        .frame(minWidth: 300)
                }
                .frame(minHeight: 150)
                .onChange(of: selectedCommit) { _, newCommit in
                    if let commit = newCommit {
                        Task {
                            await loadCommitDiff(for: commit)
                        }
                    }
                }
                .task {
                    await loadCommitDiff(for: commit)
                }
            } else {
                // No commit selected
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Select a commit to view details")
                        .foregroundColor(.secondary)
                    Text("Double-click to open full details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            }
        }
    }

    // MARK: - Changed Files List

    private var changedFilesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Changed Files")
                    .font(.headline)
                Spacer()
                if let diff = commitDiff {
                    Text("\(diff.files.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // File List
            if isLoadingDiff {
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let diff = commitDiff, !diff.files.isEmpty {
                List(selection: $selectedFileIndex) {
                    ForEach(Array(diff.files.enumerated()), id: \.offset) { index, file in
                        HStack(spacing: 8) {
                            fileStatusIcon(for: file)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.displayName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                HStack(spacing: 8) {
                                    if file.additions > 0 {
                                        Text("+\(file.additions)")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                    if file.deletions > 0 {
                                        Text("-\(file.deletions)")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                            }

                            Spacer()
                        }
                        .tag(index)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            selectedFileDiff = file
                            showFileDiffSheet = true
                        }
                        .contextMenu {
                            Button {
                                selectedFileDiff = file
                                showFileDiffSheet = true
                            } label: {
                                Label("View Diff", systemImage: "doc.text")
                            }

                            if !file.isDeletedFile {
                                Button {
                                    blameFilePath = file.newPath
                                    showBlameSheet = true
                                } label: {
                                    Label("Blame", systemImage: "text.alignleft")
                                }
                            }

                            Divider()

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(file.newPath, forType: .string)
                            } label: {
                                Label("Copy Path", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No files changed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func fileStatusIcon(for file: FileDiff) -> some View {
        Group {
            if file.isNewFile {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
            } else if file.isDeletedFile {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            } else if file.isRenamed {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            } else if file.isBinary {
                Image(systemName: "doc.zipper")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
    }

    private func loadCommitDiff(for commit: Commit) async {
        isLoadingDiff = true
        selectedFileIndex = 0
        let gitService = DependencyContainer.shared.gitService
        commitDiff = try? await gitService.getDiffForCommit(hash: commit.hash)
        isLoadingDiff = false
    }

    // MARK: - Branch Checkout

    private func checkoutBranch(_ branchName: String, remoteRef: String? = nil) async {
        do {
            let targetBranch = remoteRef ?? branchName
            try await viewModel.checkoutBranch(name: targetBranch)
            // Refresh commits after checkout - UI will reflect the branch change
            await viewModel.loadCommits(limit: currentLimit)
        } catch {
            checkoutError = error.localizedDescription
            showCheckoutError = true
        }
    }

    // MARK: - Commit Preview

    private func commitPreview(_ commit: Commit) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(commit.message)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)

                    HStack {
                        Label(commit.shortHash, systemImage: "number")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)

                        Spacer()

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(commit.hash, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy full hash")
                    }
                }

                Divider()

                // Author Info
                GroupBox("Author") {
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Name", value: commit.author)
                        LabeledContent("Email", value: commit.authorEmail)
                        LabeledContent("Date", value: commit.date.formatted(date: .long, time: .shortened))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Committer Info (if different)
                if commit.committer != commit.author {
                    GroupBox("Committer") {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent("Name", value: commit.committer)
                            LabeledContent("Email", value: commit.committerEmail)
                            LabeledContent("Date", value: commit.committerDate.formatted(date: .long, time: .shortened))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Parents
                if !commit.parents.isEmpty {
                    GroupBox("Parents") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(commit.parents, id: \.self) { parent in
                                Text(String(parent.prefix(7)))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Refs
                if !commit.refs.isEmpty {
                    GroupBox("References") {
                        FlowLayout(spacing: 6) {
                            ForEach(commit.refs, id: \.self) { ref in
                                Text(ref)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(refColor(for: ref).opacity(0.2))
                                    .foregroundColor(refColor(for: ref))
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer()

                // View Full Details Button
                Button {
                    showCommitDetail = true
                } label: {
                    Label("View Full Details", systemImage: "arrow.up.forward.square")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    private func refColor(for ref: String) -> Color {
        if ref.contains("HEAD") {
            return .purple
        } else if ref.contains("tag:") {
            return .orange
        } else if ref.contains("origin/") {
            return .blue
        } else {
            return .green
        }
    }

    // MARK: - Filtered Commits

    private var filteredCommits: [Commit] {
        if searchText.isEmpty {
            return viewModel.commits
        }
        let query = searchText.lowercased()
        return viewModel.commits.filter { commit in
            commit.message.lowercased().contains(query) ||
            commit.author.lowercased().contains(query) ||
            commit.hash.lowercased().contains(query) ||
            commit.shortHash.lowercased().contains(query)
        }
    }

    // MARK: - Pagination

    private func loadMoreCommits() {
        guard !isLoadingMore && hasMoreCommits else { return }

        isLoadingMore = true
        let newLimit = currentLimit + pageSize

        Task {
            let previousCount = viewModel.commits.count
            await viewModel.loadCommits(limit: newLimit)
            let newCount = viewModel.commits.count

            await MainActor.run {
                currentLimit = newLimit
                // If we got fewer new commits than requested, we've reached the end
                hasMoreCommits = (newCount - previousCount) >= pageSize
                isLoadingMore = false
            }
        }
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        EmptyStateView(
            icon: "clock",
            title: "No Repository Open",
            message: "Open a repository to view commit history"
        )
    }

    // MARK: - Commit Context Menu

    @ViewBuilder
    private func commitContextMenu(for commit: Commit) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(commit.hash, forType: .string)
        } label: {
            Label("Copy Hash", systemImage: "doc.on.doc")
        }

        Button {
            selectedCommit = commit
            showCommitDetail = true
        } label: {
            Label("View Details", systemImage: "info.circle")
        }

        Divider()

        Button {
            cherryPickTargetCommit = commit
            showCherryPickConfirmation = true
        } label: {
            Label("Cherry-Pick...", systemImage: "leaf.arrow.triangle.circlepath")
        }

        Button {
            revertTargetCommit = commit
            showRevertConfirmation = true
        } label: {
            Label("Revert...", systemImage: "arrow.uturn.backward")
        }

        Divider()

        Button {
            resetTargetCommit = commit
            showResetDialog = true
        } label: {
            Label("Reset to This Commit...", systemImage: "arrow.counterclockwise")
        }
    }

    // MARK: - Advanced Operations

    private func performReset(to commit: Commit, mode: ResetMode) async {
        do {
            let result = try await viewModel.reset(to: commit.hash, mode: mode)
            if result.success {
                operationSuccess = "Reset to \(commit.shortHash) (\(mode.displayName)) completed"
                showOperationSuccess = true
            } else if let error = result.errorMessage {
                operationError = error
                showOperationError = true
            }
        } catch {
            operationError = error.localizedDescription
            showOperationError = true
        }
    }

    private func performCherryPick(commit: Commit) async {
        do {
            let result = try await viewModel.cherryPick(commit: commit.hash)
            if result.success {
                operationSuccess = "Cherry-picked \(commit.shortHash) successfully"
                showOperationSuccess = true
            } else if result.hasConflicts {
                operationError = "Cherry-pick resulted in conflicts. Please resolve them and continue."
                showOperationError = true
            } else if let error = result.errorMessage {
                operationError = error
                showOperationError = true
            }
        } catch {
            operationError = error.localizedDescription
            showOperationError = true
        }
    }

    private func performRevert(commit: Commit) async {
        do {
            let result = try await viewModel.revert(commit: commit.hash)
            if result.success {
                operationSuccess = "Reverted \(commit.shortHash) successfully"
                showOperationSuccess = true
            } else if result.hasConflicts {
                operationError = "Revert resulted in conflicts. Please resolve them and continue."
                showOperationError = true
            } else if let error = result.errorMessage {
                operationError = error
                showOperationError = true
            }
        } catch {
            operationError = error.localizedDescription
            showOperationError = true
        }
    }

    // MARK: - Remote Operations

    @ViewBuilder
    private func remoteOperationIcon(isLoading: Bool, result: OperationResult, defaultIcon: String) -> some View {
        if isLoading {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 16, height: 16)
        } else {
            switch result {
            case .none:
                Image(systemName: defaultIcon)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }

    private func performFetch() async {
        isFetching = true
        fetchResult = .none
        let result = await viewModel.fetchWithResult()
        isFetching = false

        if result.success {
            await viewModel.loadCommits(limit: currentLimit)
            fetchResult = .success
        } else {
            fetchResult = .failure
        }

        // Reset icon after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        fetchResult = .none
    }

    private func performPull() async {
        isPulling = true
        pullResult = .none

        do {
            let result = try await viewModel.pullWithStrategy()
            await viewModel.loadCommits(limit: currentLimit)
            pullResult = result.success ? .success : .failure
        } catch {
            pullResult = .failure
        }

        isPulling = false

        // Reset icon after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        pullResult = .none
    }

    private func performPush() async {
        isPushing = true
        pushResult = .none

        do {
            let result = try await viewModel.pushWithOptions(PushOptions())
            pushResult = result.success ? .success : .failure
        } catch {
            pushResult = .failure
        }

        isPushing = false

        // Reset icon after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        pushResult = .none
    }
}

// MARK: - Commit Row

private struct CommitRow: View {
    let commit: Commit
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Commit indicator
            Circle()
                .fill(Color.accentColor)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                // Message
                Text(commit.message.components(separatedBy: .newlines).first ?? commit.message)
                    .lineLimit(1)
                    .fontWeight(.medium)

                // Metadata
                HStack(spacing: 8) {
                    Text(commit.shortHash)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text(commit.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(commit.date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Refs
                if !commit.refs.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(commit.refs.prefix(3), id: \.self) { ref in
                            Text(ref)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        if commit.refs.count > 3 {
                            Text("+\(commit.refs.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Commit Detail Sheet

private struct CommitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let commit: Commit

    @State private var commitDiff: Diff?
    @State private var isLoadingDiff = false
    @State private var selectedTab = 0
    @State private var diffViewMode: DiffViewMode = .sideBySide
    @State private var selectedFileIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Commit Details")
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

            // Tab Picker
            Picker("View", selection: $selectedTab) {
                Text("Info").tag(0)
                Text("Changes").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content
            if selectedTab == 0 {
                commitInfoView
            } else {
                commitChangesView
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 700, idealWidth: 900, maxWidth: .infinity,
               minHeight: 500, idealHeight: 600, maxHeight: .infinity)
        .task {
            await loadCommitDiff()
        }
    }

    // MARK: - Info View

    private var commitInfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Full Hash
                GroupBox("Commit Hash") {
                    HStack {
                        Text(commit.hash)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(commit.hash, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Full Message
                GroupBox("Message") {
                    Text(commit.message)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Author
                GroupBox("Author") {
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Name", value: commit.author)
                        LabeledContent("Email", value: commit.authorEmail)
                        LabeledContent("Date", value: commit.date.formatted(date: .complete, time: .complete))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Committer
                if commit.committer != commit.author || commit.committerDate != commit.date {
                    GroupBox("Committer") {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent("Name", value: commit.committer)
                            LabeledContent("Email", value: commit.committerEmail)
                            LabeledContent("Date", value: commit.committerDate.formatted(date: .complete, time: .complete))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Parents
                if !commit.parents.isEmpty {
                    GroupBox("Parent Commits") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(commit.parents, id: \.self) { parent in
                                Text(parent)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // References
                if !commit.refs.isEmpty {
                    GroupBox("References") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(commit.refs, id: \.self) { ref in
                                Text(ref)
                                    .font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // File Summary
                if let diff = commitDiff, !diff.isEmpty {
                    GroupBox("Changed Files (\(diff.files.count))") {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 16) {
                                Label("\(diff.totalAdditions) additions", systemImage: "plus")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Label("\(diff.totalDeletions) deletions", systemImage: "minus")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }

                            Divider()

                            ForEach(diff.files.prefix(10)) { file in
                                HStack {
                                    fileStatusIcon(for: file)
                                    Text(file.displayName)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    if file.additions > 0 {
                                        Text("+\(file.additions)")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                    if file.deletions > 0 {
                                        Text("-\(file.deletions)")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                            }

                            if diff.files.count > 10 {
                                Text("... and \(diff.files.count - 10) more files")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Changes View

    private var commitChangesView: some View {
        Group {
            if isLoadingDiff {
                ProgressView("Loading changes...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let diff = commitDiff, !diff.isEmpty {
                HSplitView {
                    // File list
                    fileListView(diff: diff)
                        .frame(minWidth: 200, maxWidth: 300)

                    // Diff view
                    VStack(spacing: 0) {
                        // View mode toggle
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

                        Divider()

                        if selectedFileIndex < diff.files.count {
                            switch diffViewMode {
                            case .unified:
                                UnifiedDiffView(fileDiff: diff.files[selectedFileIndex])
                            case .sideBySide:
                                SideBySideDiffView(fileDiff: diff.files[selectedFileIndex])
                            }
                        } else {
                            Text("Select a file to view changes")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No changes in this commit")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func fileListView(diff: Diff) -> some View {
        List(selection: $selectedFileIndex) {
            ForEach(Array(diff.files.enumerated()), id: \.offset) { index, file in
                HStack {
                    fileStatusIcon(for: file)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.displayName)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        HStack(spacing: 8) {
                            if file.additions > 0 {
                                Text("+\(file.additions)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            if file.deletions > 0 {
                                Text("-\(file.deletions)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Spacer()
                }
                .tag(index)
                .padding(.vertical, 2)
            }
        }
        .listStyle(.sidebar)
    }

    private func fileStatusIcon(for file: FileDiff) -> some View {
        Group {
            if file.isNewFile {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
            } else if file.isDeletedFile {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            } else if file.isRenamed {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            } else if file.isBinary {
                Image(systemName: "doc.zipper")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
    }

    private func loadCommitDiff() async {
        isLoadingDiff = true
        let gitService = DependencyContainer.shared.gitService
        commitDiff = try? await gitService.getDiffForCommit(hash: commit.hash)
        isLoadingDiff = false
    }
}

// MARK: - Flow Layout Helper

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - File Diff Sheet

private struct FileDiffSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fileDiff: FileDiff
    let commitHash: String?

    @State private var diffViewMode: DiffViewMode = .sideBySide

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileDiff.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    HStack(spacing: 12) {
                        if let hash = commitHash {
                            Label(hash, systemImage: "number")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if fileDiff.additions > 0 {
                            Text("+\(fileDiff.additions)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        if fileDiff.deletions > 0 {
                            Text("-\(fileDiff.deletions)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        fileStatusBadge
                    }
                }

                Spacer()

                // View mode toggle
                Picker("", selection: $diffViewMode) {
                    ForEach(DiffViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .help("Switch between Unified and Side-by-Side view")

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Diff content
            if fileDiff.isBinary {
                VStack(spacing: 12) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Binary file")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Cannot display diff for binary files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if fileDiff.hunks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No changes to display")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch diffViewMode {
                case .unified:
                    UnifiedDiffView(fileDiff: fileDiff)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .sideBySide:
                    SideBySideDiffView(fileDiff: fileDiff)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 600, idealWidth: 900, maxWidth: .infinity,
               minHeight: 400, idealHeight: 600, maxHeight: .infinity)
    }

    @ViewBuilder
    private var fileStatusBadge: some View {
        if fileDiff.isNewFile {
            Text("New")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .clipShape(Capsule())
        } else if fileDiff.isDeletedFile {
            Text("Deleted")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .clipShape(Capsule())
        } else if fileDiff.isRenamed {
            Text("Renamed")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#Preview("With Commits") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    viewModel.commits = [
        Commit(
            hash: "abc123def456789012345678901234567890abcd",
            message: "Add new feature for user authentication",
            author: "John Doe",
            authorEmail: "john@example.com",
            date: Date().addingTimeInterval(-3600),
            refs: ["HEAD -> main", "origin/main"]
        ),
        Commit(
            hash: "def456abc789012345678901234567890abcdef",
            message: "Fix bug in login validation",
            author: "Jane Smith",
            authorEmail: "jane@example.com",
            date: Date().addingTimeInterval(-86400)
        ),
        Commit(
            hash: "789012def456abc345678901234567890abcdef",
            message: "Update dependencies",
            author: "John Doe",
            authorEmail: "john@example.com",
            date: Date().addingTimeInterval(-172800)
        ),
    ]
    return HistoryTab(viewModel: viewModel)
        .frame(width: 900, height: 600)
}

#Preview("No Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    return HistoryTab(viewModel: viewModel)
        .frame(width: 900, height: 600)
}
