//
//  Commit.swift
//  CozyGit
//

import Foundation

struct Commit: Identifiable, Codable, Hashable {
    var id: String { hash }
    let hash: String
    let shortHash: String
    let message: String
    let author: String
    let authorEmail: String
    let date: Date
    let committer: String
    let committerEmail: String
    let committerDate: Date
    let parents: [String]
    var refs: [String]

    init(
        hash: String,
        shortHash: String? = nil,
        message: String,
        author: String,
        authorEmail: String,
        date: Date,
        committer: String? = nil,
        committerEmail: String? = nil,
        committerDate: Date? = nil,
        parents: [String] = [],
        refs: [String] = []
    ) {
        self.hash = hash
        self.shortHash = shortHash ?? String(hash.prefix(7))
        self.message = message
        self.author = author
        self.authorEmail = authorEmail
        self.date = date
        self.committer = committer ?? author
        self.committerEmail = committerEmail ?? authorEmail
        self.committerDate = committerDate ?? date
        self.parents = parents
        self.refs = refs
    }
}
