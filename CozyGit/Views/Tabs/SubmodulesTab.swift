//
//  SubmodulesTab.swift
//  CozyGit
//

import SwiftUI

struct SubmodulesTab: View {
    @Bindable var viewModel: RepositoryViewModel

    @State private var selectedSubmodule: Submodule?
    @State private var showAddSubmoduleSheet: Bool = false
    @State private var showRemoveConfirmation: Bool = false
    @State private var submoduleToRemove: Submodule?
    @State private var isUpdating: Bool = false
    @State private var updateMessage: String?
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    var body: some View {
        HSplitView {
            // Left: Submodule List
            submoduleListView
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)

            // Right: Submodule Details
            submoduleDetailView
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .navigationTitle("Submodules")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showAddSubmoduleSheet) {
            AddSubmoduleSheet { url, path, branch in
                await addSubmodule(url: url, path: path, branch: branch)
            }
        }
        .confirmationDialog(
            "Remove Submodule",
            isPresented: $showRemoveConfirmation,
            presenting: submoduleToRemove
        ) { submodule in
            Button("Remove", role: .destructive) {
                Task {
                    await removeSubmodule(submodule)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { submodule in
            Text("Are you sure you want to remove the submodule '\(submodule.displayName)'? This will remove the submodule directory and its configuration.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onAppear {
            if selectedSubmodule == nil, let first = viewModel.submodules.first {
                selectedSubmodule = first
            }
        }
    }

    // MARK: - Submodule List View

    private var submoduleListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Submodules")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.submodules.count)")
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

            if viewModel.submodules.isEmpty {
                ContentUnavailableView {
                    Label("No Submodules", systemImage: "shippingbox")
                } description: {
                    Text("This repository has no submodules.")
                } actions: {
                    Button("Add Submodule") {
                        showAddSubmoduleSheet = true
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                List(viewModel.submodules, selection: $selectedSubmodule) { submodule in
                    SubmoduleRow(submodule: submodule, isSelected: selectedSubmodule?.id == submodule.id)
                        .tag(submodule)
                        .contextMenu {
                            if !submodule.isInitialized {
                                Button {
                                    Task {
                                        await initSubmodule(submodule)
                                    }
                                } label: {
                                    Label("Initialize", systemImage: "arrow.down.circle")
                                }
                            }

                            Button {
                                Task {
                                    await updateSubmodule(submodule)
                                }
                            } label: {
                                Label("Update", systemImage: "arrow.clockwise")
                            }
                            .disabled(!submodule.isInitialized)

                            Divider()

                            Button(role: .destructive) {
                                submoduleToRemove = submodule
                                showRemoveConfirmation = true
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.sidebar)
            }
        }
    }

    // MARK: - Submodule Detail View

    private var submoduleDetailView: some View {
        VStack(spacing: 0) {
            if let submodule = selectedSubmodule {
                // Header
                HStack {
                    Image(systemName: "shippingbox")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(submodule.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        HStack(spacing: 8) {
                            statusBadge(for: submodule)

                            if let branch = submodule.branch {
                                Label(branch, systemImage: "arrow.triangle.branch")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    // Action Buttons
                    if !submodule.isInitialized {
                        Button {
                            Task {
                                await initSubmodule(submodule)
                            }
                        } label: {
                            Label("Initialize", systemImage: "arrow.down.circle")
                        }
                    }

                    Button {
                        Task {
                            await updateSubmodule(submodule)
                        }
                    } label: {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Label("Update", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isUpdating || !submodule.isInitialized)

                    Button(role: .destructive) {
                        submoduleToRemove = submodule
                        showRemoveConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Details
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Path Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Path", systemImage: "folder")
                                    .font(.headline)

                                HStack {
                                    Text(submodule.path)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)

                                    Spacer()

                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(submodule.path, forType: .string)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Copy path")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // URL Section
                        if let url = submodule.url {
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Repository URL", systemImage: "link")
                                        .font(.headline)

                                    HStack {
                                        Text(url.absoluteString)
                                            .font(.system(.body, design: .monospaced))
                                            .textSelection(.enabled)

                                        Spacer()

                                        Button {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(url.absoluteString, forType: .string)
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Copy URL")
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Commit Section
                        if let hash = submodule.commitHash {
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Current Commit", systemImage: "number")
                                        .font(.headline)

                                    HStack {
                                        Text(hash)
                                            .font(.system(.body, design: .monospaced))
                                            .textSelection(.enabled)

                                        Spacer()

                                        Button {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(hash, forType: .string)
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Copy commit hash")
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Status Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Status", systemImage: "info.circle")
                                    .font(.headline)

                                HStack(spacing: 12) {
                                    statusIcon(for: submodule)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(submodule.statusDescription)
                                            .fontWeight(.medium)

                                        if !submodule.isInitialized {
                                            Text("Initialize the submodule to download its contents")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else if submodule.hasChanges {
                                            Text("The submodule has local modifications")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Update Message
                        if let message = updateMessage {
                            GroupBox {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(message)
                                        .font(.callout)
                                    Spacer()
                                    Button {
                                        updateMessage = nil
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
                    Label("No Submodule Selected", systemImage: "shippingbox")
                } description: {
                    Text("Select a submodule from the list to view its details.")
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showAddSubmoduleSheet = true
            } label: {
                Label("Add Submodule", systemImage: "plus")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    await updateAllSubmodules()
                }
            } label: {
                Label("Update All", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.submodules.isEmpty || isUpdating)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    await viewModel.loadSubmodules()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statusBadge(for submodule: Submodule) -> some View {
        if !submodule.isInitialized {
            Text("Not Initialized")
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray)
                .cornerRadius(4)
        } else if submodule.hasChanges {
            Text("Modified")
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange)
                .cornerRadius(4)
        } else {
            Text("Up to date")
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green)
                .cornerRadius(4)
        }
    }

    @ViewBuilder
    private func statusIcon(for submodule: Submodule) -> some View {
        if !submodule.isInitialized {
            Image(systemName: "questionmark.circle.fill")
                .font(.title2)
                .foregroundColor(.gray)
        } else if submodule.hasChanges {
            Image(systemName: "pencil.circle.fill")
                .font(.title2)
                .foregroundColor(.orange)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
        }
    }

    // MARK: - Actions

    private func addSubmodule(url: URL, path: String, branch: String?) async {
        do {
            try await viewModel.addSubmodule(url: url, path: path, branch: branch)
            // Select the new submodule
            if let newSubmodule = viewModel.submodules.first(where: { $0.path == path }) {
                selectedSubmodule = newSubmodule
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func initSubmodule(_ submodule: Submodule) async {
        isUpdating = true
        do {
            try await viewModel.initSubmodule(submodule)
            updateMessage = "Initialized \(submodule.displayName)"
            // Refresh selection
            selectedSubmodule = viewModel.submodules.first { $0.path == submodule.path }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isUpdating = false
    }

    private func updateSubmodule(_ submodule: Submodule) async {
        isUpdating = true
        updateMessage = nil
        do {
            let result = try await viewModel.updateSubmodule(submodule, recursive: true)
            if result.success {
                updateMessage = "Updated \(submodule.displayName)"
                // Refresh selection
                selectedSubmodule = viewModel.submodules.first { $0.path == submodule.path }
            } else if let error = result.errorMessage {
                errorMessage = error
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isUpdating = false
    }

    private func updateAllSubmodules() async {
        isUpdating = true
        updateMessage = nil
        do {
            let results = try await viewModel.updateAllSubmodules(recursive: true, initialize: true)
            let successful = results.filter { $0.success }.count
            let failed = results.filter { !$0.success }.count

            if failed == 0 {
                updateMessage = "Updated \(successful) submodule(s)"
            } else {
                updateMessage = "Updated \(successful), failed \(failed) submodule(s)"
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isUpdating = false
    }

    private func removeSubmodule(_ submodule: Submodule) async {
        do {
            try await viewModel.removeSubmodule(submodule)
            if selectedSubmodule?.id == submodule.id {
                selectedSubmodule = viewModel.submodules.first
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Submodule Row

struct SubmoduleRow: View {
    let submodule: Submodule
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Status Icon
            Group {
                if !submodule.isInitialized {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.gray)
                } else if submodule.hasChanges {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(submodule.displayName)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(submodule.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let hash = submodule.shortHash {
                        Text(hash)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Add Submodule Sheet

struct AddSubmoduleSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var repositoryURL: String = ""
    @State private var localPath: String = ""
    @State private var branch: String = ""
    @State private var isAdding: Bool = false
    @State private var errorMessage: String?

    let onAdd: (URL, String, String?) async -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Submodule")
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
                    TextField("Repository URL", text: $repositoryURL)
                        .textFieldStyle(.roundedBorder)

                    TextField("Local Path", text: $localPath)
                        .textFieldStyle(.roundedBorder)

                    TextField("Branch (optional)", text: $branch)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Submodule Details")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repository URL: The Git repository to add as a submodule")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Local Path: Where to place the submodule in this repository")
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
                        await addSubmodule()
                    }
                } label: {
                    if isAdding {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Add Submodule")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValidInput || isAdding)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 380)
    }

    private var isValidInput: Bool {
        !repositoryURL.isEmpty && !localPath.isEmpty
    }

    private func addSubmodule() async {
        guard isValidInput else { return }

        guard let url = URL(string: repositoryURL) else {
            errorMessage = "Invalid repository URL"
            return
        }

        isAdding = true
        errorMessage = nil

        let branchValue = branch.isEmpty ? nil : branch
        await onAdd(url, localPath, branchValue)

        isAdding = false
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    SubmodulesTab(viewModel: RepositoryViewModel(gitService: GitService(shellExecutor: ShellExecutor())))
        .frame(width: 900, height: 600)
}
