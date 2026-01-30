//
//  GitRepositoryServiceProtocol.swift
//  CozyGit
//
//  Note: This protocol is defined in GitServiceProtocol.swift
//  This file exists for organizational purposes and future extensions.
//

import Foundation

// Repository-specific extensions can be added here
extension Repository {
    var isValid: Bool {
        FileManager.default.fileExists(atPath: path.appendingPathComponent(".git").path)
    }

    var gitDirectory: URL {
        if isBare {
            return path
        }
        return path.appendingPathComponent(".git")
    }

    var hasRemotes: Bool {
        !remotes.isEmpty
    }

    var primaryRemote: Remote? {
        remotes.first { $0.name == "origin" } ?? remotes.first
    }
}
