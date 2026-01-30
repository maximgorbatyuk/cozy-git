//
//  AutomateTab.swift
//  CozyGit
//

import SwiftUI

struct AutomateTab: View {
    let repository: Repository?

    var body: some View {
        if repository != nil {
            automateContent
        } else {
            noRepositoryView
        }
    }

    // MARK: - Automate Content

    private var automateContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Quick Commit Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Quick Commit", systemImage: "bolt.fill")
                            .font(.headline)

                        Text("Stage all changes and commit with a generated message.")
                            .foregroundColor(.secondary)

                        HStack {
                            Button("Quick Commit") {
                                // TODO: Implement quick commit
                            }
                            .buttonStyle(.borderedProminent)

                            Spacer()
                        }
                    }
                }

                // Git Flow Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Git Flow", systemImage: "arrow.triangle.branch")
                            .font(.headline)

                        Text("Automate common Git Flow operations.")
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            Button("Start Feature") {
                                // TODO: Implement
                            }
                            .buttonStyle(.bordered)

                            Button("Start Release") {
                                // TODO: Implement
                            }
                            .buttonStyle(.bordered)

                            Button("Start Hotfix") {
                                // TODO: Implement
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }
                    }
                }

                // Batch Operations Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Batch Operations", systemImage: "square.stack.3d.up")
                            .font(.headline)

                        Text("Perform operations on multiple branches at once.")
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            Button("Delete Merged Branches") {
                                // TODO: Implement
                            }
                            .buttonStyle(.bordered)

                            Button("Update All Branches") {
                                // TODO: Implement
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }
                    }
                }

                // Scheduled Tasks Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Scheduled Tasks", systemImage: "calendar.badge.clock")
                            .font(.headline)

                        Text("Configure automated tasks to run on a schedule.")
                            .foregroundColor(.secondary)

                        // Placeholder for scheduled tasks
                        Text("No scheduled tasks configured")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        HStack {
                            Button("Add Task") {
                                // TODO: Implement
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
            Image(systemName: "gearshape.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Repository Open")
                .font(.title3)
                .fontWeight(.medium)

            Text("Open a repository to access automation tools")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("With Repository") {
    AutomateTab(repository: Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    ))
    .frame(width: 700, height: 700)
}

#Preview("No Repository") {
    AutomateTab(repository: nil)
        .frame(width: 700, height: 700)
}
