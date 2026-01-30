//
//  Remote.swift
//  CozyGit
//

import Foundation

struct Remote: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let fetchURL: URL?
    let pushURL: URL?

    init(name: String, fetchURL: URL? = nil, pushURL: URL? = nil) {
        self.name = name
        self.fetchURL = fetchURL
        self.pushURL = pushURL ?? fetchURL
    }
}
