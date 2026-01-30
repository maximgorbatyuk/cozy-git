//
//  Diff.swift
//  CozyGit
//

import Foundation

/// Represents a complete diff output containing one or more file diffs
struct Diff: Identifiable, Equatable {
    let id = UUID()

    /// Individual file diffs
    let files: [FileDiff]

    /// Total number of additions across all files
    var totalAdditions: Int {
        files.reduce(0) { $0 + $1.additions }
    }

    /// Total number of deletions across all files
    var totalDeletions: Int {
        files.reduce(0) { $0 + $1.deletions }
    }

    /// Whether the diff is empty
    var isEmpty: Bool {
        files.isEmpty || files.allSatisfy { $0.hunks.isEmpty }
    }

    /// Raw diff output
    let rawOutput: String

    init(files: [FileDiff] = [], rawOutput: String = "") {
        self.files = files
        self.rawOutput = rawOutput
    }
}

/// Represents a diff for a single file
struct FileDiff: Identifiable, Equatable {
    let id = UUID()

    /// Old file path (before changes)
    let oldPath: String

    /// New file path (after changes, may differ for renames)
    let newPath: String

    /// The hunks (change regions) in this file
    let hunks: [DiffHunk]

    /// Whether this is a binary file
    let isBinary: Bool

    /// Whether this is a new file
    let isNewFile: Bool

    /// Whether this is a deleted file
    let isDeletedFile: Bool

    /// Whether this is a renamed file
    var isRenamed: Bool {
        oldPath != newPath && !isNewFile && !isDeletedFile
    }

    /// File mode (e.g., "100644")
    let fileMode: String?

    /// Number of additions in this file
    var additions: Int {
        hunks.reduce(0) { sum, hunk in
            sum + hunk.lines.filter { $0.type == .addition }.count
        }
    }

    /// Number of deletions in this file
    var deletions: Int {
        hunks.reduce(0) { sum, hunk in
            sum + hunk.lines.filter { $0.type == .deletion }.count
        }
    }

    /// Display name for the file
    var displayName: String {
        if isRenamed {
            return "\(oldPath) → \(newPath)"
        }
        return newPath.isEmpty ? oldPath : newPath
    }

    /// File extension for syntax highlighting
    var fileExtension: String {
        let path = newPath.isEmpty ? oldPath : newPath
        return (path as NSString).pathExtension.lowercased()
    }

    init(
        oldPath: String,
        newPath: String,
        hunks: [DiffHunk] = [],
        isBinary: Bool = false,
        isNewFile: Bool = false,
        isDeletedFile: Bool = false,
        fileMode: String? = nil
    ) {
        self.oldPath = oldPath
        self.newPath = newPath
        self.hunks = hunks
        self.isBinary = isBinary
        self.isNewFile = isNewFile
        self.isDeletedFile = isDeletedFile
        self.fileMode = fileMode
    }
}

/// Represents a hunk (change region) in a diff
struct DiffHunk: Identifiable, Equatable {
    let id = UUID()

    /// Starting line number in the old file
    let oldStart: Int

    /// Number of lines in the old file
    let oldCount: Int

    /// Starting line number in the new file
    let newStart: Int

    /// Number of lines in the new file
    let newCount: Int

    /// Optional section header (e.g., function name)
    let header: String?

    /// Lines in this hunk
    let lines: [DiffLine]

    /// The raw hunk header (e.g., "@@ -1,5 +1,7 @@")
    var hunkHeader: String {
        "@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@\(header.map { " \($0)" } ?? "")"
    }

    init(
        oldStart: Int,
        oldCount: Int,
        newStart: Int,
        newCount: Int,
        header: String? = nil,
        lines: [DiffLine] = []
    ) {
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.header = header
        self.lines = lines
    }
}

/// Represents a single line in a diff
struct DiffLine: Identifiable, Equatable {
    let id = UUID()

    /// The type of line (context, addition, deletion)
    let type: DiffLineType

    /// The content of the line (without the leading +/- character)
    let content: String

    /// Line number in the old file (nil for additions)
    let oldLineNumber: Int?

    /// Line number in the new file (nil for deletions)
    let newLineNumber: Int?

    /// Whether this line has a trailing newline
    let hasNewline: Bool

    init(
        type: DiffLineType,
        content: String,
        oldLineNumber: Int? = nil,
        newLineNumber: Int? = nil,
        hasNewline: Bool = true
    ) {
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.hasNewline = hasNewline
    }

    /// The raw line with prefix character
    var rawLine: String {
        switch type {
        case .context:
            return " \(content)"
        case .addition:
            return "+\(content)"
        case .deletion:
            return "-\(content)"
        case .hunkHeader:
            return content
        case .noNewline:
            return "\\ No newline at end of file"
        }
    }
}

/// Type of a diff line
enum DiffLineType: Equatable {
    case context
    case addition
    case deletion
    case hunkHeader
    case noNewline

    /// Color for this line type
    var backgroundColor: String {
        switch self {
        case .addition:
            return "green"
        case .deletion:
            return "red"
        case .context, .hunkHeader, .noNewline:
            return "clear"
        }
    }
}

/// Options for generating diffs
struct DiffOptions {
    /// Number of context lines around changes
    var contextLines: Int = 3

    /// Whether to detect renames
    var detectRenames: Bool = true

    /// Whether to ignore whitespace changes
    var ignoreWhitespace: Bool = false

    /// Whether to ignore all whitespace
    var ignoreAllWhitespace: Bool = false

    /// Whether this is a staged diff
    var staged: Bool = false

    /// Specific commit to diff against (nil for working directory)
    var commit: String?

    /// Specific file path to diff (nil for all files)
    var filePath: String?
}
