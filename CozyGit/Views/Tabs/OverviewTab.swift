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

    var body: some View {
        if let repository = viewModel.repository {
            repositoryOverview(repository)
                .task {
                    await viewModel.loadRemoteStatus()
                    await viewModel.loadCommits(limit: 1)
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Last Commit Card
                if let commit = viewModel.lastCommit {
                    GroupBox("Last Commit") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(commit.message)
                                .lineLimit(2)

                            HStack {
                                Text(commit.author)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(commit.date.formatted(date: .abbreviated, time: .shortened))
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
                    HStack(spacing: 12) {
                        ActionButton(
                            title: "Fetch",
                            icon: "arrow.down.circle",
                            isLoading: isFetching
                        ) {
                            Task {
                                isFetching = true
                                await viewModel.fetch(prune: true)
                                await viewModel.loadRemoteStatus()
                                isFetching = false
                            }
                        }

                        ActionButton(
                            title: "Pull",
                            icon: "arrow.down.doc",
                            isLoading: isPulling
                        ) {
                            Task {
                                isPulling = true
                                await viewModel.pull()
                                await viewModel.loadRemoteStatus()
                                isPulling = false
                            }
                        }

                        ActionButton(
                            title: "Push",
                            icon: "arrow.up.doc",
                            isLoading: isPushing
                        ) {
                            Task {
                                isPushing = true
                                await viewModel.push()
                                await viewModel.loadRemoteStatus()
                                isPushing = false
                            }
                        }
                    }
                }
            }
            .padding()
        }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(height: 24)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
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
    viewModel.remoteStatus = RemoteTrackingStatus(ahead: 2, behind: 1)
    return OverviewTab(viewModel: viewModel)
        .frame(width: 600, height: 500)
}

#Preview("No Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    return OverviewTab(viewModel: viewModel)
        .frame(width: 600, height: 400)
}
