//
//  CleanupTab.swift
//  CozyGit
//

import SwiftUI

struct CleanupTab: View {
    @Bindable var viewModel: RepositoryViewModel

    @State private var mergedBranches: [Branch] = []
    @State private var staleBranches: [Branch] = []
    @State private var selectedMergedBranches: Set<String> = []
    @State private var selectedStaleBranches: Set<String> = []
    @State private var isScanning = false
    @State private var isPruning = false
    @State private var isDeleting = false
    @State private var scanCompleted = false
    @State private var staleDaysThreshold: Int = 90
    @State private var baseBranch: String = "main"
    @State private var showDeleteConfirmation = false
    @State private var branchesToDelete: [Branch] = []

    var body: some View {
        if viewModel.repository != nil {
            cleanupContent
                .task {
                    // Set default base branch to current branch
                    if let current = viewModel.repository?.currentBranch {
                        baseBranch = current
                    }
                }
                .alert("Delete Branches", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        Task {
                            await deleteBranches(branchesToDelete)
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete \(branchesToDelete.count) branch(es)? This action cannot be undone.")
                }
        } else {
            noRepositoryView
        }
    }

    // MARK: - Cleanup Content

    private var cleanupContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Scan Configuration
                scanConfigurationSection

                // Merged Branches Section
                mergedBranchesSection

                // Stale Branches Section
                staleBranchesSection

                // Prune Remote Section
                pruneRemoteSection
            }
            .padding()
        }
    }

    // MARK: - Scan Configuration

    private var scanConfigurationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Scan Configuration", systemImage: "gearshape")
                    .font(.headline)

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base Branch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Base Branch", selection: $baseBranch) {
                            ForEach(viewModel.localBranches) { branch in
                                Text(branch.name).tag(branch.name)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stale Threshold (days)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Days", value: $staleDaysThreshold, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    Spacer()

                    Button {
                        Task {
                            await scanBranches()
                        }
                    } label: {
                        if isScanning {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal, 8)
                        } else {
                            Label("Scan Branches", systemImage: "magnifyingglass")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isScanning)
                }
            }
        }
    }

    // MARK: - Merged Branches Section

    private var mergedBranchesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Merged Branches", systemImage: "arrow.triangle.merge")
                        .font(.headline)

                    Spacer()

                    if !mergedBranches.isEmpty {
                        Text("\(mergedBranches.count) found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Branches that have been fully merged into \(baseBranch) and can be safely deleted.")
                    .foregroundColor(.secondary)
                    .font(.caption)

                if !scanCompleted {
                    Text("Click 'Scan Branches' to find merged branches")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if mergedBranches.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No merged branches found")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Select all / Deselect all
                    HStack {
                        Button {
                            selectedMergedBranches = Set(mergedBranches.map { $0.name })
                        } label: {
                            Text("Select All")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            selectedMergedBranches.removeAll()
                        } label: {
                            Text("Deselect All")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        if !selectedMergedBranches.isEmpty {
                            Button(role: .destructive) {
                                branchesToDelete = mergedBranches.filter { selectedMergedBranches.contains($0.name) }
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Selected (\(selectedMergedBranches.count))", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }

                    // Branch list
                    VStack(spacing: 0) {
                        ForEach(mergedBranches) { branch in
                            CleanupBranchRow(
                                branch: branch,
                                isSelected: selectedMergedBranches.contains(branch.name),
                                type: .merged
                            ) {
                                if selectedMergedBranches.contains(branch.name) {
                                    selectedMergedBranches.remove(branch.name)
                                } else {
                                    selectedMergedBranches.insert(branch.name)
                                }
                            }

                            if branch.id != mergedBranches.last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Stale Branches Section

    private var staleBranchesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Stale Branches", systemImage: "clock.badge.xmark")
                        .font(.headline)

                    Spacer()

                    if !staleBranches.isEmpty {
                        Text("\(staleBranches.count) found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Branches with no activity for more than \(staleDaysThreshold) days.")
                    .foregroundColor(.secondary)
                    .font(.caption)

                if !scanCompleted {
                    Text("Click 'Scan Branches' to find stale branches")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if staleBranches.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No stale branches found")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Select all / Deselect all
                    HStack {
                        Button {
                            selectedStaleBranches = Set(staleBranches.map { $0.name })
                        } label: {
                            Text("Select All")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            selectedStaleBranches.removeAll()
                        } label: {
                            Text("Deselect All")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        if !selectedStaleBranches.isEmpty {
                            Button(role: .destructive) {
                                branchesToDelete = staleBranches.filter { selectedStaleBranches.contains($0.name) }
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Selected (\(selectedStaleBranches.count))", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }

                    // Branch list
                    VStack(spacing: 0) {
                        ForEach(staleBranches) { branch in
                            CleanupBranchRow(
                                branch: branch,
                                isSelected: selectedStaleBranches.contains(branch.name),
                                type: .stale
                            ) {
                                if selectedStaleBranches.contains(branch.name) {
                                    selectedStaleBranches.remove(branch.name)
                                } else {
                                    selectedStaleBranches.insert(branch.name)
                                }
                            }

                            if branch.id != staleBranches.last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Prune Remote Section

    private var pruneRemoteSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Prune Remote Tracking Branches", systemImage: "network.slash")
                    .font(.headline)

                Text("Remove local references to remote branches that no longer exist on the remote server.")
                    .foregroundColor(.secondary)
                    .font(.caption)

                HStack {
                    Button {
                        Task {
                            await pruneRemote()
                        }
                    } label: {
                        if isPruning {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal, 8)
                        } else {
                            Label("Fetch & Prune", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPruning)

                    Text("This will run 'git fetch --prune' to clean up stale remote references.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func scanBranches() async {
        isScanning = true
        scanCompleted = false

        // Clear previous results
        mergedBranches = []
        staleBranches = []
        selectedMergedBranches.removeAll()
        selectedStaleBranches.removeAll()

        // Get merged branches
        let merged = await viewModel.getMergedBranches(into: baseBranch)
        // Filter out the base branch itself and protected branches
        mergedBranches = merged.filter { branch in
            branch.name != baseBranch &&
            !branch.isCurrent &&
            !branch.isProtected
        }

        // Get stale branches
        let stale = await viewModel.getStaleBranches(olderThanDays: staleDaysThreshold)
        // Filter out current branch and protected branches
        staleBranches = stale.filter { branch in
            !branch.isCurrent &&
            !branch.isProtected
        }

        isScanning = false
        scanCompleted = true
    }

    private func pruneRemote() async {
        isPruning = true
        await viewModel.fetch(prune: true)
        await viewModel.loadBranches()
        isPruning = false
    }

    private func deleteBranches(_ branches: [Branch]) async {
        isDeleting = true

        for branch in branches {
            await viewModel.deleteBranch(branch, force: false)

            // Remove from local lists
            mergedBranches.removeAll { $0.id == branch.id }
            staleBranches.removeAll { $0.id == branch.id }
            selectedMergedBranches.remove(branch.name)
            selectedStaleBranches.remove(branch.name)
        }

        branchesToDelete.removeAll()
        isDeleting = false
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        EmptyStateView(
            icon: "sparkles",
            title: "No Repository Open",
            message: "Open a repository to access cleanup tools"
        )
    }
}

// MARK: - Cleanup Branch Row

private struct CleanupBranchRow: View {
    let branch: Branch
    let isSelected: Bool
    let type: BranchType
    let onToggle: () -> Void

    enum BranchType {
        case merged
        case stale
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                onToggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            // Branch icon
            Image(systemName: "arrow.triangle.branch")
                .foregroundColor(.green)
                .frame(width: 20)

            // Branch info
            VStack(alignment: .leading, spacing: 2) {
                Text(branch.name)
                    .lineLimit(1)

                if let date = branch.lastCommitDate {
                    Text("Last activity: \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Type badge
            Text(type == .merged ? "Merged" : "Stale")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(type == .merged ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundColor(type == .merged ? .green : .orange)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - Preview

#Preview("With Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    viewModel.branches = [
        Branch(name: "main", isHead: true, isRemote: false),
        Branch(name: "develop", isHead: false, isRemote: false),
    ]
    return CleanupTab(viewModel: viewModel)
        .frame(width: 700, height: 700)
}

#Preview("No Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    return CleanupTab(viewModel: viewModel)
        .frame(width: 700, height: 600)
}
