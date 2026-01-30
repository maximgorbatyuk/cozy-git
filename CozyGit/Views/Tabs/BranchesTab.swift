//
//  BranchesTab.swift
//  CozyGit
//

import SwiftUI

struct BranchesTab: View {
    let repository: Repository?

    var body: some View {
        if repository != nil {
            branchesContent
        } else {
            noRepositoryView
        }
    }

    // MARK: - Branches Content

    private var branchesContent: some View {
        HSplitView {
            // Branch List
            VStack(alignment: .leading, spacing: 0) {
                // Local Branches Section
                Section {
                    localBranchesPlaceholder
                } header: {
                    sectionHeader("Local Branches", icon: "laptopcomputer")
                }

                Divider()

                // Remote Branches Section
                Section {
                    remoteBranchesPlaceholder
                } header: {
                    sectionHeader("Remote Branches", icon: "network")
                }
            }
            .frame(minWidth: 250, maxWidth: 350)

            // Branch Details
            VStack {
                Text("Select a branch to view details")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Placeholders

    private var localBranchesPlaceholder: some View {
        VStack {
            Text("No local branches")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 150)
    }

    private var remoteBranchesPlaceholder: some View {
        VStack {
            Text("No remote branches")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 150)
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Repository Open")
                .font(.title3)
                .fontWeight(.medium)

            Text("Open a repository to view branches")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("With Repository") {
    BranchesTab(repository: Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    ))
    .frame(width: 800, height: 500)
}

#Preview("No Repository") {
    BranchesTab(repository: nil)
        .frame(width: 800, height: 500)
}
