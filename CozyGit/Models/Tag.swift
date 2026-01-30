//
//  Tag.swift
//  CozyGit
//

import Foundation

struct Tag: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let commitHash: String
    let message: String?
    let taggerName: String?
    let taggerEmail: String?
    let date: Date?
    let isAnnotated: Bool

    init(
        name: String,
        commitHash: String,
        message: String? = nil,
        taggerName: String? = nil,
        taggerEmail: String? = nil,
        date: Date? = nil,
        isAnnotated: Bool = false
    ) {
        self.name = name
        self.commitHash = commitHash
        self.message = message
        self.taggerName = taggerName
        self.taggerEmail = taggerEmail
        self.date = date
        self.isAnnotated = isAnnotated
    }
}
