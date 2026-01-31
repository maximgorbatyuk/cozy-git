//
//  RemotesTab.swift
//  CozyGit
//

import SwiftUI

struct RemotesTab: View {
    @Bindable var viewModel: RepositoryViewModel
    @State private var selectedRemote: Remote?
    @State private var showAddRemoteSheet: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var remoteToDelete: Remote?
    @State private var isFetching: Bool = false
    @State private var fetchMessage: String?

    var body: some View {
        HSplitView {
            // Left: Remote List
            remoteListView
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 350)

            // Right: Remote Details
            remoteDetailView
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .navigationTitle("Remotes")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showAddRemoteSheet) {
            AddRemoteSheet { name, url in
                await addRemote(name: name, url: url)
            }
        }
        .confirmationDialog(
            "Delete Remote",
            isPresented: $showDeleteConfirmation,
            presenting: remoteToDelete
        ) { remote in
            Button("Delete", role: .destructive) {
                Task {
                    await deleteRemote(remote)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { remote in
            Text("Are you sure you want to delete the remote '\(remote.name)'? This cannot be undone.")
        }
        .onAppear {
            if selectedRemote == nil, let first = viewModel.remotes.first {
                selectedRemote = first
            }
        }
    }

    // MARK: - Remote List View

    private var remoteListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Remotes")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.remotes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(10)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if viewModel.remotes.isEmpty {
                ContentUnavailableView {
                    Label("No Remotes", systemImage: "network")
                } description: {
                    Text("Add a remote to connect to a remote repository.")
                } actions: {
                    Button("Add Remote") {
                        showAddRemoteSheet = true
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                List(viewModel.remotes, selection: $selectedRemote) { remote in
                    RemoteRow(remote: remote, isSelected: selectedRemote?.id == remote.id)
                        .tag(remote)
                        .contextMenu {
                            Button {
                                Task {
                                    await fetchFromRemote(remote)
                                }
                            } label: {
                                Label("Fetch", systemImage: "arrow.down.circle")
                            }

                            Divider()

                            Button(role: .destructive) {
                                remoteToDelete = remote
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(remote.name == "origin")
                        }
                }
                .listStyle(.sidebar)
            }
        }
    }

    // MARK: - Remote Detail View

    private var remoteDetailView: some View {
        VStack(spacing: 0) {
            if let remote = selectedRemote {
                // Header
                HStack {
                    Image(systemName: "network")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(remote.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if remote.name == "origin" {
                            Text("Default Remote")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Fetch Button
                    Button {
                        Task {
                            await fetchFromRemote(remote)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isFetching {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                            Text("Fetch")
                        }
                    }
                    .disabled(isFetching)

                    // Delete Button (not for origin)
                    if remote.name != "origin" {
                        Button(role: .destructive) {
                            remoteToDelete = remote
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Remote Details
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Fetch URL Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Fetch URL", systemImage: "arrow.down.doc")
                                    .font(.headline)

                                if let fetchURL = remote.fetchURL {
                                    HStack {
                                        Text(fetchURL.absoluteString)
                                            .font(.system(.body, design: .monospaced))
                                            .textSelection(.enabled)

                                        Spacer()

                                        Button {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(fetchURL.absoluteString, forType: .string)
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Copy URL")
                                    }
                                } else {
                                    Text("No fetch URL configured")
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Push URL Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Push URL", systemImage: "arrow.up.doc")
                                    .font(.headline)

                                if let pushURL = remote.pushURL {
                                    HStack {
                                        Text(pushURL.absoluteString)
                                            .font(.system(.body, design: .monospaced))
                                            .textSelection(.enabled)

                                        Spacer()

                                        Button {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(pushURL.absoluteString, forType: .string)
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Copy URL")
                                    }
                                } else {
                                    Text("No push URL configured")
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Remote Branches Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Remote Branches", systemImage: "arrow.triangle.branch")
                                        .font(.headline)

                                    Spacer()

                                    Text("\(remoteBranches(for: remote).count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(10)
                                }

                                let branches = remoteBranches(for: remote)
                                if branches.isEmpty {
                                    Text("No branches from this remote")
                                        .foregroundColor(.secondary)
                                        .italic()
                                } else {
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 8) {
                                        ForEach(branches) { branch in
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.triangle.branch")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text(shortName(for: branch, remote: remote))
                                                    .font(.caption)
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Fetch Result Message
                        if let message = fetchMessage {
                            GroupBox {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(message)
                                        .font(.callout)
                                    Spacer()
                                    Button {
                                        fetchMessage = nil
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView {
                    Label("No Remote Selected", systemImage: "network")
                } description: {
                    Text("Select a remote from the list to view its details.")
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showAddRemoteSheet = true
            } label: {
                Label("Add Remote", systemImage: "plus")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    await viewModel.loadRemotes()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    // MARK: - Helpers

    private func remoteBranches(for remote: Remote) -> [Branch] {
        viewModel.branches.filter { branch in
            branch.isRemote && branch.name.hasPrefix("\(remote.name)/")
        }
    }

    private func shortName(for branch: Branch, remote: Remote) -> String {
        // Remove the remote prefix (e.g., "origin/main" -> "main")
        let prefix = "\(remote.name)/"
        if branch.name.hasPrefix(prefix) {
            return String(branch.name.dropFirst(prefix.count))
        }
        return branch.name
    }

    // MARK: - Actions

    private func addRemote(name: String, url: URL) async {
        do {
            try await viewModel.addRemote(name: name, url: url)
            // Select the new remote
            if let newRemote = viewModel.remotes.first(where: { $0.name == name }) {
                selectedRemote = newRemote
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func deleteRemote(_ remote: Remote) async {
        do {
            try await viewModel.removeRemote(name: remote.name)
            if selectedRemote?.id == remote.id {
                selectedRemote = viewModel.remotes.first
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func fetchFromRemote(_ remote: Remote) async {
        isFetching = true
        fetchMessage = nil

        let result = await viewModel.fetchFromRemote(remote, prune: false)

        isFetching = false

        if result.success {
            if !result.updatedBranches.isEmpty {
                fetchMessage = "Fetched \(result.updatedBranches.count) updated branch(es) from \(remote.name)"
            } else {
                fetchMessage = "Fetched from \(remote.name). Already up to date."
            }
        } else if let error = result.errorMessage {
            viewModel.errorMessage = error
        }
    }
}

// MARK: - Remote Row

struct RemoteRow: View {
    let remote: Remote
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: remote.name == "origin" ? "network.badge.shield.half.filled" : "network")
                .font(.title3)
                .foregroundColor(remote.name == "origin" ? .accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(remote.name)
                        .fontWeight(.medium)

                    if remote.name == "origin" {
                        Text("default")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .cornerRadius(4)
                    }
                }

                if let fetchURL = remote.fetchURL {
                    Text(fetchURL.host ?? fetchURL.absoluteString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Add Remote Sheet

struct AddRemoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remoteName: String = ""
    @State private var remoteURL: String = ""
    @State private var isAdding: Bool = false
    @State private var errorMessage: String?

    let onAdd: (String, URL) async -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Remote")
                    .font(.headline)
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
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Form
            Form {
                Section {
                    TextField("Remote Name", text: $remoteName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Remote URL", text: $remoteURL)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Remote Details")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Examples:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("https://github.com/user/repo.git")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("git@github.com:user/repo.git")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task {
                        await addRemote()
                    }
                } label: {
                    if isAdding {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Add Remote")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValidInput || isAdding)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 450, height: 350)
    }

    private var isValidInput: Bool {
        !remoteName.isEmpty &&
        !remoteURL.isEmpty &&
        remoteName.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil
    }

    private func addRemote() async {
        guard isValidInput else { return }

        // Parse URL - support both HTTPS and SSH formats
        let urlString = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var url: URL?

        // Try standard URL parsing first
        url = URL(string: urlString)

        // If that fails, it might be SSH format (git@github.com:user/repo.git)
        if url == nil || url?.scheme == nil {
            // Convert SSH format to a parseable URL for storage
            if urlString.contains("@") && urlString.contains(":") {
                // SSH format - create a pseudo URL
                let converted = urlString
                    .replacingOccurrences(of: ":", with: "/")
                    .replacingOccurrences(of: "git@", with: "ssh://git@")
                url = URL(string: converted)
            }
        }

        // If we still don't have a valid URL, try with https prefix
        if url == nil {
            url = URL(string: "https://\(urlString)")
        }

        guard let finalURL = url else {
            errorMessage = "Invalid URL format"
            return
        }

        isAdding = true
        errorMessage = nil

        await onAdd(remoteName, finalURL)

        isAdding = false
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    RemotesTab(viewModel: RepositoryViewModel(gitService: GitService(shellExecutor: ShellExecutor())))
        .frame(width: 800, height: 500)
}
