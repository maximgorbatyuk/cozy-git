//
//  UnifiedDiffView.swift
//  CozyGit
//

import SwiftUI

/// A unified diff view component that displays file changes
struct UnifiedDiffView: View {
    let fileDiff: FileDiff

    @State private var showLineNumbers: Bool = true
    @State private var currentChangeIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // File header
            fileHeader

            Divider()

            // Diff content
            if fileDiff.isBinary {
                binaryFileView
            } else if fileDiff.hunks.isEmpty {
                emptyDiffView
            } else {
                diffContent
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - File Header

    private var fileHeader: some View {
        HStack {
            // File icon and path
            HStack(spacing: 8) {
                fileStatusIcon

                Text(fileDiff.displayName)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Stats
            HStack(spacing: 12) {
                if fileDiff.additions > 0 {
                    Text("+\(fileDiff.additions)")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                if fileDiff.deletions > 0 {
                    Text("-\(fileDiff.deletions)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
            }

            // Toggle line numbers
            Button {
                showLineNumbers.toggle()
            } label: {
                Image(systemName: showLineNumbers ? "number.square.fill" : "number.square")
            }
            .buttonStyle(.borderless)
            .help(showLineNumbers ? "Hide line numbers" : "Show line numbers")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var fileStatusIcon: some View {
        Group {
            if fileDiff.isNewFile {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
            } else if fileDiff.isDeletedFile {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            } else if fileDiff.isRenamed {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Diff Content

    private var diffContent: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(fileDiff.hunks) { hunk in
                    // Hunk header
                    hunkHeaderView(hunk)

                    // Hunk lines
                    ForEach(hunk.lines) { line in
                        diffLineView(line)
                    }
                }
            }
        }
    }

    private func hunkHeaderView(_ hunk: DiffHunk) -> some View {
        HStack(spacing: 0) {
            // Line number columns
            if showLineNumbers {
                Text("...")
                    .frame(width: 50, alignment: .trailing)
                    .padding(.horizontal, 4)
                    .foregroundColor(.secondary)

                Text("...")
                    .frame(width: 50, alignment: .trailing)
                    .padding(.horizontal, 4)
                    .foregroundColor(.secondary)
            }

            // Hunk header content
            Text(hunk.hunkHeader)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
    }

    private func diffLineView(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            // Line numbers
            if showLineNumbers {
                // Old line number
                Text(line.oldLineNumber.map { "\($0)" } ?? "")
                    .frame(width: 50, alignment: .trailing)
                    .padding(.horizontal, 4)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .background(lineNumberBackground(for: line))

                // New line number
                Text(line.newLineNumber.map { "\($0)" } ?? "")
                    .frame(width: 50, alignment: .trailing)
                    .padding(.horizontal, 4)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .background(lineNumberBackground(for: line))
            }

            // Line prefix
            Text(linePrefix(for: line))
                .frame(width: 20, alignment: .center)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(linePrefixColor(for: line))
                .background(lineBackground(for: line))

            // Line content
            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(lineBackground(for: line))

            // No newline indicator
            if !line.hasNewline {
                Image(systemName: "arrow.turn.down.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help("No newline at end of file")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linePrefix(for line: DiffLine) -> String {
        switch line.type {
        case .addition:
            return "+"
        case .deletion:
            return "-"
        case .context:
            return " "
        case .hunkHeader:
            return "@@"
        case .noNewline:
            return "\\"
        }
    }

    private func linePrefixColor(for line: DiffLine) -> Color {
        switch line.type {
        case .addition:
            return .green
        case .deletion:
            return .red
        default:
            return .secondary
        }
    }

    private func lineBackground(for line: DiffLine) -> Color {
        switch line.type {
        case .addition:
            return Color.green.opacity(0.15)
        case .deletion:
            return Color.red.opacity(0.15)
        default:
            return .clear
        }
    }

    private func lineNumberBackground(for line: DiffLine) -> Color {
        switch line.type {
        case .addition:
            return Color.green.opacity(0.1)
        case .deletion:
            return Color.red.opacity(0.1)
        default:
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        }
    }

    // MARK: - Binary File View

    private var binaryFileView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("Binary file")
                .font(.headline)

            Text("Binary files cannot be displayed in diff view")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Empty Diff View

    private var emptyDiffView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.green)

            Text("No changes")
                .font(.headline)

            Text("This file has no differences")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Multi-File Diff View

/// A view that displays diffs for multiple files
struct MultiFileDiffView: View {
    let diff: Diff

    @State private var selectedFileIndex: Int = 0

    var body: some View {
        if diff.isEmpty {
            emptyView
        } else {
            HSplitView {
                // File list
                fileList
                    .frame(minWidth: 200, maxWidth: 300)

                // Selected file diff
                if selectedFileIndex < diff.files.count {
                    UnifiedDiffView(fileDiff: diff.files[selectedFileIndex])
                } else {
                    Text("Select a file to view diff")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var fileList: some View {
        List(selection: $selectedFileIndex) {
            ForEach(Array(diff.files.enumerated()), id: \.offset) { index, file in
                HStack {
                    fileStatusIcon(for: file)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.displayName)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        HStack(spacing: 8) {
                            if file.additions > 0 {
                                Text("+\(file.additions)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            if file.deletions > 0 {
                                Text("-\(file.deletions)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Spacer()
                }
                .tag(index)
                .padding(.vertical, 2)
            }
        }
        .listStyle(.sidebar)
    }

    private func fileStatusIcon(for file: FileDiff) -> some View {
        Group {
            if file.isNewFile {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
            } else if file.isDeletedFile {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            } else if file.isRenamed {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            } else if file.isBinary {
                Image(systemName: "doc.zipper")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("No changes")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Working directory is clean")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Single File Diff") {
    let lines = [
        DiffLine(type: .context, content: "import Foundation", oldLineNumber: 1, newLineNumber: 1),
        DiffLine(type: .context, content: "", oldLineNumber: 2, newLineNumber: 2),
        DiffLine(type: .deletion, content: "func oldFunction() {", oldLineNumber: 3, newLineNumber: nil),
        DiffLine(type: .addition, content: "func newFunction() {", oldLineNumber: nil, newLineNumber: 3),
        DiffLine(type: .context, content: "    print(\"Hello\")", oldLineNumber: 4, newLineNumber: 4),
        DiffLine(type: .addition, content: "    print(\"World\")", oldLineNumber: nil, newLineNumber: 5),
        DiffLine(type: .context, content: "}", oldLineNumber: 5, newLineNumber: 6),
    ]

    let hunk = DiffHunk(oldStart: 1, oldCount: 5, newStart: 1, newCount: 6, header: "func example()", lines: lines)
    let fileDiff = FileDiff(oldPath: "Example.swift", newPath: "Example.swift", hunks: [hunk])

    return UnifiedDiffView(fileDiff: fileDiff)
        .frame(width: 800, height: 400)
}

#Preview("New File") {
    let lines = [
        DiffLine(type: .addition, content: "// New file", oldLineNumber: nil, newLineNumber: 1),
        DiffLine(type: .addition, content: "import Foundation", oldLineNumber: nil, newLineNumber: 2),
        DiffLine(type: .addition, content: "", oldLineNumber: nil, newLineNumber: 3),
        DiffLine(type: .addition, content: "struct NewStruct {}", oldLineNumber: nil, newLineNumber: 4),
    ]

    let hunk = DiffHunk(oldStart: 0, oldCount: 0, newStart: 1, newCount: 4, lines: lines)
    let fileDiff = FileDiff(oldPath: "/dev/null", newPath: "NewFile.swift", hunks: [hunk], isNewFile: true)

    return UnifiedDiffView(fileDiff: fileDiff)
        .frame(width: 800, height: 300)
}
