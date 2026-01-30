//
//  PullOptionsDialog.swift
//  CozyGit
//

import SwiftUI

struct PullOptionsDialog: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: RepositoryViewModel

    @State private var selectedStrategy: PullStrategy = .merge
    @State private var selectedRemote: String = "origin"
    @State private var selectedBranch: String = ""
    @State private var setUpstream: Bool = false
    @State private var isPulling: Bool = false
    @State private var pullResult: PullResult?
    @State private var showResult: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Pull Changes")
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
                // Remote & Branch Selection
                Section {
                    Picker("Remote", selection: $selectedRemote) {
                        ForEach(availableRemotes, id: \.self) { remote in
                            Text(remote).tag(remote)
                        }
                    }

                    Picker("Branch", selection: $selectedBranch) {
                        Text("Current branch").tag("")
                        ForEach(availableBranches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                } header: {
                    Text("Source")
                }

                // Strategy Selection
                Section {
                    Picker("Strategy", selection: $selectedStrategy) {
                        ForEach(PullStrategy.allCases) { strategy in
                            Text(strategy.rawValue).tag(strategy)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text(selectedStrategy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Pull Strategy")
                }

                // Options
                Section {
                    Toggle("Set upstream tracking", isOn: $setUpstream)
                } header: {
                    Text("Options")
                } footer: {
                    Text("Configure this branch to track the remote branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Result Section
                if let result = pullResult {
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
                if let result = pullResult {
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
                        await performPull()
                    }
                } label: {
                    if isPulling {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text(pullResult != nil ? "Pull Again" : "Pull")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isPulling)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
        .onAppear {
            // Set defaults from repository
            if let tracking = viewModel.currentBranch?.trackingBranch {
                let parts = tracking.split(separator: "/", maxSplits: 1)
                if parts.count >= 1 {
                    selectedRemote = String(parts[0])
                }
            }
        }
    }

    // MARK: - Result View

    @ViewBuilder
    private func resultView(_ result: PullResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.hasConflicts {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Pull completed with conflicts")
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
            } else if result.success {
                if result.hasChanges {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Pull successful")
                            .fontWeight(.medium)
                    }

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

                    if result.wasFastForward {
                        Text("Fast-forward merge")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if result.mergeCommitCreated {
                        Text("Merge commit created")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Already up to date")
                    }
                }
            } else {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Pull failed")
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

    private var availableRemotes: [String] {
        viewModel.repository?.remotes.map { $0.name } ?? ["origin"]
    }

    private var availableBranches: [String] {
        viewModel.remoteBranches
            .filter { $0.name.hasPrefix("\(selectedRemote)/") }
            .map { $0.name.replacingOccurrences(of: "\(selectedRemote)/", with: "") }
    }

    // MARK: - Actions

    private func performPull() async {
        isPulling = true
        pullResult = nil

        let remote = selectedRemote
        let branch = selectedBranch.isEmpty ? nil : selectedBranch

        do {
            let result = try await viewModel.pullWithStrategy(
                remote: remote,
                branch: branch,
                strategy: selectedStrategy
            )
            pullResult = result

            // Set upstream if requested and pull was successful
            if setUpstream && result.success && !result.hasConflicts {
                if let currentBranch = viewModel.repository?.currentBranch {
                    try await viewModel.setUpstream(remote: remote, branch: branch ?? currentBranch)
                }
            }

            // Reload data after pull
            await viewModel.loadCommits()
            await viewModel.loadFileStatuses()
            await viewModel.loadRemoteStatus()

        } catch {
            pullResult = PullResult(
                success: false,
                errorMessage: error.localizedDescription,
                rawOutput: "",
                strategy: selectedStrategy
            )
        }

        isPulling = false
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)

    PullOptionsDialog(viewModel: viewModel)
        .onAppear {
            viewModel.repository = Repository(
                path: URL(fileURLWithPath: "/Users/test/MyProject"),
                currentBranch: "main",
                remotes: [Remote(name: "origin", fetchURL: URL(string: "https://github.com/test/repo.git"))]
            )
            viewModel.branches = [
                Branch(name: "main", isHead: true, isRemote: false, trackingBranch: "origin/main"),
                Branch(name: "origin/main", isHead: false, isRemote: true),
                Branch(name: "origin/develop", isHead: false, isRemote: true),
            ]
        }
}
