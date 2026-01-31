//
//  LocalizationManager.swift
//  CozyGit
//
//  Phase 20: Accessibility & Localization

import Foundation
import SwiftUI

// MARK: - Localized Strings

/// Centralized localized strings for the app
/// Using Swift String(localized:) for compile-time safety
enum L10n {
    // MARK: - App General

    static let appName = String(localized: "Cozy Git", comment: "App name")

    // MARK: - Navigation

    enum Nav {
        static let overview = String(localized: "Overview", comment: "Overview tab")
        static let changes = String(localized: "Changes", comment: "Changes tab")
        static let branches = String(localized: "Branches", comment: "Branches tab")
        static let history = String(localized: "History", comment: "History tab")
        static let stash = String(localized: "Stash", comment: "Stash tab")
        static let tags = String(localized: "Tags", comment: "Tags tab")
        static let remotes = String(localized: "Remotes", comment: "Remotes tab")
        static let submodules = String(localized: "Submodules", comment: "Submodules tab")
        static let gitignore = String(localized: "Gitignore", comment: "Gitignore tab")
        static let automation = String(localized: "Automation", comment: "Automation tab")
        static let cleanup = String(localized: "Cleanup", comment: "Cleanup tab")
    }

    // MARK: - Common Actions

    enum Action {
        static let ok = String(localized: "OK", comment: "OK button")
        static let cancel = String(localized: "Cancel", comment: "Cancel button")
        static let close = String(localized: "Close", comment: "Close button")
        static let save = String(localized: "Save", comment: "Save button")
        static let delete = String(localized: "Delete", comment: "Delete button")
        static let edit = String(localized: "Edit", comment: "Edit button")
        static let add = String(localized: "Add", comment: "Add button")
        static let remove = String(localized: "Remove", comment: "Remove button")
        static let refresh = String(localized: "Refresh", comment: "Refresh button")
        static let copy = String(localized: "Copy", comment: "Copy button")
        static let search = String(localized: "Search", comment: "Search action")
        static let filter = String(localized: "Filter", comment: "Filter action")
        static let selectAll = String(localized: "Select All", comment: "Select all action")
        static let deselectAll = String(localized: "Deselect All", comment: "Deselect all action")
    }

    // MARK: - Repository

    enum Repo {
        static let open = String(localized: "Open Repository", comment: "Open repository action")
        static let close = String(localized: "Close Repository", comment: "Close repository action")
        static let clone = String(localized: "Clone Repository", comment: "Clone repository action")
        static let initialize = String(localized: "Initialize Repository", comment: "Initialize repository action")
        static let recent = String(localized: "Recent Repositories", comment: "Recent repositories section")
        static let noOpen = String(localized: "No Repository Open", comment: "No repository open title")
        static let noOpenMessage = String(localized: "Open a repository to get started", comment: "No repository open message")
    }

    // MARK: - Branches

    enum Branch {
        static let current = String(localized: "Current Branch", comment: "Current branch label")
        static let local = String(localized: "Local Branches", comment: "Local branches section")
        static let remote = String(localized: "Remote Branches", comment: "Remote branches section")
        static let create = String(localized: "Create Branch", comment: "Create branch action")
        static let delete = String(localized: "Delete Branch", comment: "Delete branch action")
        static let rename = String(localized: "Rename Branch", comment: "Rename branch action")
        static let checkout = String(localized: "Switch to Branch", comment: "Checkout branch action")
        static let merge = String(localized: "Merge Branch", comment: "Merge branch action")
        static let rebase = String(localized: "Rebase", comment: "Rebase action")
        static let namePlaceholder = String(localized: "Branch name", comment: "Branch name placeholder")
        static let fromPlaceholder = String(localized: "Create from (optional)", comment: "Create from placeholder")
        static let merged = String(localized: "Merged Branches", comment: "Merged branches section")
        static let stale = String(localized: "Stale Branches", comment: "Stale branches section")
    }

    // MARK: - Commits

    enum Commit {
        static let title = String(localized: "Commit", comment: "Commit title")
        static let messagePlaceholder = String(localized: "Enter commit message...", comment: "Commit message placeholder")
        static let messageRequired = String(localized: "Commit message is required", comment: "Commit message required error")
        static let amend = String(localized: "Amend previous commit", comment: "Amend commit option")
        static let stagedFiles = String(localized: "Staged Files", comment: "Staged files section")
        static let noStaged = String(localized: "No staged files", comment: "No staged files message")
        static let success = String(localized: "Changes committed successfully", comment: "Commit success message")
    }

    // MARK: - Changes

    enum Changes {
        static let staged = String(localized: "Staged Changes", comment: "Staged changes section")
        static let unstaged = String(localized: "Unstaged Changes", comment: "Unstaged changes section")
        static let noChanges = String(localized: "No Changes", comment: "No changes title")
        static let noChangesMessage = String(localized: "Working directory is clean", comment: "No changes message")
        static let stage = String(localized: "Stage", comment: "Stage action")
        static let unstage = String(localized: "Unstage", comment: "Unstage action")
        static let stageAll = String(localized: "Stage All", comment: "Stage all action")
        static let unstageAll = String(localized: "Unstage All", comment: "Unstage all action")
        static let discard = String(localized: "Discard Changes", comment: "Discard changes action")
        static let discardConfirm = String(localized: "Are you sure you want to discard changes to this file? This cannot be undone.", comment: "Discard confirm message")
    }

    // MARK: - File Status

    enum Status {
        static let modified = String(localized: "Modified", comment: "Modified status")
        static let added = String(localized: "Added", comment: "Added status")
        static let deleted = String(localized: "Deleted", comment: "Deleted status")
        static let renamed = String(localized: "Renamed", comment: "Renamed status")
        static let copied = String(localized: "Copied", comment: "Copied status")
        static let untracked = String(localized: "Untracked", comment: "Untracked status")
        static let ignored = String(localized: "Ignored", comment: "Ignored status")

        static func forType(_ type: FileChangeType) -> String {
            switch type {
            case .modified: return modified
            case .added: return added
            case .deleted: return deleted
            case .renamed: return renamed
            case .copied: return copied
            case .untracked: return untracked
            case .ignored: return ignored
            }
        }
    }

    // MARK: - Diff View

    enum Diff {
        static let unified = String(localized: "Unified", comment: "Unified diff view")
        static let sideBySide = String(localized: "Side by Side", comment: "Side by side diff view")
        static let noChanges = String(localized: "No changes to display", comment: "No diff changes")
        static let binaryFile = String(localized: "Binary file", comment: "Binary file label")
        static let binaryMessage = String(localized: "Cannot display diff for binary files", comment: "Binary file message")
        static let nextChange = String(localized: "Next Change", comment: "Next change action")
        static let previousChange = String(localized: "Previous Change", comment: "Previous change action")

        static func additions(_ count: Int) -> String {
            String(localized: "\(count) additions", comment: "Additions count")
        }

        static func deletions(_ count: Int) -> String {
            String(localized: "\(count) deletions", comment: "Deletions count")
        }

        static func changeOf(current: Int, total: Int) -> String {
            String(localized: "Change \(current) of \(total)", comment: "Change navigation")
        }
    }

    // MARK: - Remote Operations

    enum Remote {
        static let fetch = String(localized: "Fetch", comment: "Fetch action")
        static let pull = String(localized: "Pull", comment: "Pull action")
        static let push = String(localized: "Push", comment: "Push action")
        static let add = String(localized: "Add Remote", comment: "Add remote action")
        static let remove = String(localized: "Remove Remote", comment: "Remove remote action")
        static let name = String(localized: "Remote Name", comment: "Remote name label")
        static let url = String(localized: "Remote URL", comment: "Remote URL label")
        static let upToDate = String(localized: "Up to date", comment: "Up to date status")

        static func ahead(_ count: Int) -> String {
            String(localized: "\(count) ahead", comment: "Ahead count")
        }

        static func behind(_ count: Int) -> String {
            String(localized: "\(count) behind", comment: "Behind count")
        }
    }

    // MARK: - Stash

    enum Stash {
        static let create = String(localized: "Create Stash", comment: "Create stash action")
        static let apply = String(localized: "Apply Stash", comment: "Apply stash action")
        static let pop = String(localized: "Pop Stash", comment: "Pop stash action")
        static let drop = String(localized: "Drop Stash", comment: "Drop stash action")
        static let messagePlaceholder = String(localized: "Stash message (optional)", comment: "Stash message placeholder")
        static let includeUntracked = String(localized: "Include untracked files", comment: "Include untracked option")
        static let empty = String(localized: "No Stashes", comment: "No stashes title")
        static let emptyMessage = String(localized: "Stash changes to save them for later", comment: "No stashes message")
    }

    // MARK: - Tags

    enum Tag {
        static let create = String(localized: "Create Tag", comment: "Create tag action")
        static let delete = String(localized: "Delete Tag", comment: "Delete tag action")
        static let name = String(localized: "Tag Name", comment: "Tag name label")
        static let message = String(localized: "Tag Message (optional)", comment: "Tag message label")
        static let push = String(localized: "Push Tag", comment: "Push tag action")
        static let pushAll = String(localized: "Push All Tags", comment: "Push all tags action")
        static let empty = String(localized: "No Tags", comment: "No tags title")
        static let emptyMessage = String(localized: "Create tags to mark specific points in history", comment: "No tags message")
    }

    // MARK: - Errors

    enum Error {
        static let title = String(localized: "Error", comment: "Error title")
        static let generic = String(localized: "An error occurred", comment: "Generic error")
        static let notRepository = String(localized: "Not a Git repository", comment: "Not a repository error")
        static let repositoryNotOpen = String(localized: "No repository is open", comment: "Repository not open error")
        static let commandFailed = String(localized: "Git command failed", comment: "Command failed error")
        static let network = String(localized: "Network error", comment: "Network error")
        static let conflict = String(localized: "Merge conflict detected", comment: "Conflict error")
    }

    // MARK: - Loading

    enum Loading {
        static let generic = String(localized: "Loading...", comment: "Loading generic")
        static let commits = String(localized: "Loading commits...", comment: "Loading commits")
        static let branches = String(localized: "Loading branches...", comment: "Loading branches")
        static let changes = String(localized: "Loading changes...", comment: "Loading changes")
        static let diff = String(localized: "Loading diff...", comment: "Loading diff")
    }
}

// MARK: - Pluralization Helpers

extension L10n {
    /// Format a count with proper pluralization
    static func pluralize(_ count: Int, singular: String, plural: String) -> String {
        count == 1 ? "\(count) \(singular)" : "\(count) \(plural)"
    }

    static func files(_ count: Int) -> String {
        pluralize(count, singular: "file", plural: "files")
    }

    static func commits(_ count: Int) -> String {
        pluralize(count, singular: "commit", plural: "commits")
    }

    static func branches(_ count: Int) -> String {
        pluralize(count, singular: "branch", plural: "branches")
    }

    static func changes(_ count: Int) -> String {
        pluralize(count, singular: "change", plural: "changes")
    }

    static func daysOld(_ count: Int) -> String {
        pluralize(count, singular: "day old", plural: "days old")
    }
}

// MARK: - Date Formatting

extension L10n {
    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static func fullDate(_ date: Date) -> String {
        date.formatted(date: .complete, time: .shortened)
    }
}
