//
//  CommitDialog.swift
//  CozyGit
//

import SwiftUI

struct CommitDialog: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: RepositoryViewModel

    @State private var commitMessage: String = ""
    @State private var isCommitting = false
    @State private var errorMessage: String?
    @State private var config: AutomationConfig = AutomationConfig()
    @State private var selectedPrefixId: UUID?

    // Commit message guidelines
    private let subjectMaxLength = 72
    private let bodyStartLine = 2

    private let automationService = AutomationService(shellExecutor: DependencyContainer.shared.shellExecutor)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Commit")
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
                // Staged Files Summary
                stagedFilesSummary

                Divider()

                // Prefix Selector (if enabled)
                if config.showPrefixInCommitDialog && !config.enabledPrefixes.isEmpty {
                    prefixSelector
                }

                // Commit Message Editor
                commitMessageEditor

                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()
            .onAppear {
                if let repo = viewModel.repository {
                    config = automationService.loadConfig(for: repo)
                    selectedPrefixId = config.selectedPrefixId
                }
            }

            Divider()

            // Footer with buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task {
                        await performCommit()
                    }
                } label: {
                    if isCommitting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Commit")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCommit || isCommitting)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 520)
    }

    // MARK: - Staged Files Summary

    private var stagedFilesSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Staged Changes")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.stagedFiles.count) file(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if viewModel.stagedFiles.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No files staged for commit")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.stagedFiles.prefix(10)) { file in
                            HStack(spacing: 6) {
                                FileStatusBadge(status: file.status)
                                    .scaleEffect(0.8)
                                Text(file.path)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        if viewModel.stagedFiles.count > 10 {
                            Text("... and \(viewModel.stagedFiles.count - 10) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
        }
    }

    // MARK: - Prefix Selector

    private var prefixSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Commit Prefix")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // None option
                    Button {
                        selectedPrefixId = nil
                    } label: {
                        Text("None")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedPrefixId == nil ? Color.accentColor : Color.secondary.opacity(0.2))
                            .foregroundStyle(selectedPrefixId == nil ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    ForEach(config.enabledPrefixes) { prefix in
                        Button {
                            selectedPrefixId = prefix.id
                        } label: {
                            Text(prefix.prefix)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedPrefixId == prefix.id ? prefixColor(for: prefix) : prefixColor(for: prefix).opacity(0.2))
                                .foregroundStyle(selectedPrefixId == prefix.id ? .white : prefixColor(for: prefix))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help(prefix.name)
                    }
                }
            }

            if let selectedId = selectedPrefixId,
               let prefix = config.prefixes.first(where: { $0.id == selectedId }) {
                Text("Preview: \(prefix.prefix) \(commitMessage.isEmpty ? "your message" : commitMessage.components(separatedBy: .newlines).first ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func prefixColor(for prefix: CommitPrefix) -> Color {
        switch prefix.color {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .cyan: return .cyan
        case .indigo: return .indigo
        case .brown: return .brown
        case .gray: return .gray
        }
    }

    // MARK: - Commit Message Editor

    private var commitMessageEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Commit Message")
                    .font(.headline)
                Spacer()
                characterCount
            }

            TextEditor(text: $commitMessage)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Text("First line: Summary (max \(subjectMaxLength) chars). Leave blank line, then detailed description.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var characterCount: some View {
        let lines = commitMessage.components(separatedBy: .newlines)
        let firstLineLength = lines.first?.count ?? 0
        let isOverLimit = firstLineLength > subjectMaxLength

        return HStack(spacing: 4) {
            Text("\(firstLineLength)/\(subjectMaxLength)")
                .foregroundColor(isOverLimit ? .orange : .secondary)
            if isOverLimit {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
    }

    // MARK: - Actions

    private var canCommit: Bool {
        !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.stagedFiles.isEmpty
    }

    private func performCommit() async {
        isCommitting = true
        errorMessage = nil

        // Apply prefix if selected
        var finalMessage = commitMessage
        if let selectedId = selectedPrefixId,
           let prefix = config.prefixes.first(where: { $0.id == selectedId }) {
            finalMessage = prefix.apply(to: commitMessage)
        }

        await viewModel.commit(message: finalMessage)

        if viewModel.errorMessage != nil {
            errorMessage = viewModel.errorMessage
            viewModel.clearError()
            isCommitting = false
        } else {
            isCommitting = false
            dismiss()
        }
    }
}

#Preview {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    viewModel.fileStatuses = [
        FileStatus(path: "src/main.swift", status: .modified, isStaged: true),
        FileStatus(path: "README.md", status: .added, isStaged: true),
    ]
    return CommitDialog(viewModel: viewModel)
}
