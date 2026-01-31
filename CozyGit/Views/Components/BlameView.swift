//
//  BlameView.swift
//  CozyGit
//

import SwiftUI

struct BlameView: View {
    let blameInfo: BlameInfo
    let onCommitClick: ((String) -> Void)?

    @State private var selectedLine: BlameLine?
    @State private var hoveredLine: Int?
    @State private var showCommitInfo: Bool = true
    @State private var colorByAge: Bool = true

    init(blameInfo: BlameInfo, onCommitClick: ((String) -> Void)? = nil) {
        self.blameInfo = blameInfo
        self.onCommitClick = onCommitClick
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(blameInfo.filePath)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Toggle("Show Commits", isOn: $showCommitInfo)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Toggle("Color by Age", isOn: $colorByAge)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Blame Content
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(blameInfo.lines) { line in
                        BlameLineRow(
                            line: line,
                            isSelected: selectedLine?.id == line.id,
                            isHovered: hoveredLine == line.lineNumber,
                            showCommitInfo: showCommitInfo,
                            ageColor: colorByAge ? ageColor(for: line.date) : nil,
                            onSelect: {
                                selectedLine = line
                            },
                            onCommitClick: onCommitClick
                        )
                        .onHover { isHovered in
                            hoveredLine = isHovered ? line.lineNumber : nil
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func ageColor(for date: Date) -> Color {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0

        if days < 7 {
            return .green
        } else if days < 30 {
            return .yellow
        } else if days < 90 {
            return .orange
        } else if days < 365 {
            return .red
        } else {
            return .purple
        }
    }
}

// MARK: - Blame Line Row

private struct BlameLineRow: View {
    let line: BlameLine
    let isSelected: Bool
    let isHovered: Bool
    let showCommitInfo: Bool
    let ageColor: Color?
    let onSelect: () -> Void
    let onCommitClick: ((String) -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // Age indicator
            if let color = ageColor {
                Rectangle()
                    .fill(color)
                    .frame(width: 3)
            }

            // Commit info column
            if showCommitInfo {
                HStack(spacing: 8) {
                    // Author initials
                    Text(line.authorInitials)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 18)
                        .background(authorColor(for: line.author))
                        .cornerRadius(4)

                    // Commit hash (clickable)
                    Button {
                        onCommitClick?(line.commitHash)
                    } label: {
                        Text(line.shortHash)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(onCommitClick == nil)

                    // Date
                    Text(line.relativeDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
                .frame(width: 160)
                .padding(.horizontal, 8)
            }

            // Line number
            Text("\(line.lineNumber)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            // Separator
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1)

            // Code content
            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(.leading, 8)

            Spacer(minLength: 16)
        }
        .padding(.vertical, 2)
        .background(backgroundColor)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color.secondary.opacity(0.1)
        }
        return .clear
    }

    private func authorColor(for author: String) -> Color {
        // Generate consistent color based on author name
        let hash = author.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .indigo, .mint]
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Blame Sheet

struct BlameSheet: View {
    @Environment(\.dismiss) private var dismiss

    let filePath: String
    @Bindable var viewModel: RepositoryViewModel

    @State private var blameInfo: BlameInfo?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.accentColor)
                Text("Git Blame")
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

            if isLoading {
                ProgressView("Loading blame information...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if let info = blameInfo {
                BlameView(blameInfo: info) { commitHash in
                    // TODO: Navigate to commit in history
                    print("Navigate to commit: \(commitHash)")
                }
            } else {
                ContentUnavailableView {
                    Label("No Blame Info", systemImage: "doc.text")
                } description: {
                    Text("Could not load blame information for this file")
                }
            }
        }
        .frame(minWidth: 800, idealWidth: 1000, maxWidth: .infinity,
               minHeight: 500, idealHeight: 700, maxHeight: .infinity)
        .task {
            await loadBlame()
        }
    }

    private func loadBlame() async {
        isLoading = true
        errorMessage = nil

        do {
            blameInfo = try await viewModel.blame(file: filePath)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    BlameView(
        blameInfo: BlameInfo(
            filePath: "Sources/MyFile.swift",
            lines: [
                BlameLine(lineNumber: 1, commitHash: "abc1234567890", author: "John Doe", date: Date().addingTimeInterval(-86400 * 2), content: "import Foundation"),
                BlameLine(lineNumber: 2, commitHash: "abc1234567890", author: "John Doe", date: Date().addingTimeInterval(-86400 * 2), content: ""),
                BlameLine(lineNumber: 3, commitHash: "def9876543210", author: "Jane Smith", date: Date().addingTimeInterval(-86400 * 30), content: "struct MyStruct {"),
                BlameLine(lineNumber: 4, commitHash: "def9876543210", author: "Jane Smith", date: Date().addingTimeInterval(-86400 * 30), content: "    let value: Int"),
                BlameLine(lineNumber: 5, commitHash: "ghi5555555555", author: "Bob Wilson", date: Date().addingTimeInterval(-86400 * 100), content: "}")
            ]
        )
    )
    .frame(width: 800, height: 400)
}
