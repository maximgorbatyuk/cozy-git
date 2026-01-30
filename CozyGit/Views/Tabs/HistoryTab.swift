//
//  HistoryTab.swift
//  CozyGit
//

import SwiftUI

struct HistoryTab: View {
    let repository: Repository?

    var body: some View {
        if repository != nil {
            historyContent
        } else {
            noRepositoryView
        }
    }

    // MARK: - History Content

    private var historyContent: some View {
        HSplitView {
            // Commit List
            VStack(alignment: .leading, spacing: 0) {
                // Search/Filter Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text("Search commits...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(.quaternary)

                Divider()

                // Commit List Placeholder
                commitListPlaceholder
            }
            .frame(minWidth: 300, maxWidth: 400)

            // Commit Details
            VStack {
                Text("Select a commit to view details")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Placeholders

    private var commitListPlaceholder: some View {
        VStack {
            Text("No commits to display")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Repository Open")
                .font(.title3)
                .fontWeight(.medium)

            Text("Open a repository to view commit history")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("With Repository") {
    HistoryTab(repository: Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    ))
    .frame(width: 800, height: 500)
}

#Preview("No Repository") {
    HistoryTab(repository: nil)
        .frame(width: 800, height: 500)
}
