//
//  NewBranchDialog.swift
//  CozyGit
//

import SwiftUI

struct NewBranchDialog: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: RepositoryViewModel

    @State private var branchName: String = ""
    @State private var selectedBaseBranch: String = ""
    @State private var checkoutAfterCreate: Bool = true
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Branch")
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
                    TextField("Branch name", text: $branchName)
                        .textFieldStyle(.roundedBorder)

                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Branch Name")
                }

                Section {
                    Picker("Base branch", selection: $selectedBaseBranch) {
                        ForEach(availableBranches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Create From")
                } footer: {
                    Text("The new branch will be created from this branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Toggle("Switch to new branch after creation", isOn: $checkoutAfterCreate)
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
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
                    Task {
                        await createBranch()
                    }
                } label: {
                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Create Branch")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValidBranchName || isCreating)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 450, height: 380)
        .onAppear {
            if let currentBranch = viewModel.repository?.currentBranch {
                selectedBaseBranch = currentBranch
            } else if let firstBranch = availableBranches.first {
                selectedBaseBranch = firstBranch
            }
        }
    }

    // MARK: - Computed Properties

    private var availableBranches: [String] {
        viewModel.branches.map { $0.name }
    }

    private var isValidBranchName: Bool {
        !branchName.isEmpty && validationError == nil
    }

    private var validationError: String? {
        let trimmed = branchName.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return nil // Don't show error for empty field
        }

        // Check for invalid characters
        let invalidChars = CharacterSet(charactersIn: " ~^:?*[\\")
        if trimmed.unicodeScalars.contains(where: { invalidChars.contains($0) }) {
            return "Branch name contains invalid characters"
        }

        // Check if starts or ends with dot or slash
        if trimmed.hasPrefix(".") || trimmed.hasSuffix(".") ||
           trimmed.hasPrefix("/") || trimmed.hasSuffix("/") {
            return "Branch name cannot start or end with '.' or '/'"
        }

        // Check for consecutive dots
        if trimmed.contains("..") {
            return "Branch name cannot contain '..'"
        }

        // Check for @{
        if trimmed.contains("@{") {
            return "Branch name cannot contain '@{'"
        }

        // Check if branch already exists
        if viewModel.branches.contains(where: { $0.name == trimmed }) {
            return "A branch with this name already exists"
        }

        return nil
    }

    // MARK: - Actions

    private func createBranch() async {
        isCreating = true
        errorMessage = nil

        do {
            let baseBranch = selectedBaseBranch.isEmpty ? nil : selectedBaseBranch
            _ = try await viewModel.createBranch(
                name: branchName.trimmingCharacters(in: .whitespaces),
                from: baseBranch
            )

            if checkoutAfterCreate {
                try await viewModel.checkoutBranch(name: branchName.trimmingCharacters(in: .whitespaces))
            }

            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = RepositoryViewModel(gitService: DependencyContainer.shared.gitService)
    viewModel.repository = Repository(
        path: URL(fileURLWithPath: "/Users/test/MyProject"),
        currentBranch: "main"
    )
    viewModel.branches = [
        Branch(name: "main", isHead: true, isRemote: false),
        Branch(name: "develop", isHead: false, isRemote: false),
        Branch(name: "feature/login", isHead: false, isRemote: false),
    ]
    return NewBranchDialog(viewModel: viewModel)
}
