//
//  StashTab.swift
//  CozyGit
//
//  Phase 11: Stash Operations

import SwiftUI

struct StashTab: View {
    @Bindable var viewModel: RepositoryViewModel

    @State private var showCreateStashSheet = false
    @State private var showDropConfirmation = false
    @State private var stashToDelete: Stash?
    @State private var selectedStash: Stash?
    @State private var stashDiff: Diff?
    @State private var isLoadingDiff = false

    var body: some View {
        if viewModel.repository != nil {
            stashContent
                .task {
                    await viewModel.loadStashes()
                }
                .sheet(isPresented: $showCreateStashSheet) {
                    CreateStashSheet { message, includeUntracked in
                        await viewModel.createStash(message: message, includeUntracked: includeUntracked)
                    }
                }
                .alert("Drop Stash", isPresented: $showDropConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Drop", role: .destructive) {
                        if let stash = stashToDelete {
                            Task {
                                await viewModel.dropStash(stash)
                                if selectedStash?.index == stash.index {
                                    selectedStash = nil
                                    stashDiff = nil
                                }
                            }
                        }
                    }
                } message: {
                    if let stash = stashToDelete {
                        Text("Are you sure you want to drop '\(stash.displayName)'? This action cannot be undone.")
                    }
                }
        } else {
            noRepositoryView
        }
    }

    // MARK: - Stash Content

    private var stashContent: some View {
        HSplitView {
            // Left: Stash List
            stashListPanel
                .frame(minWidth: 280, maxWidth: 400)

            // Right: Stash Details / Diff
            stashDetailPanel
                .frame(minWidth: 400)
        }
    }

    // MARK: - Stash List Panel

    private var stashListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Stashes", systemImage: "tray.and.arrow.down")
                    .font(.headline)

                Spacer()

                if !viewModel.stashes.isEmpty {
                    Text("\(viewModel.stashes.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }

                Button {
                    showCreateStashSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new stash")
                .disabled(viewModel.fileStatuses.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // Stash List
            if viewModel.stashes.isEmpty {
                emptyStashView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.stashes) { stash in
                            StashRow(
                                stash: stash,
                                isSelected: selectedStash?.index == stash.index,
                                onApply: {
                                    Task {
                                        await viewModel.applyStash(stash, pop: false)
                                    }
                                },
                                onPop: {
                                    Task {
                                        await viewModel.applyStash(stash, pop: true)
                                        if selectedStash?.index == stash.index {
                                            selectedStash = nil
                                            stashDiff = nil
                                        }
                                    }
                                },
                                onDrop: {
                                    stashToDelete = stash
                                    showDropConfirmation = true
                                }
                            )
                            .background(selectedStash?.index == stash.index ? Color.accentColor.opacity(0.15) : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedStash = stash
                                Task {
                                    await loadStashDiff(stash)
                                }
                            }

                            if stash.id != viewModel.stashes.last?.id {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stash Detail Panel

    private var stashDetailPanel: some View {
        VStack(spacing: 0) {
            if let stash = selectedStash {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stash.displayName)
                            .font(.headline)
                        Text(stash.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    // Action buttons
                    HStack(spacing: 8) {
                        Button {
                            Task {
                                await viewModel.applyStash(stash, pop: false)
                            }
                        } label: {
                            Label("Apply", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.bordered)
                        .help("Apply stash without removing it")

                        Button {
                            Task {
                                await viewModel.applyStash(stash, pop: true)
                                selectedStash = nil
                                stashDiff = nil
                            }
                        } label: {
                            Label("Pop", systemImage: "tray.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Apply stash and remove it")
                    }
                }
                .padding()
                .background(.bar)

                Divider()

                // Stash info
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        if let branch = stash.branchName {
                            LabeledContent("Branch", value: branch)
                        }
                        LabeledContent("Date", value: stash.date.formatted(date: .long, time: .shortened))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()

                Divider()

                // Diff view
                if isLoadingDiff {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading changes...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let diff = stashDiff, !diff.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Changes")
                                .font(.headline)
                            Spacer()
                            Text("\(diff.files.count) file(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        Divider()

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(diff.files) { file in
                                    StashFileRow(file: file)

                                    if file.id != diff.files.last?.id {
                                        Divider()
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No changes to display")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // No stash selected
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a stash to view details")
                        .foregroundColor(.secondary)

                    if !viewModel.fileStatuses.isEmpty {
                        Divider()
                            .frame(width: 200)
                            .padding(.vertical, 8)

                        Button {
                            showCreateStashSheet = true
                        } label: {
                            Label("Create New Stash", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Empty Stash View

    private var emptyStashView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Stashes")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Stashes allow you to save your uncommitted changes temporarily and restore them later.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            if !viewModel.fileStatuses.isEmpty {
                Button {
                    showCreateStashSheet = true
                } label: {
                    Label("Stash Current Changes", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Make some changes to create a stash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Load Stash Diff

    private func loadStashDiff(_ stash: Stash) async {
        isLoadingDiff = true
        let gitService = DependencyContainer.shared.gitService
        stashDiff = try? await gitService.getStashDiff(index: stash.index)
        isLoadingDiff = false
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        EmptyStateView(
            icon: "tray.and.arrow.down",
            title: "No Repository Open",
            message: "Open a repository to manage stashes"
        )
    }
}

// MARK: - Stash Row

private struct StashRow: View {
    let stash: Stash
    let isSelected: Bool
    let onApply: () -> Void
    let onPop: () -> Void
    let onDrop: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Stash icon
            Image(systemName: "tray.full")
                .foregroundColor(.accentColor)
                .frame(width: 24)

            // Stash info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stash.displayName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)

                    if let branch = stash.branchName {
                        Text("on \(branch)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(stash.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(stash.date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action buttons (visible on hover or selection)
            if isHovered || isSelected {
                HStack(spacing: 4) {
                    Button {
                        onApply()
                    } label: {
                        Image(systemName: "arrow.down.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Apply")

                    Button {
                        onPop()
                    } label: {
                        Image(systemName: "tray.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Pop")

                    Button {
                        onDrop()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Drop")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Stash File Row

private struct StashFileRow: View {
    let file: FileDiff

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            fileStatusIcon

            // File path
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if file.isRenamed {
                    Text("Renamed from \(file.oldPath)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Stats
            HStack(spacing: 8) {
                if file.additions > 0 {
                    Text("+\(file.additions)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                if file.deletions > 0 {
                    Text("-\(file.deletions)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var fileStatusIcon: some View {
        Group {
            if file.isNewFile {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
            } else if file.isDeletedFile {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            } else if file.isRenamed {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            } else if file.isBinary {
                Image(systemName: "doc.zipper")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .frame(width: 20)
    }
}

// MARK: - Create Stash Sheet

private struct CreateStashSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var message: String = ""
    @State private var includeUntracked: Bool = false
    @State private var isCreating: Bool = false

    let onCreate: (String?, Bool) async -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Stash")
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
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Describe your changes...", text: $message)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Include untracked files", isOn: $includeUntracked)
                    .help("Also stash files that are not yet tracked by git")

                Text("This will save your current working directory changes and revert to a clean state.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

                Button {
                    isCreating = true
                    Task {
                        await onCreate(message.isEmpty ? nil : message, includeUntracked)
                        isCreating = false
                        dismiss()
                    }
                } label: {
                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Create Stash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreating)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400)
    }
}

// MARK: - Preview

#Preview("With Stashes") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    viewModel.stashes = [
        Stash(index: 0, message: "WIP: Feature implementation", branchName: "feature/auth", date: Date()),
        Stash(index: 1, message: "Quick save before merge", branchName: "main", date: Date().addingTimeInterval(-86400)),
        Stash(index: 2, message: "Experimental changes", branchName: "develop", date: Date().addingTimeInterval(-172800)),
    ]
    return StashTab(viewModel: viewModel)
        .frame(width: 900, height: 600)
}

#Preview("Empty Stashes") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    return StashTab(viewModel: viewModel)
        .frame(width: 900, height: 600)
}

#Preview("No Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    return StashTab(viewModel: viewModel)
        .frame(width: 900, height: 600)
}
