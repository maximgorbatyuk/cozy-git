//
//  CloneRepositorySheet.swift
//  CozyGit
//

import SwiftUI

struct CloneRepositorySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var repositoryURL: String = ""
    @State private var destinationPath: URL?
    @State private var isCloning = false
    @State private var errorMessage: String?

    let onClone: (URL, URL) async -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Clone Repository")
                .font(.title2)
                .fontWeight(.semibold)

            // URL Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Repository URL")
                    .font(.headline)
                TextField("https://github.com/user/repo.git", text: $repositoryURL)
                    .textFieldStyle(.roundedBorder)
            }

            // Destination Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Clone to")
                    .font(.headline)
                HStack {
                    if let path = destinationPath {
                        Text(path.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Choose destination folder...")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button("Choose...") {
                        showFolderPicker()
                    }
                }
                .padding(8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Error Message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task {
                        await cloneRepository()
                    }
                } label: {
                    if isCloning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Clone")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canClone || isCloning)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 450, height: 280)
    }

    private var canClone: Bool {
        !repositoryURL.isEmpty && destinationPath != nil
    }

    private func showFolderPicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose Destination Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK {
            destinationPath = panel.url
        }
    }

    private func cloneRepository() async {
        guard let url = URL(string: repositoryURL),
              let destination = destinationPath else {
            errorMessage = "Invalid URL or destination"
            return
        }

        // Extract repo name from URL for the folder
        let repoName = url.deletingPathExtension().lastPathComponent
        let finalDestination = destination.appendingPathComponent(repoName)

        isCloning = true
        errorMessage = nil

        await onClone(url, finalDestination)

        isCloning = false
        dismiss()
    }
}

#Preview {
    CloneRepositorySheet { _, _ in }
}
