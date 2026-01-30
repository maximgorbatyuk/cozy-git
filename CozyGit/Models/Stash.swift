//
//  Stash.swift
//  CozyGit
//

import Foundation

struct Stash: Identifiable, Codable, Hashable {
    var id: String { "\(index)" }
    let index: Int
    let message: String
    let branchName: String?
    let date: Date

    init(index: Int, message: String, branchName: String? = nil, date: Date = Date()) {
        self.index = index
        self.message = message
        self.branchName = branchName
        self.date = date
    }

    var displayName: String {
        "stash@{\(index)}"
    }
}
