//
//  PushOptionsDialog.swift
//  CozyGit
//

import SwiftUI

struct PushOptionsDialog: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: RepositoryViewModel

    @State private var selectedRemote: String = "origin"
    @State private var selectedBranch: String = ""
    @State private var forcePush: Bool = false
    @State private var forceWithLease: Bool = true
    @State private var pushTags: Bool = false
    @State private var setUpstream: Bool = false
    @State private var isPushing: Bool = false
    @State private var pushResult: PushResult?
    @State private var showForcePushWarning: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Push Changes")
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
                        ForEach(availableLocalBranches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                } header: {
                    Text("Destination")
                }

                // Push Options
                Section {
                    Toggle("Set upstream tracking", isOn: $setUpstream)

                    Toggle("Push tags", isOn: $pushTags)
                } header: {
                    Text("Options")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if setUpstream {
                            Text("The local branch will track the remote branch")
                        }
                        if pushTags {
                            Text("All local tags will be pushed to the remote")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                // Force Push Options
                Section {
                    Toggle("Force push", isOn: $forcePush)
                        .onChange(of: forcePush) { _, newValue in
                            if newValue && !forceWithLease {
                                showForcePushWarning = true
                            }
                        }

                    if forcePush {
                        Toggle("Use --force-with-lease (safer)", isOn: $forceWithLease)
                            .padding(.leading, 20)
                    }
                } header: {
                    HStack {
                        Text("Force Push")
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                } footer: {
                    if forcePush {
                        if forceWithLease {
                            Text("Force-with-lease will only push if no one else has pushed to this branch")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Warning: This will overwrite remote changes. Use with caution!")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                // Result Section
                if let result = pushResult {
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
                if let result = pushResult {
                    if result.wasRejected {
                        Label("Rejected - pull first", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else if result.authenticationFailed {
                        Label("Auth failed", systemImage: "lock.fill")
                            .foregroundColor(.red)
                    } else if result.success {
                        Label(result.summary, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } else if let status = viewModel.remoteStatus, status.ahead > 0 {
                    Label("\(status.ahead) commit(s) to push", systemImage: "arrow.up")
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    if forcePush && !forceWithLease {
                        showForcePushWarning = true
                    } else {
                        Task {
                            await performPush()
                        }
                    }
                } label: {
                    if isPushing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text(pushResult != nil ? "Push Again" : "Push")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isPushing)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 450, height: 550)
        .onAppear {
            // Set defaults from repository
            if let tracking = viewModel.currentBranch?.trackingBranch {
                let parts = tracking.split(separator: "/", maxSplits: 1)
                if parts.count >= 1 {
                    selectedRemote = String(parts[0])
                }
            }
        }
        .alert("Force Push Warning", isPresented: $showForcePushWarning) {
            Button("Cancel", role: .cancel) {
                forcePush = false
            }
            Button("Force Push", role: .destructive) {
                Task {
                    await performPush()
                }
            }
        } message: {
            Text("Force pushing without --force-with-lease can overwrite commits that others have pushed. This may cause data loss. Are you sure you want to continue?")
        }
    }

    // MARK: - Result View

    @ViewBuilder
    private func resultView(_ result: PushResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.wasRejected {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Push rejected")
                        .fontWeight(.medium)
                }

                Text("The remote contains changes you don't have locally. Pull first and try again.")
                    .font(.caption)
                    .foregroundColor(.secondary)

            } else if result.authenticationFailed {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.red)
                    Text("Authentication failed")
                        .fontWeight(.medium)
                }

                Text("Please check your credentials and try again.")
                    .font(.caption)
                    .foregroundColor(.secondary)

            } else if result.success {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Push successful")
                        .fontWeight(.medium)
                }

                HStack(spacing: 16) {
                    if result.commitsPushed > 0 {
                        Label("\(result.commitsPushed) commit(s)", systemImage: "arrow.up.circle")
                    }
                    if result.tagsPushed > 0 {
                        Label("\(result.tagsPushed) tag(s)", systemImage: "tag")
                    }
                    if result.createdRemoteBranch {
                        Label("New branch", systemImage: "plus.circle")
                            .foregroundColor(.blue)
                    }
                }
                .font(.caption)

                if result.wasForcePush {
                    Label("Force push completed", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if let remoteBranch = result.remoteBranch {
                    Text("Pushed to \(remoteBranch)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            } else {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Push failed")
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

    private var availableLocalBranches: [String] {
        viewModel.localBranches.map { $0.name }
    }

    // MARK: - Actions

    private func performPush() async {
        isPushing = true
        pushResult = nil

        let options = PushOptions(
            remote: selectedRemote,
            branch: selectedBranch.isEmpty ? nil : selectedBranch,
            force: forcePush,
            forceWithLease: forceWithLease,
            pushTags: pushTags,
            pushAllTags: pushTags,
            setUpstream: setUpstream
        )

        do {
            let result = try await viewModel.pushWithOptions(options)
            pushResult = result

            // Reload data after push
            await viewModel.loadRemoteStatus()
            await viewModel.loadBranches()

        } catch {
            pushResult = PushResult(
                success: false,
                errorMessage: error.localizedDescription,
                rawOutput: ""
            )
        }

        isPushing = false
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)

    PushOptionsDialog(viewModel: viewModel)
        .onAppear {
            viewModel.repository = Repository(
                path: URL(fileURLWithPath: "/Users/test/MyProject"),
                currentBranch: "main",
                remotes: [Remote(name: "origin", fetchURL: URL(string: "https://github.com/test/repo.git"))]
            )
            viewModel.branches = [
                Branch(name: "main", isHead: true, isRemote: false, trackingBranch: "origin/main"),
                Branch(name: "feature/test", isHead: false, isRemote: false),
                Branch(name: "origin/main", isHead: false, isRemote: true),
            ]
            viewModel.remoteStatus = RemoteTrackingStatus(ahead: 3, behind: 0)
        }
}
