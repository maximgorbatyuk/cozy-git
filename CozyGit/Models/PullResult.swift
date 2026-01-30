//
//  PullResult.swift
//  CozyGit
//

import Foundation

/// Strategy for pull operations
enum PullStrategy: String, CaseIterable, Identifiable {
    case merge = "Merge"
    case rebase = "Rebase"
    case fastForwardOnly = "Fast-forward only"

    var id: String { rawValue }

    var gitFlag: String? {
        switch self {
        case .merge:
            return nil // Default behavior
        case .rebase:
            return "--rebase"
        case .fastForwardOnly:
            return "--ff-only"
        }
    }

    var description: String {
        switch self {
        case .merge:
            return "Create a merge commit if necessary"
        case .rebase:
            return "Rebase local commits on top of remote"
        case .fastForwardOnly:
            return "Only update if fast-forward is possible"
        }
    }
}

/// Result of a pull operation
struct PullResult: Equatable {
    /// Whether the pull was successful
    let success: Bool

    /// Number of files changed
    let filesChanged: Int

    /// Number of insertions
    let insertions: Int

    /// Number of deletions
    let deletions: Int

    /// Whether conflicts were detected
    let hasConflicts: Bool

    /// List of conflicting files
    let conflictingFiles: [String]

    /// Whether a merge commit was created
    let mergeCommitCreated: Bool

    /// Whether the pull was a fast-forward
    let wasFastForward: Bool

    /// Error message if pull failed
    let errorMessage: String?

    /// Raw output from git command
    let rawOutput: String

    /// The strategy used for the pull
    let strategy: PullStrategy

    init(
        success: Bool = true,
        filesChanged: Int = 0,
        insertions: Int = 0,
        deletions: Int = 0,
        hasConflicts: Bool = false,
        conflictingFiles: [String] = [],
        mergeCommitCreated: Bool = false,
        wasFastForward: Bool = false,
        errorMessage: String? = nil,
        rawOutput: String = "",
        strategy: PullStrategy = .merge
    ) {
        self.success = success
        self.filesChanged = filesChanged
        self.insertions = insertions
        self.deletions = deletions
        self.hasConflicts = hasConflicts
        self.conflictingFiles = conflictingFiles
        self.mergeCommitCreated = mergeCommitCreated
        self.wasFastForward = wasFastForward
        self.errorMessage = errorMessage
        self.rawOutput = rawOutput
        self.strategy = strategy
    }

    /// Whether any changes were made
    var hasChanges: Bool {
        filesChanged > 0 || insertions > 0 || deletions > 0
    }

    /// Summary message for display
    var summary: String {
        if !success {
            if hasConflicts {
                return "Pull completed with \(conflictingFiles.count) conflict\(conflictingFiles.count == 1 ? "" : "s")"
            }
            return errorMessage ?? "Pull failed"
        }

        if !hasChanges {
            return "Already up to date"
        }

        var parts: [String] = []
        if filesChanged > 0 {
            parts.append("\(filesChanged) file\(filesChanged == 1 ? "" : "s") changed")
        }
        if insertions > 0 {
            parts.append("\(insertions) insertion\(insertions == 1 ? "" : "s")(+)")
        }
        if deletions > 0 {
            parts.append("\(deletions) deletion\(deletions == 1 ? "" : "s")(-)")
        }

        if wasFastForward {
            parts.append("(fast-forward)")
        } else if mergeCommitCreated {
            parts.append("(merge)")
        }

        return parts.joined(separator: ", ")
    }
}

/// Result of checking for available updates
struct RemoteUpdatesInfo: Equatable {
    /// Number of commits ahead of remote
    let ahead: Int

    /// Number of commits behind remote
    let behind: Int

    /// Whether there are incoming changes to pull
    var hasIncomingChanges: Bool { behind > 0 }

    /// Whether there are outgoing changes to push
    var hasOutgoingChanges: Bool { ahead > 0 }

    /// Whether there are any differences with remote
    var hasDifferences: Bool { ahead > 0 || behind > 0 }

    /// Summary for display
    var summary: String {
        if !hasDifferences {
            return "Up to date"
        }
        var parts: [String] = []
        if ahead > 0 {
            parts.append("\(ahead) ahead")
        }
        if behind > 0 {
            parts.append("\(behind) behind")
        }
        return parts.joined(separator: ", ")
    }
}
