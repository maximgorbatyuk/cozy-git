//
//  OverviewTab.swift
//  CozyGit
//

import SwiftUI

struct OverviewTab: View {
    let repository: Repository?

    var body: some View {
        if let repository = repository {
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
                        if let branch = repository.currentBranch {
                            LabeledContent("Current Branch", value: branch)
                        }
                        if let date = repository.lastCommitDate {
                            LabeledContent("Last Commit", value: date.formatted())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                        ActionButton(title: "Fetch", icon: "arrow.down.circle") {
                            // TODO: Implement fetch
                        }
                        ActionButton(title: "Pull", icon: "arrow.down.doc") {
                            // TODO: Implement pull
                        }
                        ActionButton(title: "Push", icon: "arrow.up.doc") {
                            // TODO: Implement push
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(width: 80, height: 60)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Preview

#Preview("With Repository") {
    OverviewTab(repository: Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        name: "MyProject",
        currentBranch: "main",
        remotes: [
            Remote(name: "origin", fetchURL: URL(string: "https://github.com/test/repo.git"))
        ]
    ))
    .frame(width: 600, height: 400)
}

#Preview("No Repository") {
    OverviewTab(repository: nil)
        .frame(width: 600, height: 400)
}
