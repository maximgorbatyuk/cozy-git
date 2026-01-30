//
//  RebaseDialog.swift
//  CozyGit
//

import SwiftUI

struct RebaseDialog: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: RepositoryViewModel

    @State private var selectedBranch: String = ""
    @State private var isRebasing: Bool = false
    @State private var rebaseResult: RebaseResult?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rebase Branch")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            Form {
                // Branch Selection
                Section {
                    Picker("Rebase onto", selection: $selectedBranch) {
                        Text("Select a branch...").tag("")
                        ForEach(availableBranches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }

                    if !selectedBranch.isEmpty {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(.accentColor)
                            Text("Rebase")
                            Text(currentBranch)
                                .fontWeight(.medium)
                            Text("onto")
                            Text(selectedBranch)
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Target Branch")
                }

                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Rebase replays your commits on top of the target branch", systemImage: "info.circle")
                            .font(.caption)

                        Label("Your branch history will be rewritten", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Label("Don't rebase commits that have been pushed to a shared remote", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("Important")
                }

                // Result Section
                if let result = rebaseResult {
                    Section {
                        resultView(result)
                    } header: {
                        Text("Result")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                if let result = rebaseResult {
                    if result.hasConflicts {
                        Label("\(result.conflictingFiles.count) conflict(s)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else if result.isInProgress {
                        Label("Rebase in progress", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                    } else if result.success {
                        Label(result.summary, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    Task {
                        await performRebase()
                    }
                } label: {
                    if isRebasing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text(rebaseResult != nil ? "Rebase Again" : "Rebase")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isRebasing || selectedBranch.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 480, height: 500)
    }

    // MARK: - Result View

    @ViewBuilder
    private func resultView(_ result: RebaseResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.hasConflicts {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Rebase paused - conflicts detected")
                        .fontWeight(.medium)
                }

                Text("The following files have conflicts:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(result.conflictingFiles, id: \.self) { file in
                    HStack {
                        Image(systemName: "doc.badge.ellipsis")
                            .foregroundColor(.orange)
                        Text(file)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                Text("Resolve conflicts and use 'Continue Rebase' to proceed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                HStack(spacing: 12) {
                    Button("Continue Rebase") {
                        Task {
                            await continueRebase()
                        }
                    }
                    .disabled(isRebasing)

                    Button("Skip Commit") {
                        Task {
                            await skipCommit()
                        }
                    }
                    .disabled(isRebasing)

                    Button("Abort Rebase", role: .destructive) {
                        Task {
                            await abortRebase()
                        }
                    }
                    .disabled(isRebasing)
                }
                .padding(.top, 8)

            } else if result.isInProgress {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                    Text("Rebase in progress")
                        .fontWeight(.medium)
                }

                if result.totalCommits > 0 {
                    ProgressView(value: result.progress, total: 100)
                    Text("Commit \(result.currentCommit) of \(result.totalCommits)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            } else if result.success {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Rebase successful")
                        .fontWeight(.medium)
                }

                if result.commitsRebased > 0 {
                    Text("\(result.commitsRebased) commit(s) rebased")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            } else {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Rebase failed")
                        .fontWeight(.medium)
                }

                if let error = result.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var currentBranch: String {
        viewModel.repository?.currentBranch ?? "HEAD"
    }

    private var availableBranches: [String] {
        viewModel.branches
            .filter { !$0.isCurrent }
            .map { $0.name }
    }

    // MARK: - Actions

    private func performRebase() async {
        guard !selectedBranch.isEmpty else { return }

        isRebasing = true
        rebaseResult = nil

        do {
            let result = try await viewModel.rebase(onto: selectedBranch)
            rebaseResult = result

            // Reload data after rebase
            if result.success && !result.hasConflicts {
                await viewModel.loadCommits()
                await viewModel.loadBranches()
            }

        } catch {
            rebaseResult = RebaseResult(
                success: false,
                errorMessage: error.localizedDescription,
                rawOutput: ""
            )
        }

        isRebasing = false
    }

    private func continueRebase() async {
        isRebasing = true

        do {
            let result = try await viewModel.continueRebase()
            rebaseResult = result

            if result.success && !result.hasConflicts {
                await viewModel.loadCommits()
                await viewModel.loadBranches()
            }
        } catch {
            rebaseResult = RebaseResult(
                success: false,
                errorMessage: error.localizedDescription,
                rawOutput: ""
            )
        }

        isRebasing = false
    }

    private func skipCommit() async {
        isRebasing = true

        do {
            let result = try await viewModel.skipRebaseCommit()
            rebaseResult = result

            if result.success && !result.hasConflicts {
                await viewModel.loadCommits()
                await viewModel.loadBranches()
            }
        } catch {
            rebaseResult = RebaseResult(
                success: false,
                errorMessage: error.localizedDescription,
                rawOutput: ""
            )
        }

        isRebasing = false
    }

    private func abortRebase() async {
        isRebasing = true

        do {
            try await viewModel.abortRebase()
            rebaseResult = nil
            dismiss()
        } catch {
            rebaseResult = RebaseResult(
                success: false,
                errorMessage: error.localizedDescription,
                rawOutput: ""
            )
        }

        isRebasing = false
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)

    RebaseDialog(viewModel: viewModel)
        .onAppear {
            viewModel.repository = Repository(
                path: URL(fileURLWithPath: "/Users/test/MyProject"),
                currentBranch: "feature/new-feature",
                remotes: [Remote(name: "origin", fetchURL: URL(string: "https://github.com/test/repo.git"))]
            )
            viewModel.branches = [
                Branch(name: "main"),
                Branch(name: "feature/new-feature", isCurrent: true),
                Branch(name: "develop"),
            ]
        }
}
