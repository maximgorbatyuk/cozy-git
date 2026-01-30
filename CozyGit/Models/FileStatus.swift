//
//  FileStatus.swift
//  CozyGit
//

import Foundation

struct FileStatus: Identifiable, Codable, Hashable {
    var id: String { path }
    let path: String
    let oldPath: String?
    let status: FileChangeType
    var isStaged: Bool
    var isConflicted: Bool

    init(
        path: String,
        oldPath: String? = nil,
        status: FileChangeType,
        isStaged: Bool = false,
        isConflicted: Bool = false
    ) {
        self.path = path
        self.oldPath = oldPath
        self.status = status
        self.isStaged = isStaged
        self.isConflicted = isConflicted
    }
}

enum FileChangeType: String, Codable, CaseIterable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case ignored = "!"

    var displayName: String {
        switch self {
        case .modified: return "Modified"
        case .added: return "Added"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .untracked: return "Untracked"
        case .ignored: return "Ignored"
        }
    }

    var symbolName: String {
        switch self {
        case .modified: return "pencil"
        case .added: return "plus"
        case .deleted: return "minus"
        case .renamed: return "arrow.right"
        case .copied: return "doc.on.doc"
        case .untracked: return "questionmark"
        case .ignored: return "eye.slash"
        }
    }
}
