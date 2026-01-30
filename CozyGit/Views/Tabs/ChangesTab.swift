//
//  ChangesTab.swift
//  CozyGit
//

import SwiftUI

struct ChangesTab: View {
    let repository: Repository?

    var body: some View {
        if repository != nil {
            changesContent
        } else {
            noRepositoryView
        }
    }

    // MARK: - Changes Content

    private var changesContent: some View {
        HSplitView {
            // File List
            VStack(alignment: .leading, spacing: 0) {
                // Staged Files Section
                Section {
                    stagedFilesPlaceholder
                } header: {
                    sectionHeader("Staged Changes", count: 0)
                }

                Divider()

                // Unstaged Files Section
                Section {
                    unstagedFilesPlaceholder
                } header: {
                    sectionHeader("Unstaged Changes", count: 0)
                }
            }
            .frame(minWidth: 250, maxWidth: 350)

            // Diff View
            VStack {
                Text("Select a file to view changes")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Placeholders

    private var stagedFilesPlaceholder: some View {
        VStack {
            Text("No staged changes")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 100)
    }

    private var unstagedFilesPlaceholder: some View {
        VStack {
            Text("No unstaged changes")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 100)
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Repository Open")
                .font(.title3)
                .fontWeight(.medium)

            Text("Open a repository to view changes")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("With Repository") {
    ChangesTab(repository: Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    ))
    .frame(width: 800, height: 500)
}

#Preview("No Repository") {
    ChangesTab(repository: nil)
        .frame(width: 800, height: 500)
}
