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
}
