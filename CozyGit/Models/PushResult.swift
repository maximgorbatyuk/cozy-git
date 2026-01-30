//
//  PushResult.swift
//  CozyGit
//

import Foundation

/// Result of a push operation
struct PushResult: Equatable {
    /// Whether the push was successful
    let success: Bool

    /// Number of commits pushed
    let commitsPushed: Int

    /// The remote branch that was pushed to
    let remoteBranch: String?

    /// Whether a new branch was created on the remote
    let createdRemoteBranch: Bool

    /// Whether this was a force push
    let wasForcePush: Bool

    /// Whether tags were pushed
    let tagsPushed: Int

    /// Error message if push failed
    let errorMessage: String?

    /// Raw output from git command
    let rawOutput: String

    /// Whether the push was rejected (needs pull first)
    let wasRejected: Bool

    /// Whether authentication failed
    let authenticationFailed: Bool

    init(
        success: Bool = true,
        commitsPushed: Int = 0,
        remoteBranch: String? = nil,
        createdRemoteBranch: Bool = false,
        wasForcePush: Bool = false,
        tagsPushed: Int = 0,
        errorMessage: String? = nil,
        rawOutput: String = "",
        wasRejected: Bool = false,
        authenticationFailed: Bool = false
    ) {
        self.success = success
        self.commitsPushed = commitsPushed
        self.remoteBranch = remoteBranch
        self.createdRemoteBranch = createdRemoteBranch
        self.wasForcePush = wasForcePush
        self.tagsPushed = tagsPushed
        self.errorMessage = errorMessage
        self.rawOutput = rawOutput
        self.wasRejected = wasRejected
        self.authenticationFailed = authenticationFailed
    }

    /// Summary message for display
    var summary: String {
        if !success {
            if wasRejected {
                return "Push rejected - pull changes first"
            }
            if authenticationFailed {
                return "Authentication failed"
            }
            return errorMessage ?? "Push failed"
        }

        var parts: [String] = []

        if commitsPushed > 0 {
            parts.append("\(commitsPushed) commit\(commitsPushed == 1 ? "" : "s") pushed")
        }

        if tagsPushed > 0 {
            parts.append("\(tagsPushed) tag\(tagsPushed == 1 ? "" : "s") pushed")
        }

        if createdRemoteBranch {
            parts.append("new branch created")
        }

        if wasForcePush {
            parts.append("(force)")
        }

        if parts.isEmpty {
            return "Already up to date"
        }

        return parts.joined(separator: ", ")
    }
}

/// Options for push operation
struct PushOptions {
    /// Remote to push to (default: origin)
    var remote: String = "origin"

    /// Branch to push (default: current branch)
    var branch: String?

    /// Whether to force push
    var force: Bool = false

    /// Whether to use force-with-lease (safer force push)
    var forceWithLease: Bool = true

    /// Whether to push tags
    var pushTags: Bool = false

    /// Whether to push all tags
    var pushAllTags: Bool = false

    /// Whether to set upstream tracking
    var setUpstream: Bool = false

    /// Specific tags to push
    var tags: [String] = []
}
