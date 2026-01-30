//
//  DeleteBranchConfirmation.swift
//  CozyGit
//

import SwiftUI

struct DeleteBranchConfirmation: View {
    @Environment(\.dismiss) private var dismiss

    let branch: Branch
    let onConfirm: (Bool, Bool) async -> Void

    @State private var forceDelete: Bool = false
    @State private var deleteRemote: Bool = false
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Delete Branch")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                Text("Are you sure you want to delete the branch:")
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: branch.isRemote ? "cloud" : "arrow.triangle.branch")
                        .foregroundColor(branch.isRemote ? .blue : .green)
                    Text(branch.name)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                if !branch.isRemote {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $forceDelete) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Force delete")
                                    .fontWeight(.medium)
                                Text("Delete even if branch has unmerged changes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if branch.trackingBranch != nil {
                            Toggle(isOn: $deleteRemote) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Delete remote branch")
                                        .fontWeight(.medium)
                                    Text("Also delete the remote tracking branch")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                if forceDelete {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Force deleting may result in losing unmerged commits. This action cannot be undone.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                if let error = errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    Task {
                        await deleteBranch()
                    }
                } label: {
                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Delete")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isDeleting)
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
        }
        .frame(width: 420, height: branch.trackingBranch != nil ? 400 : 350)
    }

    // MARK: - Actions

    private func deleteBranch() async {
        isDeleting = true
        errorMessage = nil

        await onConfirm(forceDelete, deleteRemote)

        await MainActor.run {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("Local Branch") {
    DeleteBranchConfirmation(
        branch: Branch(
            name: "feature/old-feature",
            isHead: false,
            isRemote: false,
            trackingBranch: "origin/feature/old-feature"
        ),
        onConfirm: { force, deleteRemote in
            print("Delete with force: \(force), deleteRemote: \(deleteRemote)")
        }
    )
}

#Preview("Remote Branch") {
    DeleteBranchConfirmation(
        branch: Branch(
            name: "origin/feature/old-feature",
            isHead: false,
            isRemote: true
        ),
        onConfirm: { force, deleteRemote in
            print("Delete remote branch")
        }
    )
}

#Preview("Local Branch Without Tracking") {
    DeleteBranchConfirmation(
        branch: Branch(
            name: "local-only",
            isHead: false,
            isRemote: false
        ),
        onConfirm: { force, deleteRemote in
            print("Delete local branch")
        }
    )
}
