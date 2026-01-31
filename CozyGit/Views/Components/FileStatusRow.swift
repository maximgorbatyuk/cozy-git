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

    private var fileName: String {
        file.path.components(separatedBy: "/").last ?? file.path
    }

    private var directoryPath: String? {
        file.path.contains("/")
            ? file.path.components(separatedBy: "/").dropLast().joined(separator: "/")
            : nil
    }

    private var accessibilityDescription: String {
        let status = L10n.Status.forType(file.status)
        let stageState = isStaged ? L10n.Changes.staged : L10n.Changes.unstaged
        return "\(fileName), \(status), \(stageState)"
    }

    var body: some View {
        HStack(spacing: 8) {
            FileStatusBadge(status: file.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .lineLimit(1)

                if let directory = directoryPath {
                    Text(directory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    onStageToggle()
                    // Announce for VoiceOver
                    if isStaged {
                        AccessibilityAnnouncer.shared.announceFileUnstaged(fileName)
                    } else {
                        AccessibilityAnnouncer.shared.announceFileStaged(fileName)
                    }
                } label: {
                    Image(systemName: isStaged ? "minus.circle" : "plus.circle")
                }
                .buttonStyle(.borderless)
                .help(isStaged ? L10n.Changes.unstage : L10n.Changes.stage)
                .accessibilityLabel(isStaged ? AccessibilityLabel.unstageFile : AccessibilityLabel.stageFile)
                .accessibilityHint(isStaged ? AccessibilityHint.unstageButton : AccessibilityHint.stageButton)

                if !isStaged, let onDiscard = onDiscard, file.status != .untracked {
                    Button {
                        onDiscard()
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.orange)
                    .help(L10n.Changes.discard)
                    .accessibilityLabel(AccessibilityLabel.discardChanges)
                    .accessibilityHint(AccessibilityHint.discardButton)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        // Accessibility for the entire row
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(AccessibilityHint.fileRow)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("fileRow_\(file.path)")
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
