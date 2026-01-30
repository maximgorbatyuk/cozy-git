//
//  RebaseResult.swift
//  CozyGit
//

import Foundation

/// Result of a rebase operation
struct RebaseResult: Equatable {
    /// Whether the rebase was successful
    let success: Bool

    /// Number of commits rebased
    let commitsRebased: Int

    /// Current commit being rebased (during in-progress rebase)
    let currentCommit: Int

    /// Total commits to rebase
    let totalCommits: Int

    /// Whether there are conflicts
    let hasConflicts: Bool

    /// List of conflicted files
    let conflictingFiles: [String]

    /// Whether a rebase is currently in progress
    let isInProgress: Bool

    /// The branch being rebased onto
    let targetBranch: String?

    /// Error message if rebase failed
    let errorMessage: String?

    /// Raw output from git command
    let rawOutput: String

    init(
        success: Bool = true,
        commitsRebased: Int = 0,
        currentCommit: Int = 0,
        totalCommits: Int = 0,
        hasConflicts: Bool = false,
        conflictingFiles: [String] = [],
        isInProgress: Bool = false,
        targetBranch: String? = nil,
        errorMessage: String? = nil,
        rawOutput: String = ""
    ) {
        self.success = success
        self.commitsRebased = commitsRebased
        self.currentCommit = currentCommit
        self.totalCommits = totalCommits
        self.hasConflicts = hasConflicts
        self.conflictingFiles = conflictingFiles
        self.isInProgress = isInProgress
        self.targetBranch = targetBranch
        self.errorMessage = errorMessage
        self.rawOutput = rawOutput
    }

    /// Summary message for display
    var summary: String {
        if hasConflicts {
            return "Rebase paused - \(conflictingFiles.count) conflict(s) to resolve"
        }

        if isInProgress {
            return "Rebase in progress (\(currentCommit)/\(totalCommits))"
        }

        if !success {
            return errorMessage ?? "Rebase failed"
        }

        if commitsRebased > 0 {
            return "\(commitsRebased) commit(s) rebased successfully"
        }

        return "Already up to date"
    }

    /// Progress percentage (0-100)
    var progress: Double {
        guard totalCommits > 0 else { return 0 }
        return Double(currentCommit) / Double(totalCommits) * 100
    }
}

/// State of an in-progress merge or rebase
enum OperationState: Equatable {
    case none
    case mergeInProgress(conflictCount: Int)
    case rebaseInProgress(current: Int, total: Int)
    case cherryPickInProgress

    var isInProgress: Bool {
        switch self {
        case .none:
            return false
        default:
            return true
        }
    }

    var description: String {
        switch self {
        case .none:
            return "No operation in progress"
        case .mergeInProgress(let count):
            return "Merge in progress (\(count) conflict(s))"
        case .rebaseInProgress(let current, let total):
            return "Rebase in progress (\(current)/\(total))"
        case .cherryPickInProgress:
            return "Cherry-pick in progress"
        }
    }
}

/// Conflict file information
struct ConflictedFile: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let conflictType: ConflictType

    enum ConflictType: String {
        case content = "Content conflict"
        case addAdd = "Both added"
        case modifyDelete = "Modified/Deleted"
        case deleteModify = "Deleted/Modified"
        case renameRename = "Rename conflict"
    }
}
