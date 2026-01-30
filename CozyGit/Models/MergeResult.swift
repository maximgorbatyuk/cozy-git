//
//  MergeResult.swift
//  CozyGit
//

import Foundation

/// Strategy for merge operations
enum MergeStrategy: String, CaseIterable, Identifiable {
    case merge = "Merge"
    case fastForwardOnly = "Fast-forward only"
    case noFastForward = "No fast-forward"
    case squash = "Squash"

    var id: String { rawValue }

    /// Git command flag for this strategy
    var gitFlag: String? {
        switch self {
        case .merge:
            return nil // default behavior
        case .fastForwardOnly:
            return "--ff-only"
        case .noFastForward:
            return "--no-ff"
        case .squash:
            return "--squash"
        }
    }

    /// Description of what this strategy does
    var description: String {
        switch self {
        case .merge:
            return "Use fast-forward when possible, otherwise create a merge commit"
        case .fastForwardOnly:
            return "Only merge if fast-forward is possible (no divergent history)"
        case .noFastForward:
            return "Always create a merge commit, even if fast-forward is possible"
        case .squash:
            return "Combine all commits into a single commit (requires manual commit)"
        }
    }
}

/// Result of a merge operation
struct MergeResult: Equatable {
    /// Whether the merge was successful
    let success: Bool

    /// Whether the merge was a fast-forward
    let wasFastForward: Bool

    /// Whether a merge commit was created
    let mergeCommitCreated: Bool

    /// Whether this was a squash merge (needs manual commit)
    let wasSquash: Bool

    /// Number of commits merged
    let commitsMerged: Int

    /// Number of files changed
    let filesChanged: Int

    /// Number of insertions
    let insertions: Int

    /// Number of deletions
    let deletions: Int

    /// Whether there are conflicts
    let hasConflicts: Bool

    /// List of conflicted files
    let conflictingFiles: [String]

    /// The branch that was merged
    let sourceBranch: String?

    /// Error message if merge failed
    let errorMessage: String?

    /// Raw output from git command
    let rawOutput: String

    /// The strategy used for the merge
    let strategy: MergeStrategy

    init(
        success: Bool = true,
        wasFastForward: Bool = false,
        mergeCommitCreated: Bool = false,
        wasSquash: Bool = false,
        commitsMerged: Int = 0,
        filesChanged: Int = 0,
        insertions: Int = 0,
        deletions: Int = 0,
        hasConflicts: Bool = false,
        conflictingFiles: [String] = [],
        sourceBranch: String? = nil,
        errorMessage: String? = nil,
        rawOutput: String = "",
        strategy: MergeStrategy = .merge
    ) {
        self.success = success
        self.wasFastForward = wasFastForward
        self.mergeCommitCreated = mergeCommitCreated
        self.wasSquash = wasSquash
        self.commitsMerged = commitsMerged
        self.filesChanged = filesChanged
        self.insertions = insertions
        self.deletions = deletions
        self.hasConflicts = hasConflicts
        self.conflictingFiles = conflictingFiles
        self.sourceBranch = sourceBranch
        self.errorMessage = errorMessage
        self.rawOutput = rawOutput
        self.strategy = strategy
    }

    /// Summary message for display
    var summary: String {
        if hasConflicts {
            return "Merge has \(conflictingFiles.count) conflict(s) to resolve"
        }

        if !success {
            return errorMessage ?? "Merge failed"
        }

        if wasSquash {
            return "Squash merge ready - commit to complete"
        }

        var parts: [String] = []

        if wasFastForward {
            parts.append("Fast-forward")
        } else if mergeCommitCreated {
            parts.append("Merge commit created")
        }

        if filesChanged > 0 {
            parts.append("\(filesChanged) file(s) changed")
        }

        if parts.isEmpty {
            return "Already up to date"
        }

        return parts.joined(separator: ", ")
    }

    /// Whether the merge has any changes
    var hasChanges: Bool {
        filesChanged > 0 || insertions > 0 || deletions > 0
    }
}

/// Options for merge operation
struct MergeOptions {
    /// The branch to merge
    var sourceBranch: String

    /// The strategy to use
    var strategy: MergeStrategy = .merge

    /// Custom commit message (for non-fast-forward merges)
    var commitMessage: String?

    /// Whether to abort if there are conflicts
    var abortOnConflict: Bool = false
}
