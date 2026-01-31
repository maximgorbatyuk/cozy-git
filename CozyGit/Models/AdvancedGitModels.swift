//
//  AdvancedGitModels.swift
//  CozyGit
//
//  Models for advanced Git operations: reset, cherry-pick, revert, blame
//

import Foundation

// MARK: - Reset Mode

enum ResetMode: String, CaseIterable, Identifiable {
    case soft = "soft"
    case mixed = "mixed"
    case hard = "hard"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .soft: return "Soft"
        case .mixed: return "Mixed"
        case .hard: return "Hard"
        }
    }

    var description: String {
        switch self {
        case .soft:
            return "Keep all changes staged. Only moves HEAD."
        case .mixed:
            return "Keep changes but unstaged. Moves HEAD and resets index."
        case .hard:
            return "Discard all changes. Moves HEAD, resets index and working directory."
        }
    }

    var isDestructive: Bool {
        self == .hard
    }

    var iconName: String {
        switch self {
        case .soft: return "arrow.uturn.backward"
        case .mixed: return "arrow.uturn.backward.circle"
        case .hard: return "arrow.uturn.backward.circle.fill"
        }
    }
}

// MARK: - Reset Result

struct ResetResult: Equatable {
    let success: Bool
    let targetCommit: String
    let mode: ResetMode
    let errorMessage: String?

    init(success: Bool, targetCommit: String, mode: ResetMode, errorMessage: String? = nil) {
        self.success = success
        self.targetCommit = targetCommit
        self.mode = mode
        self.errorMessage = errorMessage
    }
}

// MARK: - Cherry-Pick Result

struct CherryPickResult: Equatable {
    let success: Bool
    let hasConflicts: Bool
    let commitHash: String?
    let errorMessage: String?

    init(success: Bool, hasConflicts: Bool = false, commitHash: String? = nil, errorMessage: String? = nil) {
        self.success = success
        self.hasConflicts = hasConflicts
        self.commitHash = commitHash
        self.errorMessage = errorMessage
    }

    static func success(commitHash: String) -> CherryPickResult {
        CherryPickResult(success: true, commitHash: commitHash)
    }

    static func conflict() -> CherryPickResult {
        CherryPickResult(success: false, hasConflicts: true)
    }

    static func failure(_ message: String) -> CherryPickResult {
        CherryPickResult(success: false, errorMessage: message)
    }
}

// MARK: - Revert Result

struct RevertResult: Equatable {
    let success: Bool
    let hasConflicts: Bool
    let revertCommitHash: String?
    let errorMessage: String?

    init(success: Bool, hasConflicts: Bool = false, revertCommitHash: String? = nil, errorMessage: String? = nil) {
        self.success = success
        self.hasConflicts = hasConflicts
        self.revertCommitHash = revertCommitHash
        self.errorMessage = errorMessage
    }

    static func success(revertCommitHash: String) -> RevertResult {
        RevertResult(success: true, revertCommitHash: revertCommitHash)
    }

    static func conflict() -> RevertResult {
        RevertResult(success: false, hasConflicts: true)
    }

    static func failure(_ message: String) -> RevertResult {
        RevertResult(success: false, errorMessage: message)
    }
}

// MARK: - Blame Line

struct BlameLine: Identifiable, Equatable {
    let id: Int  // Line number (1-based)
    let lineNumber: Int
    let commitHash: String
    let author: String
    let authorEmail: String
    let date: Date
    let content: String
    let isOriginal: Bool  // Whether this line originated in this commit

    init(
        lineNumber: Int,
        commitHash: String,
        author: String,
        authorEmail: String = "",
        date: Date,
        content: String,
        isOriginal: Bool = false
    ) {
        self.id = lineNumber
        self.lineNumber = lineNumber
        self.commitHash = commitHash
        self.author = author
        self.authorEmail = authorEmail
        self.date = date
        self.content = content
        self.isOriginal = isOriginal
    }

    var shortHash: String {
        String(commitHash.prefix(7))
    }

    var authorInitials: String {
        let parts = author.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "??"
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Blame Info

struct BlameInfo: Equatable {
    let filePath: String
    let lines: [BlameLine]
    let commits: [String: Commit]  // Hash -> Commit for quick lookup

    init(filePath: String, lines: [BlameLine], commits: [String: Commit] = [:]) {
        self.filePath = filePath
        self.lines = lines
        self.commits = commits
    }

    var uniqueCommits: [String] {
        Array(Set(lines.map { $0.commitHash })).sorted()
    }

    var uniqueAuthors: [String] {
        Array(Set(lines.map { $0.author })).sorted()
    }

    func linesForCommit(_ hash: String) -> [BlameLine] {
        lines.filter { $0.commitHash == hash }
    }

    func linesForAuthor(_ author: String) -> [BlameLine] {
        lines.filter { $0.author == author }
    }
}

// MARK: - Operation State Extension

extension OperationState {
    static var revertInProgress: OperationState {
        // For now, treat revert similar to cherry-pick
        .cherryPickInProgress
    }
}
