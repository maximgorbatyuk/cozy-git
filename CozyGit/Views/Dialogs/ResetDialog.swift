//
//  ResetDialog.swift
//  CozyGit
//

import SwiftUI

struct ResetDialog: View {
    @Environment(\.dismiss) private var dismiss

    let commit: Commit
    let onReset: (ResetMode) async -> Void

    @State private var selectedMode: ResetMode = .mixed
    @State private var isResetting: Bool = false
    @State private var confirmHardReset: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Reset to Commit")
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

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Target Commit Info
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Target Commit", systemImage: "target")
                                .font(.headline)

                            HStack {
                                Text(commit.shortHash)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.accentColor)

                                Text(commit.message.components(separatedBy: .newlines).first ?? commit.message)
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text(commit.author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(commit.date.formatted(.relative(presentation: .named)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Reset Mode Selection
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Reset Mode", systemImage: "slider.horizontal.3")
                                .font(.headline)

                            ForEach(ResetMode.allCases) { mode in
                                ResetModeOption(
                                    mode: mode,
                                    isSelected: selectedMode == mode,
                                    onSelect: {
                                        selectedMode = mode
                                    }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Warning for Hard Reset
                    if selectedMode == .hard {
                        GroupBox {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Warning: Destructive Operation")
                                        .font(.headline)
                                        .foregroundColor(.red)

                                    Text("Hard reset will permanently discard all uncommitted changes. This cannot be undone.")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .backgroundStyle(.red.opacity(0.1))

                        Toggle("I understand this will discard all uncommitted changes", isOn: $confirmHardReset)
                            .font(.callout)
                    }
                }
                .padding()
            }

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
                        isResetting = true
                        await onReset(selectedMode)
                        isResetting = false
                        dismiss()
                    }
                } label: {
                    if isResetting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Reset")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isResetting || (selectedMode == .hard && !confirmHardReset))
                .buttonStyle(.borderedProminent)
                .tint(selectedMode.isDestructive ? .red : .accentColor)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 520)
    }
}

// MARK: - Reset Mode Option

private struct ResetModeOption: View {
    let mode: ResetMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title3)

                Image(systemName: mode.iconName)
                    .foregroundColor(mode.isDestructive ? .red : .primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(mode.displayName)
                            .fontWeight(.medium)

                        if mode.isDestructive {
                            Text("DESTRUCTIVE")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                    }

                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(10)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ResetDialog(
        commit: Commit(
            hash: "abc123def456",
            message: "Fix: Resolve crash on startup",
            author: "John Doe",
            authorEmail: "john@example.com",
            date: Date()
        )
    ) { mode in
        print("Reset with mode: \(mode)")
    }
}
