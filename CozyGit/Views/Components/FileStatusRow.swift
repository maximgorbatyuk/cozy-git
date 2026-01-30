//
//  FileStatusRow.swift
//  CozyGit
//

import SwiftUI

struct FileStatusRow: View {
    let file: FileStatus
    let isStaged: Bool
    let onStageToggle: () -> Void
    let onDiscard: (() -> Void)?

    init(
        file: FileStatus,
        isStaged: Bool,
        onStageToggle: @escaping () -> Void,
        onDiscard: (() -> Void)? = nil
    ) {
        self.file = file
        self.isStaged = isStaged
        self.onStageToggle = onStageToggle
        self.onDiscard = onDiscard
    }

    var body: some View {
        HStack(spacing: 8) {
            FileStatusBadge(status: file.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.path.components(separatedBy: "/").last ?? file.path)
                    .lineLimit(1)

                if file.path.contains("/") {
                    Text(file.path.components(separatedBy: "/").dropLast().joined(separator: "/"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    onStageToggle()
                } label: {
                    Image(systemName: isStaged ? "minus.circle" : "plus.circle")
                }
                .buttonStyle(.borderless)
                .help(isStaged ? "Unstage" : "Stage")

                if !isStaged, let onDiscard = onDiscard, file.status != .untracked {
                    Button {
                        onDiscard()
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.orange)
                    .help("Discard Changes")
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 0) {
        FileStatusRow(
            file: FileStatus(path: "src/components/Button.swift", status: .modified),
            isStaged: false,
            onStageToggle: {},
            onDiscard: {}
        )
        Divider()
        FileStatusRow(
            file: FileStatus(path: "README.md", status: .added),
            isStaged: true,
            onStageToggle: {}
        )
        Divider()
        FileStatusRow(
            file: FileStatus(path: "old-file.txt", status: .deleted),
            isStaged: false,
            onStageToggle: {},
            onDiscard: {}
        )
    }
    .frame(width: 300)
}
