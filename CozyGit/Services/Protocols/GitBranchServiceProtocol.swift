//
//  GitBranchServiceProtocol.swift
//  CozyGit
//
//  Note: This protocol is defined in GitServiceProtocol.swift
//  This file exists for organizational purposes and future extensions.
//

import Foundation

// Branch-specific extensions can be added here
extension Branch {
    var isMain: Bool {
        name == "main" || name == "master"
    }

    var displayName: String {
        if isRemote {
            return name.replacingOccurrences(of: "origin/", with: "")
        }
        return name
    }

    var remoteName: String? {
        guard isRemote else { return nil }
        let components = name.split(separator: "/", maxSplits: 1)
        return components.first.map(String.init)
    }
}
