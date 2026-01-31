//
//  Submodule.swift
//  CozyGit
//

import Foundation

struct Submodule: Identifiable, Equatable, Hashable {
    var id: String { path }

    let name: String
    let path: String
    let url: URL?
    let branch: String?
    let commitHash: String?
    let isInitialized: Bool
    let hasChanges: Bool

    init(
        name: String,
        path: String,
        url: URL? = nil,
        branch: String? = nil,
        commitHash: String? = nil,
        isInitialized: Bool = false,
        hasChanges: Bool = false
    ) {
        self.name = name
        self.path = path
        self.url = url
        self.branch = branch
        self.commitHash = commitHash
        self.isInitialized = isInitialized
        self.hasChanges = hasChanges
    }

    var shortHash: String? {
        guard let hash = commitHash else { return nil }
        return String(hash.prefix(7))
    }

    var displayName: String {
        name.isEmpty ? path : name
    }

    var statusDescription: String {
        if !isInitialized {
            return "Not initialized"
        } else if hasChanges {
            return "Modified"
        } else {
            return "Up to date"
        }
    }
}

// MARK: - Submodule Status

enum SubmoduleStatus: String, CaseIterable {
    case upToDate = "Up to date"
    case modified = "Modified"
    case notInitialized = "Not initialized"
    case commitBehind = "Behind"
    case commitAhead = "Ahead"
    case conflict = "Conflict"

    var iconName: String {
        switch self {
        case .upToDate: return "checkmark.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .notInitialized: return "questionmark.circle.fill"
        case .commitBehind: return "arrow.down.circle.fill"
        case .commitAhead: return "arrow.up.circle.fill"
        case .conflict: return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .upToDate: return "green"
        case .modified: return "orange"
        case .notInitialized: return "gray"
        case .commitBehind: return "blue"
        case .commitAhead: return "purple"
        case .conflict: return "red"
        }
    }
}

// MARK: - Submodule Update Result

struct SubmoduleUpdateResult: Equatable {
    let success: Bool
    let submodulePath: String
    let updatedCommit: String?
    let errorMessage: String?

    init(success: Bool, submodulePath: String, updatedCommit: String? = nil, errorMessage: String? = nil) {
        self.success = success
        self.submodulePath = submodulePath
        self.updatedCommit = updatedCommit
        self.errorMessage = errorMessage
    }

    static func success(path: String, commit: String?) -> SubmoduleUpdateResult {
        SubmoduleUpdateResult(success: true, submodulePath: path, updatedCommit: commit)
    }

    static func failure(path: String, error: String) -> SubmoduleUpdateResult {
        SubmoduleUpdateResult(success: false, submodulePath: path, errorMessage: error)
    }
}
