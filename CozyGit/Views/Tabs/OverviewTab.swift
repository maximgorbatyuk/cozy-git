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
