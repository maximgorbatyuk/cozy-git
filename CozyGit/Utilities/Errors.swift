//
//  Errors.swift
//  CozyGit
//

import Foundation

enum GitError: LocalizedError {
    case notARepository
    case commandFailed(String)
    case parseError(String)
    case timeout
    case repositoryNotOpen
    case invalidPath(String)
    case branchNotFound(String)
    case commitNotFound(String)
    case mergeConflict
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notARepository:
            return "The specified path is not a Git repository"
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        case .parseError(let message):
            return "Failed to parse Git output: \(message)"
        case .timeout:
            return "Git operation timed out"
        case .repositoryNotOpen:
            return "No repository is currently open"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .branchNotFound(let name):
            return "Branch not found: \(name)"
        case .commitNotFound(let hash):
            return "Commit not found: \(hash)"
        case .mergeConflict:
            return "Merge conflict detected"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notARepository:
            return "Please open a valid Git repository"
        case .commandFailed:
            return "Check the Git command output for more details"
        case .parseError:
            return "This may be a bug - please report it"
        case .timeout:
            return "Try the operation again or check your network connection"
        case .repositoryNotOpen:
            return "Open a repository first using File > Open Repository"
        case .invalidPath:
            return "Verify the path exists and is accessible"
        case .branchNotFound:
            return "Verify the branch name and try again"
        case .commitNotFound:
            return "Verify the commit hash and try again"
        case .mergeConflict:
            return "Resolve the conflicts and try again"
        case .networkError:
            return "Check your network connection and try again"
        }
    }
}
