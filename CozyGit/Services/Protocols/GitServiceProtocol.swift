//
//  GitServiceProtocol.swift
//  CozyGit
//

import Foundation

// MARK: - Repository Operations

protocol GitRepositoryServiceProtocol {
    func openRepository(at path: URL) async throws -> Repository
    func initRepository(at path: URL, bare: Bool) async throws -> Repository
    func cloneRepository(from url: URL, to path: URL) async throws -> Repository
    func getStatus() async throws -> [FileStatus]
    func isGitRepository(at path: URL) async -> Bool
}

// MARK: - Branch Operations

protocol GitBranchServiceProtocol {
    func listBranches() async throws -> [Branch]
    func createBranch(name: String, from: String?) async throws -> Branch
    func checkoutBranch(name: String) async throws
    func deleteBranch(name: String, force: Bool) async throws
    func renameBranch(oldName: String, newName: String) async throws
    func getCurrentBranch() async throws -> String?
    func getMergedBranches(into baseBranch: String) async throws -> [Branch]
}

// MARK: - Commit Operations

protocol GitCommitServiceProtocol {
    func getHistory(limit: Int, branch: String?) async throws -> [Commit]
    func commit(message: String, amend: Bool) async throws -> Commit
    func getCommit(hash: String) async throws -> Commit
    func stageFile(path: String) async throws
    func unstageFile(path: String) async throws
    func stageAllFiles() async throws
    func discardChanges(path: String) async throws
}

// MARK: - Remote Operations

protocol GitRemoteServiceProtocol {
    func listRemotes() async throws -> [Remote]
    func addRemote(name: String, url: URL) async throws
    func removeRemote(name: String) async throws
    func fetch(remote: String?, prune: Bool) async throws
    func pull(remote: String?, branch: String?) async throws
    func push(remote: String?, branch: String?, force: Bool) async throws
}

// MARK: - Stash Operations

protocol GitStashServiceProtocol {
    func listStashes() async throws -> [Stash]
    func createStash(message: String?, includeUntracked: Bool) async throws -> Stash
    func applyStash(index: Int, pop: Bool) async throws
    func dropStash(index: Int) async throws
}

// MARK: - Tag Operations

protocol GitTagServiceProtocol {
    func listTags() async throws -> [Tag]
    func createTag(name: String, message: String?, commit: String?) async throws -> Tag
    func deleteTag(name: String) async throws
}

// MARK: - Combined Protocol

protocol GitServiceProtocol: GitRepositoryServiceProtocol,
                              GitBranchServiceProtocol,
                              GitCommitServiceProtocol,
                              GitRemoteServiceProtocol,
                              GitStashServiceProtocol,
                              GitTagServiceProtocol {
    var currentRepository: Repository? { get }
}
