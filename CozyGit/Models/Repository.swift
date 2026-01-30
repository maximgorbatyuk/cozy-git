//
//  Repository.swift
//  CozyGit
//

import Foundation

struct Repository: Identifiable, Codable, Hashable {
    let id: UUID
    let path: URL
    let name: String
    var currentBranch: String?
    let isBare: Bool
    var remotes: [Remote]
    var lastCommitDate: Date?

    init(
        id: UUID = UUID(),
        path: URL,
        name: String? = nil,
        currentBranch: String? = nil,
        isBare: Bool = false,
        remotes: [Remote] = [],
        lastCommitDate: Date? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name ?? path.lastPathComponent
        self.currentBranch = currentBranch
        self.isBare = isBare
        self.remotes = remotes
        self.lastCommitDate = lastCommitDate
    }
}
