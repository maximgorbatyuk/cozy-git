//
//  OverviewTab.swift
//  CozyGit
//

import SwiftUI

struct OverviewTab: View {
    @Bindable var viewModel: RepositoryViewModel

    @State private var isFetching = false
    @State private var isPulling = false
    @State private var isPushing = false
    @State private var showPullDialog = false
    @State private var showPushDialog = false
    @State private var fetchResult: FetchResult?
    @State private var lastOperationMessage: String?
    @State private var showOperationResult = false

    var body: some View {
        if let repository = viewModel.repository {
            repositoryOverview(repository)
                .task {
                    await viewModel.loadRemoteStatus()
                    await viewModel.loadCommits(limit: 1)
                }
                .sheet(isPresented: $showPullDialog) {
                    PullOptionsDialog(viewModel: viewModel)
                }
                .sheet(isPresented: $showPushDialog) {
                    PushOptionsDialog(viewModel: viewModel)
                }
        } else {
            noRepositoryView
        }
    }

    // MARK: - Repository Overview

    private func repositoryOverview(_ repository: Repository) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Repository Info Card
                GroupBox("Repository") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Name", value: repository.name)
                        LabeledContent("Path", value: repository.path.path)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Current Branch Card
                GroupBox("Current Branch") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(.accentColor)
                            if let branch = repository.currentBranch {
                                Text(branch)
                                    .fontWeight(.medium)
                            } else {
                                Text("Detached HEAD")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            RemoteStatusView(status: viewModel.remoteStatus)
                        }

                        // Show sync status message
                        if let status = viewModel.remoteStatus, status.hasChanges {
                            HStack(spacing: 16) {
                                if status.behind > 0 {
                                    Label("\(status.behind) commit\(status.behind == 1 ? "" : "s") to pull", systemImage: "arrow.down")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                if status.ahead > 0 {
                                    Label("\(status.ahead) commit\(status.ahead == 1 ? "" : "s") to push", systemImage: "arrow.up")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Last Commit Card
                if let commit = viewModel.lastCommit {
                    GroupBox("Last Commit") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(commit.shortHash)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(commit.date.formatted(.relative(presentation: .named)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(commit.message)
                                .lineLimit(2)

                            HStack {
                                Image(systemName: "person.circle")
                                    .foregroundColor(.secondary)
                                Text(commit.author)
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Remotes Card
                if !repository.remotes.isEmpty {
                    GroupBox("Remotes") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(repository.remotes) { remote in
                                HStack {
                                    Image(systemName: "network")
                                        .foregroundColor(.secondary)
                                    Text(remote.name)
                                        .fontWeight(.medium)
                                    Spacer()
                                    if let url = remote.fetchURL {
                                        Text(url.absoluteString)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Quick Actions Card
                GroupBox("Quick Actions") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ActionButton(
                                title: "Fetch",
                                icon: "arrow.down.circle",
                                isLoading: isFetching,
                                badge: nil
                            ) {
                                Task {
                                    await performFetch()
                                }
                            }

                            ActionButton(
                                title: "Pull",
                                icon: "arrow.down.doc",
                                isLoading: isPulling,
                                badge: viewModel.remoteStatus?.behind
                            ) {
                                showPullDialog = true
                            }

                            ActionButton(
                                title: "Push",
                                icon: "arrow.up.doc",
                                isLoading: isPushing,
                                badge: viewModel.remoteStatus?.ahead
                            ) {
                                showPushDialog = true
                            }

                            Spacer()
                        }

                        // Operation Result
                        if let message = lastOperationMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    lastOperationMessage = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }

                // Working Directory Status
                workingDirectoryStatus
            }
            .padding()
        }
    }

    // MARK: - Working Directory Status

    private var workingDirectoryStatus: some View {
        GroupBox("Working Directory") {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.fileStatuses.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Clean working directory")
                            .foregroundColor(.secondary)
                    }
                } else {
                    let staged = viewModel.stagedFiles.count
                    let unstaged = viewModel.unstagedFiles.count

                    HStack(spacing: 16) {
                        if staged > 0 {
                            Label("\(staged) staged", systemImage: "checkmark.circle")
                                .foregroundColor(.green)
                        }
                        if unstaged > 0 {
                            Label("\(unstaged) unstaged", systemImage: "pencil.circle")
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.caption)

                    Button {
                        DependencyContainer.shared.mainViewModel.selectedTab = .changes
                    } label: {
                        Text("View Changes")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await viewModel.loadFileStatuses()
        }
    }

    // MARK: - Actions

    private func performFetch() async {
        isFetching = true
        lastOperationMessage = nil

        let result = await viewModel.fetchWithResult(prune: true)

        if result.success {
            lastOperationMessage = result.summary
        }

        isFetching = false
    }

    private func performPush() async {
        isPushing = true
        lastOperationMessage = nil

        await viewModel.push()

        if viewModel.errorMessage == nil {
            lastOperationMessage = "Push successful"
        }

        isPushing = false
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        EmptyStateView(
            icon: "folder.badge.questionmark",
            title: "No Repository Open",
            message: "Open a Git repository to get started",
            actionTitle: "Open Repository"
        ) {
            DependencyContainer.shared.mainViewModel.showOpenDialog()
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let title: String
    let icon: String
    var isLoading: Bool = false
    var badge: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(height: 24)
                    } else {
                        Image(systemName: icon)
                            .font(.title2)
                    }

                    // Badge
                    if let count = badge, count > 0, !isLoading {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
                }
                Text(title)
                    .font(.caption)
            }
            .frame(width: 80, height: 60)
        }
        .buttonStyle(.bordered)
        .disabled(isLoading)
    }
}

// MARK: - Preview

#Preview("With Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        name: "MyProject",
        currentBranch: "main",
        remotes: [
            Remote(name: "origin", fetchURL: URL(string: "https://github.com/test/repo.git"))
        ]
    )
    viewModel.remoteStatus = RemoteTrackingStatus(ahead: 2, behind: 3)
    viewModel.commits = [
        Commit(
            hash: "abc123def456",
            message: "Add new feature for authentication",
            author: "John Doe",
            authorEmail: "john@example.com",
            date: Date().addingTimeInterval(-3600)
        )
    ]
    return OverviewTab(viewModel: viewModel)
        .frame(width: 600, height: 600)
}

#Preview("No Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    return OverviewTab(viewModel: viewModel)
        .frame(width: 600, height: 400)
}
