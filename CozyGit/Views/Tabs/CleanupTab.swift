//
//  CleanupTab.swift
//  CozyGit
//

import SwiftUI

struct CleanupTab: View {
    let repository: Repository?

    var body: some View {
        if repository != nil {
            cleanupContent
        } else {
            noRepositoryView
        }
    }

    // MARK: - Cleanup Content

    private var cleanupContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Merged Branches Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Merged Branches", systemImage: "arrow.triangle.merge")
                            .font(.headline)

                        Text("Find and delete branches that have been merged into the main branch.")
                            .foregroundColor(.secondary)

                        HStack {
                            Button("Scan for Merged Branches") {
                                // TODO: Implement scanning
                            }
                            .buttonStyle(.borderedProminent)

                            Spacer()
                        }

                        // Placeholder for merged branches list
                        Text("No merged branches found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Stale Remote Branches Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Stale Remote Branches", systemImage: "network.slash")
                            .font(.headline)

                        Text("Remove remote tracking branches that no longer exist on the remote.")
                            .foregroundColor(.secondary)

                        HStack {
                            Button("Prune Remote Branches") {
                                // TODO: Implement pruning
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }
                    }
                }

                // Large Files Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Large Files", systemImage: "doc.badge.ellipsis")
                            .font(.headline)

                        Text("Find large files in the repository history.")
                            .foregroundColor(.secondary)

                        HStack {
                            Button("Scan Repository") {
                                // TODO: Implement scanning
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Repository Open")
                .font(.title3)
                .fontWeight(.medium)

            Text("Open a repository to access cleanup tools")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("With Repository") {
    CleanupTab(repository: Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    ))
    .frame(width: 700, height: 600)
}

#Preview("No Repository") {
    CleanupTab(repository: nil)
        .frame(width: 700, height: 600)
}
