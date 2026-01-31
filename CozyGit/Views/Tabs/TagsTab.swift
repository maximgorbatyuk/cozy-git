//
//  TagsTab.swift
//  CozyGit
//
//  Phase 12: Tag Operations

import SwiftUI

struct TagsTab: View {
    @Bindable var viewModel: RepositoryViewModel

    @State private var showCreateTagSheet = false
    @State private var showDeleteConfirmation = false
    @State private var tagToDelete: Tag?
    @State private var selectedTag: Tag?
    @State private var isPushingTag = false
    @State private var isPushingAllTags = false

    var body: some View {
        if viewModel.repository != nil {
            tagContent
                .task {
                    await viewModel.loadTags()
                }
                .sheet(isPresented: $showCreateTagSheet) {
                    CreateTagSheet(
                        commits: viewModel.commits,
                        onCreate: { name, message, commit in
                            await viewModel.createTag(name: name, message: message, commit: commit)
                        }
                    )
                }
                .alert("Delete Tag", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete Local", role: .destructive) {
                        if let tag = tagToDelete {
                            Task {
                                await viewModel.deleteTag(tag)
                                if selectedTag?.name == tag.name {
                                    selectedTag = nil
                                }
                            }
                        }
                    }
                    Button("Delete Local & Remote", role: .destructive) {
                        if let tag = tagToDelete {
                            Task {
                                await viewModel.deleteTag(tag)
                                await viewModel.deleteTagFromRemote(tag)
                                if selectedTag?.name == tag.name {
                                    selectedTag = nil
                                }
                            }
                        }
                    }
                } message: {
                    if let tag = tagToDelete {
                        Text("Are you sure you want to delete tag '\(tag.name)'?")
                    }
                }
        } else {
            noRepositoryView
        }
    }

    // MARK: - Tag Content

    private var tagContent: some View {
        HSplitView {
            // Left: Tag List
            tagListPanel
                .frame(minWidth: 280, maxWidth: 400)

            // Right: Tag Details
            tagDetailPanel
                .frame(minWidth: 400)
        }
    }

    // MARK: - Tag List Panel

    private var tagListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Tags", systemImage: "tag")
                    .font(.headline)

                Spacer()

                if !viewModel.tags.isEmpty {
                    Text("\(viewModel.tags.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }

                Button {
                    showCreateTagSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new tag")

                if !viewModel.tags.isEmpty {
                    Button {
                        Task {
                            isPushingAllTags = true
                            _ = try? await viewModel.pushTags()
                            isPushingAllTags = false
                        }
                    } label: {
                        if isPushingAllTags {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.circle")
                        }
                    }
                    .buttonStyle(.borderless)
                    .help("Push all tags to remote")
                    .disabled(isPushingAllTags)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // Tag List
            if viewModel.tags.isEmpty {
                emptyTagView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedTags) { tag in
                            TagRow(
                                tag: tag,
                                isSelected: selectedTag?.name == tag.name,
                                onPush: {
                                    Task {
                                        isPushingTag = true
                                        _ = try? await viewModel.pushTags(tags: [tag.name])
                                        isPushingTag = false
                                    }
                                },
                                onDelete: {
                                    tagToDelete = tag
                                    showDeleteConfirmation = true
                                }
                            )
                            .background(selectedTag?.name == tag.name ? Color.accentColor.opacity(0.15) : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTag = tag
                            }

                            if tag.id != sortedTags.last?.id {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tag Detail Panel

    private var tagDetailPanel: some View {
        VStack(spacing: 0) {
            if let tag = selectedTag {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: tag.isAnnotated ? "tag.fill" : "tag")
                                .foregroundColor(.orange)
                            Text(tag.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        HStack(spacing: 8) {
                            Text(tag.isAnnotated ? "Annotated tag" : "Lightweight tag")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(tag.isAnnotated ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.2))
                                .foregroundColor(tag.isAnnotated ? .orange : .secondary)
                                .clipShape(Capsule())

                            Label(tag.commitHash, systemImage: "number")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Action buttons
                    HStack(spacing: 8) {
                        Button {
                            Task {
                                isPushingTag = true
                                _ = try? await viewModel.pushTags(tags: [tag.name])
                                isPushingTag = false
                            }
                        } label: {
                            if isPushingTag {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Push", systemImage: "arrow.up")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPushingTag)
                        .help("Push tag to remote")

                        Button(role: .destructive) {
                            tagToDelete = tag
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(.bar)

                Divider()

                // Tag details
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Message (for annotated tags)
                        if let message = tag.message, !message.isEmpty {
                            GroupBox("Message") {
                                Text(message)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Tagger info (for annotated tags)
                        if tag.isAnnotated {
                            GroupBox("Tagger") {
                                VStack(alignment: .leading, spacing: 8) {
                                    if let name = tag.taggerName {
                                        LabeledContent("Name", value: name)
                                    }
                                    if let email = tag.taggerEmail {
                                        LabeledContent("Email", value: email)
                                    }
                                    if let date = tag.date {
                                        LabeledContent("Date", value: date.formatted(date: .long, time: .shortened))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Commit info
                        GroupBox("Commit") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Hash:")
                                        .foregroundColor(.secondary)
                                    Text(tag.commitHash)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)

                                    Spacer()

                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(tag.commitHash, forType: .string)
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
                    .padding()
                }
            } else {
                // No tag selected
                VStack(spacing: 12) {
                    Image(systemName: "tag")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a tag to view details")
                        .foregroundColor(.secondary)

                    Divider()
                        .frame(width: 200)
                        .padding(.vertical, 8)

                    Button {
                        showCreateTagSheet = true
                    } label: {
                        Label("Create New Tag", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Empty Tag View

    private var emptyTagView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Tags")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Tags are useful for marking release points like v1.0, v2.0, etc.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                showCreateTagSheet = true
            } label: {
                Label("Create Tag", systemImage: "tag")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Sorted Tags

    private var sortedTags: [Tag] {
        viewModel.tags.sorted { tag1, tag2 in
            // Sort by date if available, otherwise by name
            if let date1 = tag1.date, let date2 = tag2.date {
                return date1 > date2
            }
            return tag1.name.localizedCompare(tag2.name) == .orderedDescending
        }
    }

    // MARK: - No Repository View

    private var noRepositoryView: some View {
        EmptyStateView(
            icon: "tag",
            title: "No Repository Open",
            message: "Open a repository to manage tags"
        )
    }
}

// MARK: - Tag Row

private struct TagRow: View {
    let tag: Tag
    let isSelected: Bool
    let onPush: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Tag icon
            Image(systemName: tag.isAnnotated ? "tag.fill" : "tag")
                .foregroundColor(.orange)
                .frame(width: 24)

            // Tag info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tag.name)
                        .fontWeight(.medium)

                    if tag.isAnnotated {
                        Text("annotated")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text(tag.commitHash)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let date = tag.date {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Action buttons (visible on hover or selection)
            if isHovered || isSelected {
                HStack(spacing: 4) {
                    Button {
                        onPush()
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Push to remote")

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete tag")
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

// MARK: - Create Tag Sheet

private struct CreateTagSheet: View {
    @Environment(\.dismiss) private var dismiss

    let commits: [Commit]
    let onCreate: (String, String?, String?) async -> Void

    @State private var tagName: String = ""
    @State private var tagMessage: String = ""
    @State private var isAnnotated: Bool = true
    @State private var selectedCommit: String = "HEAD"
    @State private var isCreating: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Tag")
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
                Section {
                    TextField("Tag name (e.g., v1.0.0)", text: $tagName)
                        .textFieldStyle(.roundedBorder)
                }

                Section {
                    Toggle("Annotated tag", isOn: $isAnnotated)
                        .help("Annotated tags include a message and tagger information")

                    if isAnnotated {
                        TextEditor(text: $tagMessage)
                            .font(.body)
                            .frame(height: 80)
                            .border(Color.secondary.opacity(0.3), width: 1)
                    }
                } header: {
                    Text("Tag Type")
                }

                Section {
                    Picker("Commit", selection: $selectedCommit) {
                        Text("HEAD (current commit)").tag("HEAD")
                        ForEach(commits.prefix(20)) { commit in
                            HStack {
                                Text(commit.shortHash)
                                    .font(.system(.body, design: .monospaced))
                                Text("-")
                                Text(commit.message.components(separatedBy: .newlines).first ?? "")
                                    .lineLimit(1)
                            }
                            .tag(commit.hash)
                        }
                    }
                } header: {
                    Text("Target Commit")
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                if showError {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    createTag()
                } label: {
                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Create Tag")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(tagName.isEmpty || isCreating)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 450)
    }

    private func createTag() {
        guard !tagName.isEmpty else {
            errorMessage = "Tag name is required"
            showError = true
            return
        }

        // Validate tag name (no spaces, special characters)
        let invalidChars = CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: ".-_/"))
        if tagName.unicodeScalars.contains(where: { invalidChars.contains($0) }) {
            errorMessage = "Invalid tag name"
            showError = true
            return
        }

        isCreating = true
        showError = false

        Task {
            let message = isAnnotated && !tagMessage.isEmpty ? tagMessage : nil
            let commit = selectedCommit == "HEAD" ? nil : selectedCommit
            await onCreate(tagName, message, commit)
            isCreating = false
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("With Tags") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    viewModel.tags = [
        Tag(name: "v1.0.0", commitHash: "abc1234", message: "Initial release", taggerName: "John Doe", taggerEmail: "john@example.com", date: Date(), isAnnotated: true),
        Tag(name: "v1.1.0", commitHash: "def5678", message: "Feature update", taggerName: "Jane Smith", taggerEmail: "jane@example.com", date: Date().addingTimeInterval(-86400), isAnnotated: true),
        Tag(name: "v0.9.0-beta", commitHash: "ghi9012", isAnnotated: false),
    ]
    return TagsTab(viewModel: viewModel)
        .frame(width: 900, height: 600)
}

#Preview("Empty Tags") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    return TagsTab(viewModel: viewModel)
        .frame(width: 900, height: 600)
}

#Preview("No Repository") {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    return TagsTab(viewModel: viewModel)
        .frame(width: 900, height: 600)
}
