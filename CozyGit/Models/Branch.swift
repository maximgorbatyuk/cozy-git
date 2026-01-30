//
//  Branch.swift
//  CozyGit
//

import Foundation

struct Branch: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let isLocal: Bool
    let isRemote: Bool
    var isCurrent: Bool
    var lastCommit: Commit?
    var isMerged: Bool
    var isProtected: Bool
    var commitCount: Int
    var upstream: String?

    init(
        name: String,
        isLocal: Bool = true,
        isRemote: Bool = false,
        isCurrent: Bool = false,
        lastCommit: Commit? = nil,
        isMerged: Bool = false,
        isProtected: Bool = false,
        commitCount: Int = 0,
        upstream: String? = nil
    ) {
        self.name = name
        self.isLocal = isLocal
        self.isRemote = isRemote
        self.isCurrent = isCurrent
        self.lastCommit = lastCommit
        self.isMerged = isMerged
        self.isProtected = isProtected
        self.commitCount = commitCount
        self.upstream = upstream
    }

    // MARK: - Convenience initializer for UI previews

    init(
        name: String,
        isHead: Bool = false,
        isRemote: Bool = false,
        trackingBranch: String? = nil,
        lastCommitDate: Date? = nil,
        lastCommitHash: String? = nil
    ) {
        self.name = name
        self.isLocal = !isRemote
        self.isRemote = isRemote
        self.isCurrent = isHead
        self.upstream = trackingBranch
        self.isMerged = false
        self.isProtected = false
        self.commitCount = 0

        // Create a minimal commit if date or hash provided
        if lastCommitDate != nil || lastCommitHash != nil {
            self.lastCommit = Commit(
                hash: lastCommitHash ?? "",
                message: "",
                author: "",
                authorEmail: "",
                date: lastCommitDate ?? Date()
            )
        } else {
            self.lastCommit = nil
        }
    }

    // MARK: - Computed Properties

    /// Alias for isCurrent (used in UI)
    var isHead: Bool { isCurrent }

    /// Alias for upstream (used in UI)
    var trackingBranch: String? { upstream }

    /// Last commit date from the associated commit
    var lastCommitDate: Date? { lastCommit?.date }

    /// Last commit hash from the associated commit
    var lastCommitHash: String? { lastCommit?.hash }
}
