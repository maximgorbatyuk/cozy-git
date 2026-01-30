//
//  MergeDialog.swift
//  CozyGit
//

import SwiftUI

struct MergeDialog: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: RepositoryViewModel

    @State private var selectedBranch: String = ""
    @State private var selectedStrategy: MergeStrategy = .merge
    @State private var customMessage: String = ""
    @State private var useCustomMessage: Bool = false
    @State private var isMerging: Bool = false
    @State private var mergeResult: MergeResult?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Merge Branch")
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
                    Picker("Branch to merge", selection: $selectedBranch) {
                        Text("Select a branch...").tag("")
                        ForEach(availableBranches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }

                    if !selectedBranch.isEmpty {
                        HStack {
                            Image(systemName: "arrow.triangle.merge")
                                .foregroundColor(.accentColor)
                            Text("Merge")
                            Text(selectedBranch)
                                .fontWeight(.medium)
                            Text("into")
                            Text(currentBranch)
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Source Branch")
                }

                // Strategy Selection
                Section {
                    Picker("Strategy", selection: $selectedStrategy) {
                        ForEach(MergeStrategy.allCases) { strategy in
                            Text(strategy.rawValue).tag(strategy)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text(selectedStrategy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Merge Strategy")
                }

                // Custom Message
                if selectedStrategy != .fastForwardOnly {
                    Section {
                        Toggle("Use custom commit message", isOn: $useCustomMessage)

                        if useCustomMessage {
                            TextField("Commit message", text: $customMessage, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    } header: {
                        Text("Commit Message")
                    } footer: {
                        if !useCustomMessage {
                            Text("Default message: Merge branch '\(selectedBranch)' into \(currentBranch)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Result Section
                if let result = mergeResult {
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
                if let result = mergeResult {
                    if result.hasConflicts {
                        Label("\(result.conflictingFiles.count) conflict(s)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
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
                        await performMerge()
                    }
                } label: {
                    if isMerging {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text(mergeResult != nil ? "Merge Again" : "Merge")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isMerging || selectedBranch.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 480, height: 550)
    }

    // MARK: - Result View

    @ViewBuilder
    private func resultView(_ result: MergeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.hasConflicts {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Merge has conflicts")
                        .fontWeight(.medium)
                }

                Text("The following files have conflicts that need to be resolved:")
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

                Text("Resolve conflicts and commit to complete the merge.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

            } else if result.success {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Merge successful")
                        .fontWeight(.medium)
                }

                if result.hasChanges {
                    HStack(spacing: 16) {
                        if result.filesChanged > 0 {
                            Label("\(result.filesChanged) files", systemImage: "doc")
                        }
                        if result.insertions > 0 {
                            Label("+\(result.insertions)", systemImage: "plus")
                                .foregroundColor(.green)
                        }
                        if result.deletions > 0 {
                            Label("-\(result.deletions)", systemImage: "minus")
                                .foregroundColor(.red)
                        }
                    }
                    .font(.caption)
                }

                if result.wasFastForward {
                    Text("Fast-forward merge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if result.mergeCommitCreated {
                    Text("Merge commit created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if result.wasSquash {
                    Text("Squash merge - commit to complete")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Merge failed")
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

    private func performMerge() async {
        guard !selectedBranch.isEmpty else { return }

        isMerging = true
        mergeResult = nil

        do {
            let message = useCustomMessage && !customMessage.isEmpty ? customMessage : nil
            let result = try await viewModel.mergeBranch(
                selectedBranch,
                strategy: selectedStrategy,
                message: message
            )
            mergeResult = result

            // Reload data after merge
            await viewModel.loadCommits()
            await viewModel.loadFileStatuses()
            await viewModel.loadBranches()

        } catch {
            mergeResult = MergeResult(
                success: false,
                errorMessage: error.localizedDescription,
                rawOutput: "",
                strategy: selectedStrategy
            )
        }

        isMerging = false
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)

    MergeDialog(viewModel: viewModel)
        .onAppear {
            viewModel.repository = Repository(
                path: URL(fileURLWithPath: "/Users/test/MyProject"),
                currentBranch: "main",
                remotes: [Remote(name: "origin", fetchURL: URL(string: "https://github.com/test/repo.git"))]
            )
            viewModel.branches = [
                Branch(name: "main", isCurrent: true),
                Branch(name: "feature/new-feature"),
                Branch(name: "bugfix/fix-issue"),
                Branch(name: "develop"),
            ]
        }
}
