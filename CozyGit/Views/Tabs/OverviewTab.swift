//
//  OverviewTab.swift
//  CozyGit
//

import SwiftUI

struct OverviewTab: View {
    @Bindable var viewModel: RepositoryViewModel

    var body: some View {
        if let repository = viewModel.repository {
            repositoryOverview(repository)
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

                // Statistics Section (Last 6 Months)
                if viewModel.isLoadingStatistics {
                    GroupBox {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading statistics...")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }
                } else if let stats = viewModel.statistics {
                    // Statistics Card
                    StatisticsCard(statistics: stats)

                    // Author Stats
                    AuthorStatsView(authors: stats.authorStats)

                    // Activity Graph
                    ActivityGraphView(dailyActivity: stats.dailyActivity)
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

                // Working Directory Status
                workingDirectoryStatus
            }
            .padding()
        }
        .task(id: repository.path) {
            await viewModel.loadStatistics()
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

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome header
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Repository Open")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Open a Git repository to get started")
                        .foregroundColor(.secondary)

                    Button {
                        DependencyContainer.shared.mainViewModel.showOpenDialog()
                    } label: {
                        Label("Open Repository", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.top, 40)

                // Recent repositories
                recentRepositoriesSection
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    // MARK: - Recent Repositories Section

    private var recentRepositoriesSection: some View {
        let recentRepos = DependencyContainer.shared.mainViewModel.recentRepositories

        return Group {
            if !recentRepos.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Repositories")
                            .font(.headline)

                        Spacer()

                        Button {
                            DependencyContainer.shared.mainViewModel.clearRecentRepositories()
                        } label: {
                            Text("Clear")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }

                    VStack(spacing: 0) {
                        ForEach(recentRepos) { repo in
                            RecentRepositoryRow(
                                repository: repo,
                                onOpen: {
                                    Task {
                                        await DependencyContainer.shared.mainViewModel.openRepository(at: repo.path)
                                    }
                                },
                                onRemove: {
                                    DependencyContainer.shared.mainViewModel.removeFromRecent(repo)
                                }
                            )

                            if repo.id != recentRepos.last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxWidth: 500)
            }
        }
    }
}

// MARK: - Recent Repository Row

private struct RecentRepositoryRow: View {
    let repository: Repository
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(repository.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(repository.path.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isHovered {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove from recent")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onOpen()
        }
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
    return OverviewTab(viewModel: viewModel)
        .frame(width: 600, height: 400)
}

#Preview("No Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    return OverviewTab(viewModel: viewModel)
        .frame(width: 600, height: 400)
}
