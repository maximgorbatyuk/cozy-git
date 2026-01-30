//
//  GitCommitServiceProtocol.swift
//  CozyGit
//
//  Note: This protocol is defined in GitServiceProtocol.swift
//  This file exists for organizational purposes and future extensions.
//

import Foundation

// Commit-specific extensions can be added here
extension Commit {
    var shortMessage: String {
        let firstLine = message.components(separatedBy: .newlines).first ?? message
        if firstLine.count > 72 {
            return String(firstLine.prefix(69)) + "..."
        }
        return firstLine
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var isMergeCommit: Bool {
        parents.count > 1
    }
}
