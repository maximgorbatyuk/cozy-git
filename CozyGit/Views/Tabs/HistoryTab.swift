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
        } else {
            noRepositoryView
        }
    }

    // MARK: - History Content

    private var historyContent: some View {
        VSplitView {
            // Top: Revision Graph
            VStack(alignment: .leading, spacing: 0) {
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
                .background(.bar)

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
                        }
                    )
                } else {
                    // Simple List View
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredCommits) { commit in
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

                                if commit.id != filteredCommits.last?.id {
                                    Divider()
                                        .padding(.leading, 50)
                                }
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

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        EmptyStateView(
            icon: "clock",
            title: "No Repository Open",
            message: "Open a repository to view commit history"
        )
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
        .frame(width: 900, height: 600)
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
