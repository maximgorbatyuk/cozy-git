//
//  InitRepositorySheet.swift
//  CozyGit
//

import SwiftUI

struct InitRepositorySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPath: URL?
    @State private var isBare: Bool = false
    @State private var isInitializing = false
    @State private var errorMessage: String?

    let onInit: (URL, Bool) async -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Initialize Repository")
                .font(.title2)
                .fontWeight(.semibold)

            // Folder Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.headline)
                HStack {
                    if let path = selectedPath {
                        Text(path.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Choose folder...")
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

            // Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.headline)

                Toggle("Create bare repository", isOn: $isBare)
                    .toggleStyle(.checkbox)

                Text("A bare repository has no working directory and is used for sharing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        await initRepository()
                    }
                } label: {
                    if isInitializing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Create")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPath == nil || isInitializing)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 450, height: 300)
    }

    private func showFolderPicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose Repository Location"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK {
            selectedPath = panel.url
        }
    }

    private func initRepository() async {
        guard let path = selectedPath else {
            errorMessage = "Please select a folder"
            return
        }

        isInitializing = true
        errorMessage = nil

        await onInit(path, isBare)

        isInitializing = false
        dismiss()
    }
}

#Preview {
    InitRepositorySheet { _, _ in }
}
