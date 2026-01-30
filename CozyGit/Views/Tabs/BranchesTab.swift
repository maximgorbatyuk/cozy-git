//
//  BranchesTab.swift
//  CozyGit
//

import SwiftUI

struct BranchesTab: View {
    @Bindable var viewModel: RepositoryViewModel

    @State private var selectedBranch: Branch?
    @State private var searchText: String = ""
    @State private var showNewBranchDialog = false
    @State private var branchToDelete: Branch?
    @State private var showDeleteConfirmation = false
    @State private var expandLocalBranches = true
    @State private var expandRemoteBranches = true
    @State private var showMergeDialog = false
    @State private var showRebaseDialog = false
    @State private var operationState: OperationState = .none

    var body: some View {
        if viewModel.repository != nil {
            branchesContent
                .task {
                    await viewModel.loadBranches()
                }
                .sheet(isPresented: $showNewBranchDialog) {
                    NewBranchDialog(viewModel: viewModel)
                }
                .sheet(isPresented: $showMergeDialog) {
                    MergeDialog(viewModel: viewModel)
                }
                .sheet(isPresented: $showRebaseDialog) {
                    RebaseDialog(viewModel: viewModel)
                }
                .sheet(isPresented: $showDeleteConfirmation) {
                    if let branch = branchToDelete {
                        DeleteBranchConfirmation(
                            branch: branch,
                            onConfirm: { force, deleteRemote in
                                do {
                                    try await viewModel.deleteBranch(branch, force: force, deleteRemote: deleteRemote)
                                    if selectedBranch?.id == branch.id {
                                        selectedBranch = nil
                                    }
                                } catch {
                                    // Error is handled by viewModel
                                }
                            }
                        )
                    }
                }
        } else {
            noRepositoryView
        }
    }

    // MARK: - Branches Content

    private var branchesContent: some View {
        HSplitView {
            // Branch List
            VStack(alignment: .leading, spacing: 0) {
                // Toolbar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search branches...", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showNewBranchDialog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .help("Create new branch")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Local Branches Section
                        DisclosureGroup(isExpanded: $expandLocalBranches) {
                            localBranchesList
                        } label: {
                            sectionHeader("Local Branches", count: filteredLocalBranches.count, icon: "laptopcomputer")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)

                        Divider()
                            .padding(.vertical, 4)

                        // Remote Branches Section
                        DisclosureGroup(isExpanded: $expandRemoteBranches) {
                            remoteBranchesList
                        } label: {
                            sectionHeader("Remote Branches", count: filteredRemoteBranches.count, icon: "cloud")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(minWidth: 280, maxWidth: 400)

            // Branch Details
            if let branch = selectedBranch {
                branchDetailView(branch)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Select a branch to view details")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: Int, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
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
    }

    // MARK: - Local Branches List

    private var localBranchesList: some View {
        VStack(spacing: 0) {
            if filteredLocalBranches.isEmpty {
                Text(searchText.isEmpty ? "No local branches" : "No matching branches")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(filteredLocalBranches) { branch in
                    BranchRow(
                        branch: branch,
                        isSelected: selectedBranch?.id == branch.id,
                        onCheckout: {
                            Task {
                                await viewModel.checkoutBranch(branch)
                            }
                        },
                        onDelete: {
                            branchToDelete = branch
                            showDeleteConfirmation = true
                        }
                    )
                    .onTapGesture {
                        selectedBranch = branch
                    }

                    if branch.id != filteredLocalBranches.last?.id {
                        Divider()
                            .padding(.leading, 30)
                    }
                }
            }
        }
    }

    // MARK: - Remote Branches List

    private var remoteBranchesList: some View {
        VStack(spacing: 0) {
            if filteredRemoteBranches.isEmpty {
                Text(searchText.isEmpty ? "No remote branches" : "No matching branches")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(filteredRemoteBranches) { branch in
                    BranchRow(
                        branch: branch,
                        isSelected: selectedBranch?.id == branch.id,
                        onCheckout: nil,
                        onDelete: nil
                    )
                    .onTapGesture {
                        selectedBranch = branch
                    }

                    if branch.id != filteredRemoteBranches.last?.id {
                        Divider()
                            .padding(.leading, 30)
                    }
                }
            }
        }
    }

    // MARK: - Branch Detail View

    private func branchDetailView(_ branch: Branch) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: branch.isRemote ? "cloud" : "arrow.triangle.branch")
                            .font(.title2)
                            .foregroundColor(branch.isRemote ? .blue : .green)

                        Text(branch.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .textSelection(.enabled)

                        Spacer()

                        if branch.isHead {
                            Text("Current")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }

                    if let tracking = branch.trackingBranch {
                        HStack {
                            Image(systemName: "arrow.triangle.merge")
                                .foregroundColor(.secondary)
                            Text("Tracking: \(tracking)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                // Branch Info
                GroupBox("Branch Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Type", value: branch.isRemote ? "Remote" : "Local")
                        LabeledContent("Full Reference", value: branch.isRemote ? "refs/remotes/\(branch.name)" : "refs/heads/\(branch.name)")

                        if let tracking = branch.trackingBranch {
                            LabeledContent("Upstream", value: tracking)
                        }

                        if let lastCommitHash = branch.lastCommitHash {
                            HStack {
                                Text("Last Commit")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(lastCommitHash.prefix(7)))
                                    .font(.system(.body, design: .monospaced))

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(lastCommitHash, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .help("Copy commit hash")
                            }
                        }

                        if let date = branch.lastCommitDate {
                            LabeledContent("Last Activity", value: date.formatted(.relative(presentation: .named)))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Actions
                if !branch.isRemote {
                    GroupBox("Actions") {
                        VStack(alignment: .leading, spacing: 12) {
                            if !branch.isHead {
                                Button {
                                    Task {
                                        await viewModel.checkoutBranch(branch)
                                        selectedBranch = branch
                                    }
                                } label: {
                                    Label("Checkout Branch", systemImage: "checkmark.circle")
                                }
                                .buttonStyle(.bordered)
                            }

                            if !branch.isHead {
                                Button(role: .destructive) {
                                    branchToDelete = branch
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete Branch", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }

                            if branch.isHead {
                                Text("Cannot delete or checkout the current branch")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Merge & Rebase Actions
                GroupBox("Merge & Rebase") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                showMergeDialog = true
                            } label: {
                                Label("Merge Branch...", systemImage: "arrow.triangle.merge")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showRebaseDialog = true
                            } label: {
                                Label("Rebase...", systemImage: "arrow.triangle.branch")
                            }
                            .buttonStyle(.bordered)
                        }

                        // Operation state indicator
                        if operationState.isInProgress {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(operationState.description)
                                    .font(.caption)

                                Spacer()

                                Button("Abort") {
                                    Task {
                                        await abortCurrentOperation()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }

                        Text("Merge combines branches. Rebase replays commits on a new base.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .task {
                    operationState = await viewModel.getOperationState()
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Filtered Branches

    private var filteredLocalBranches: [Branch] {
        let local = viewModel.localBranches
        if searchText.isEmpty {
            return local
        }
        return local.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredRemoteBranches: [Branch] {
        let remote = viewModel.remoteBranches
        if searchText.isEmpty {
            return remote
        }
        return remote.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Actions

    private func abortCurrentOperation() async {
        switch operationState {
        case .mergeInProgress:
            do {
                try await viewModel.abortMerge()
            } catch {
                // Error handled by viewModel
            }
        case .rebaseInProgress:
            do {
                try await viewModel.abortRebase()
            } catch {
                // Error handled by viewModel
            }
        case .cherryPickInProgress, .none:
            break
        }
        operationState = await viewModel.getOperationState()
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        EmptyStateView(
            icon: "arrow.triangle.branch",
            title: "No Repository Open",
            message: "Open a repository to view branches"
        )
    }
}

// MARK: - Branch Row

private struct BranchRow: View {
    let branch: Branch
    let isSelected: Bool
    let onCheckout: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Branch icon
            Image(systemName: branch.isRemote ? "cloud" : "arrow.triangle.branch")
                .foregroundColor(branch.isRemote ? .blue : .green)
                .frame(width: 20)

            // Branch name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(branch.name)
                        .lineLimit(1)
                        .fontWeight(branch.isHead ? .semibold : .regular)

                    if branch.isHead {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                if let tracking = branch.trackingBranch {
                    Text(tracking)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Action buttons (visible on hover for local non-current branches)
            if isHovered && !branch.isRemote && !branch.isHead {
                HStack(spacing: 4) {
                    if let onCheckout = onCheckout {
                        Button {
                            onCheckout()
                        } label: {
                            Image(systemName: "checkmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Checkout")
                    }

                    if let onDelete = onDelete {
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Delete")
                    }
                }
            }

            // Last activity
            if let date = branch.lastCommitDate {
                Text(date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview("With Branches") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    viewModel.branches = [
        Branch(name: "main", isHead: true, isRemote: false, trackingBranch: "origin/main", lastCommitDate: Date()),
        Branch(name: "develop", isHead: false, isRemote: false, trackingBranch: "origin/develop", lastCommitDate: Date().addingTimeInterval(-86400)),
        Branch(name: "feature/login", isHead: false, isRemote: false, lastCommitDate: Date().addingTimeInterval(-172800)),
        Branch(name: "origin/main", isHead: false, isRemote: true, lastCommitDate: Date()),
        Branch(name: "origin/develop", isHead: false, isRemote: true, lastCommitDate: Date().addingTimeInterval(-86400)),
    ]
    return BranchesTab(viewModel: viewModel)
        .frame(width: 900, height: 600)
}

#Preview("No Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    return BranchesTab(viewModel: viewModel)
        .frame(width: 800, height: 500)
}
