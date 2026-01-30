//
//  FetchResult.swift
//  CozyGit
//

import Foundation

/// Result of a fetch operation
struct FetchResult: Equatable {
    /// Number of new commits fetched
    let newCommits: Int

    /// Branches that were updated
    let updatedBranches: [String]

    /// Whether the fetch was successful
    let success: Bool

    /// Error message if fetch failed
    let errorMessage: String?

    /// Raw output from git command
    let rawOutput: String

    init(
        newCommits: Int = 0,
        updatedBranches: [String] = [],
        success: Bool = true,
        errorMessage: String? = nil,
        rawOutput: String = ""
    ) {
        self.newCommits = newCommits
        self.updatedBranches = updatedBranches
        self.success = success
        self.errorMessage = errorMessage
        self.rawOutput = rawOutput
    }

    /// Whether any updates were received
    var hasUpdates: Bool {
        newCommits > 0 || !updatedBranches.isEmpty
    }

    /// Summary message for display
    var summary: String {
        if !success {
            return errorMessage ?? "Fetch failed"
        }
        if !hasUpdates {
            return "Already up to date"
        }
        var parts: [String] = []
        if newCommits > 0 {
            parts.append("\(newCommits) new commit\(newCommits == 1 ? "" : "s")")
        }
        if !updatedBranches.isEmpty {
            parts.append("\(updatedBranches.count) branch\(updatedBranches.count == 1 ? "" : "es") updated")
        }
        return parts.joined(separator: ", ")
    }
}
