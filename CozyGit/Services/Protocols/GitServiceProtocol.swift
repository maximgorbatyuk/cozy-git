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
    func getAheadBehindCount() async throws -> RemoteTrackingStatus?
}

// MARK: - Branch Operations

protocol GitBranchServiceProtocol {
    func listBranches() async throws -> [Branch]
    func createBranch(name: String, from: String?) async throws -> Branch
    func checkoutBranch(name: String) async throws
    func deleteBranch(name: String, force: Bool) async throws
    func deleteRemoteBranch(name: String, remote: String) async throws
    func renameBranch(oldName: String, newName: String) async throws
    func getCurrentBranch() async throws -> String?
    func getMergedBranches(into baseBranch: String) async throws -> [Branch]
    func getStaleBranches(olderThanDays: Int) async throws -> [Branch]
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
    func fetchWithResult(remote: String?, prune: Bool) async throws -> FetchResult
    func pull(remote: String?, branch: String?) async throws
    func pullWithStrategy(remote: String?, branch: String?, strategy: PullStrategy) async throws -> PullResult
    func push(remote: String?, branch: String?, force: Bool) async throws
    func pushWithOptions(_ options: PushOptions) async throws -> PushResult
    func pushTags(remote: String?, tags: [String]?) async throws -> PushResult
    func setUpstream(remote: String, branch: String) async throws
}

// MARK: - Stash Operations

protocol GitStashServiceProtocol {
    func listStashes() async throws -> [Stash]
    func createStash(message: String?, includeUntracked: Bool) async throws -> Stash
    func applyStash(index: Int, pop: Bool) async throws
    func dropStash(index: Int) async throws
    func getStashDiff(index: Int) async throws -> Diff
}

// MARK: - Tag Operations

protocol GitTagServiceProtocol {
    func listTags() async throws -> [Tag]
    func createTag(name: String, message: String?, commit: String?) async throws -> Tag
    func deleteTag(name: String) async throws
    func deleteRemoteTag(name: String, remote: String) async throws
}

// MARK: - Merge & Rebase Operations

protocol GitMergeRebaseServiceProtocol {
    // Merge operations
    func mergeBranch(_ branch: String, strategy: MergeStrategy, message: String?) async throws -> MergeResult
    func abortMerge() async throws
    func continueMerge() async throws -> MergeResult

    // Rebase operations
    func rebase(onto branch: String) async throws -> RebaseResult
    func continueRebase() async throws -> RebaseResult
    func abortRebase() async throws
    func skipRebaseCommit() async throws -> RebaseResult

    // Operation state
    func getOperationState() async throws -> OperationState
    func getConflictedFiles() async throws -> [ConflictedFile]

    // Conflict resolution
    func acceptCurrentChanges(for path: String) async throws
    func acceptIncomingChanges(for path: String) async throws
    func markConflictResolved(for path: String) async throws
}

// MARK: - Diff Operations

protocol GitDiffServiceProtocol {
    /// Get diff for working directory changes
    func getDiff(options: DiffOptions) async throws -> Diff

    /// Get diff for a specific file
    func getDiffForFile(path: String, staged: Bool) async throws -> FileDiff?

    /// Get diff for a specific commit
    func getDiffForCommit(hash: String) async throws -> Diff

    /// Get diff between two commits
    func getDiffBetweenCommits(from: String, to: String) async throws -> Diff
}

// MARK: - Advanced Operations

protocol GitAdvancedOperationsProtocol {
    // Reset operations
    func reset(to commit: String, mode: ResetMode) async throws -> ResetResult

    // Cherry-pick operations
    func cherryPick(commit: String) async throws -> CherryPickResult
    func cherryPickContinue() async throws -> CherryPickResult
    func cherryPickAbort() async throws

    // Revert operations
    func revert(commit: String) async throws -> RevertResult
    func revertContinue() async throws -> RevertResult
    func revertAbort() async throws

    // Blame operations
    func blame(file: String) async throws -> BlameInfo
}

// MARK: - Submodule Operations

protocol GitSubmoduleServiceProtocol {
    func listSubmodules() async throws -> [Submodule]
    func addSubmodule(url: URL, path: String, branch: String?) async throws
    func initSubmodule(path: String?) async throws
    func updateSubmodules(recursive: Bool, init: Bool) async throws -> [SubmoduleUpdateResult]
    func updateSubmodule(path: String, recursive: Bool) async throws -> SubmoduleUpdateResult
    func removeSubmodule(path: String) async throws
    func syncSubmodules() async throws
}

// MARK: - Combined Protocol

protocol GitServiceProtocol: GitRepositoryServiceProtocol,
                              GitBranchServiceProtocol,
                              GitCommitServiceProtocol,
                              GitRemoteServiceProtocol,
                              GitStashServiceProtocol,
                              GitTagServiceProtocol,
                              GitMergeRebaseServiceProtocol,
                              GitDiffServiceProtocol,
                              GitAdvancedOperationsProtocol,
                              GitSubmoduleServiceProtocol {
    var currentRepository: Repository? { get }
}
