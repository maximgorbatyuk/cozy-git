//
//  RepositoryViewModel.swift
//  CozyGit
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class RepositoryViewModel {
    // MARK: - State

    var repository: Repository?
    var branches: [Branch] = []
    var commits: [Commit] = []
    var fileStatuses: [FileStatus] = []
    var stashes: [Stash] = []
    var tags: [Tag] = []
    var remotes: [Remote] = []

    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Remote Status

    var remoteStatus: RemoteTrackingStatus?

    // MARK: - Filtering

    var searchText: String = ""
    var fileFilter: FileFilter = .all

    enum FileFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case modified = "Modified"
        case added = "Added"
        case deleted = "Deleted"
        case untracked = "Untracked"

        var id: String { rawValue }
    }

    // MARK: - Services

    private let gitService: GitService
    private let logger = Logger.shared

    // MARK: - Initialization

    init(gitService: GitService) {
        self.gitService = gitService
    }

    // MARK: - Data Loading

    func loadAllData() async {
        guard repository != nil else { return }

        isLoading = true

        async let branchesTask = loadBranches()
        async let commitsTask = loadCommits()
        async let statusTask = loadFileStatuses()
        async let stashTask = loadStashes()
        async let tagsTask = loadTags()
        async let remotesTask = loadRemotes()
        async let remoteStatusTask = loadRemoteStatus()

        _ = await (branchesTask, commitsTask, statusTask, stashTask, tagsTask, remotesTask, remoteStatusTask)

        isLoading = false
    }

    func loadRemoteStatus() async {
        do {
            remoteStatus = try await gitService.getAheadBehindCount()
        } catch {
            // Don't treat this as a critical error
            remoteStatus = nil
        }
    }

    func loadBranches() async {
        do {
            branches = try await gitService.listBranches()
        } catch {
            handleError(error)
        }
    }

    func loadCommits(limit: Int = 50) async {
        do {
            commits = try await gitService.getHistory(limit: limit)
        } catch {
            handleError(error)
        }
    }

    func loadFileStatuses() async {
        do {
            fileStatuses = try await gitService.getStatus()
        } catch {
            handleError(error)
        }
    }

    func loadStashes() async {
        do {
            stashes = try await gitService.listStashes()
        } catch {
            handleError(error)
        }
    }

    func loadTags() async {
        do {
            tags = try await gitService.listTags()
        } catch {
            handleError(error)
        }
    }

    func loadRemotes() async {
        do {
            remotes = try await gitService.listRemotes()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Remote Management

    func addRemote(name: String, url: URL) async throws {
        try await gitService.addRemote(name: name, url: url)
        await loadRemotes()
    }

    func removeRemote(name: String) async throws {
        try await gitService.removeRemote(name: name)
        await loadRemotes()
    }

    func fetchFromRemote(_ remote: Remote, prune: Bool = false) async -> FetchResult {
        do {
            let result = try await gitService.fetchWithResult(remote: remote.name, prune: prune)
            await loadBranches()
            await loadRemoteStatus()
            return result
        } catch {
            handleError(error)
            return FetchResult(success: false, errorMessage: error.localizedDescription)
        }
    }

    // MARK: - Branch Operations

    func createBranch(name: String, from: String? = nil) async throws -> Branch {
        let branch = try await gitService.createBranch(name: name, from: from)
        await loadBranches()
        return branch
    }

    func checkoutBranch(_ branch: Branch) async {
        do {
            try await gitService.checkoutBranch(name: branch.name)
            await loadBranches()
            // Update current branch in repository
            if let currentBranch = try? await gitService.getCurrentBranch() {
                repository?.currentBranch = currentBranch
            }
        } catch {
            handleError(error)
        }
    }

    func checkoutBranch(name: String) async throws {
        try await gitService.checkoutBranch(name: name)
        await loadBranches()
        // Update current branch in repository
        if let currentBranch = try? await gitService.getCurrentBranch() {
            repository?.currentBranch = currentBranch
        }
    }

    func deleteBranch(_ branch: Branch, force: Bool = false) async {
        do {
            try await gitService.deleteBranch(name: branch.name, force: force)
            await loadBranches()
        } catch {
            handleError(error)
        }
    }

    func deleteBranch(_ branch: Branch, force: Bool = false, deleteRemote: Bool = false) async throws {
        try await gitService.deleteBranch(name: branch.name, force: force)

        if deleteRemote, let tracking = branch.trackingBranch {
            // Extract remote name and branch name from tracking branch (e.g., "origin/feature/x")
            let parts = tracking.split(separator: "/", maxSplits: 1)
            if parts.count == 2 {
                let remote = String(parts[0])
                let remoteBranchName = String(parts[1])
                try await gitService.deleteRemoteBranch(name: remoteBranchName, remote: remote)
            }
        }

        await loadBranches()
    }

    func renameBranch(_ branch: Branch, newName: String) async {
        do {
            try await gitService.renameBranch(oldName: branch.name, newName: newName)
            await loadBranches()
        } catch {
            handleError(error)
        }
    }

    func getMergedBranches(into baseBranch: String) async -> [Branch] {
        do {
            return try await gitService.getMergedBranches(into: baseBranch)
        } catch {
            handleError(error)
            return []
        }
    }

    func getStaleBranches(olderThanDays: Int = 90) async -> [Branch] {
        do {
            return try await gitService.getStaleBranches(olderThanDays: olderThanDays)
        } catch {
            handleError(error)
            return []
        }
    }

    // MARK: - Staging Operations

    func stageFile(_ file: FileStatus) async {
        do {
            try await gitService.stageFile(path: file.path)
            await loadFileStatuses()
        } catch {
            handleError(error)
        }
    }

    func unstageFile(_ file: FileStatus) async {
        do {
            try await gitService.unstageFile(path: file.path)
            await loadFileStatuses()
        } catch {
            handleError(error)
        }
    }

    func stageAllFiles() async {
        do {
            try await gitService.stageAllFiles()
            await loadFileStatuses()
        } catch {
            handleError(error)
        }
    }

    func unstageAllFiles() async {
        for file in stagedFiles {
            do {
                try await gitService.unstageFile(path: file.path)
            } catch {
                handleError(error)
            }
        }
        await loadFileStatuses()
    }

    func discardChanges(_ file: FileStatus) async {
        do {
            try await gitService.discardChanges(path: file.path)
            await loadFileStatuses()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Commit Operations

    func commit(message: String, amend: Bool = false) async {
        do {
            _ = try await gitService.commit(message: message, amend: amend)
            await loadCommits()
            await loadFileStatuses()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Remote Operations

    func fetch(prune: Bool = false) async {
        do {
            try await gitService.fetch(prune: prune)
            await loadBranches()
            await loadRemoteStatus()
        } catch {
            handleError(error)
        }
    }

    func fetchWithResult(prune: Bool = false) async -> FetchResult {
        do {
            let result = try await gitService.fetchWithResult(remote: nil, prune: prune)
            await loadBranches()
            await loadRemoteStatus()
            return result
        } catch {
            handleError(error)
            return FetchResult(success: false, errorMessage: error.localizedDescription)
        }
    }

    func pull() async {
        do {
            try await gitService.pull()
            await loadCommits()
            await loadFileStatuses()
            await loadRemoteStatus()
        } catch {
            handleError(error)
        }
    }

    func pullWithStrategy(remote: String? = nil, branch: String? = nil, strategy: PullStrategy = .merge) async throws -> PullResult {
        let result = try await gitService.pullWithStrategy(remote: remote, branch: branch, strategy: strategy)
        await loadCommits()
        await loadFileStatuses()
        await loadRemoteStatus()
        return result
    }

    func push(force: Bool = false) async {
        do {
            try await gitService.push(force: force)
            await loadRemoteStatus()
        } catch {
            handleError(error)
        }
    }

    func pushWithOptions(_ options: PushOptions) async throws -> PushResult {
        let result = try await gitService.pushWithOptions(options)
        await loadRemoteStatus()
        await loadBranches()
        return result
    }

    func pushTags(remote: String? = nil, tags: [String]? = nil) async throws -> PushResult {
        let result = try await gitService.pushTags(remote: remote, tags: tags)
        await loadTags()
        return result
    }

    func setUpstream(remote: String, branch: String) async throws {
        try await gitService.setUpstream(remote: remote, branch: branch)
        await loadBranches()
    }

    // MARK: - Merge Operations

    func mergeBranch(_ branch: String, strategy: MergeStrategy = .merge, message: String? = nil) async throws -> MergeResult {
        let result = try await gitService.mergeBranch(branch, strategy: strategy, message: message)
        await loadCommits()
        await loadFileStatuses()
        await loadBranches()
        return result
    }

    func abortMerge() async throws {
        try await gitService.abortMerge()
        await loadFileStatuses()
        await loadBranches()
    }

    func continueMerge() async throws -> MergeResult {
        let result = try await gitService.continueMerge()
        await loadCommits()
        await loadFileStatuses()
        return result
    }

    // MARK: - Rebase Operations

    func rebase(onto branch: String) async throws -> RebaseResult {
        let result = try await gitService.rebase(onto: branch)
        if result.success && !result.hasConflicts {
            await loadCommits()
            await loadBranches()
        }
        await loadFileStatuses()
        return result
    }

    func continueRebase() async throws -> RebaseResult {
        let result = try await gitService.continueRebase()
        if result.success && !result.hasConflicts {
            await loadCommits()
            await loadBranches()
        }
        await loadFileStatuses()
        return result
    }

    func abortRebase() async throws {
        try await gitService.abortRebase()
        await loadCommits()
        await loadFileStatuses()
        await loadBranches()
    }

    func skipRebaseCommit() async throws -> RebaseResult {
        let result = try await gitService.skipRebaseCommit()
        if result.success && !result.hasConflicts {
            await loadCommits()
            await loadBranches()
        }
        await loadFileStatuses()
        return result
    }

    // MARK: - Operation State & Conflicts

    func getOperationState() async -> OperationState {
        do {
            return try await gitService.getOperationState()
        } catch {
            handleError(error)
            return .none
        }
    }

    func getConflictedFiles() async -> [ConflictedFile] {
        do {
            return try await gitService.getConflictedFiles()
        } catch {
            handleError(error)
            return []
        }
    }

    func acceptCurrentChanges(for path: String) async throws {
        try await gitService.acceptCurrentChanges(for: path)
        await loadFileStatuses()
    }

    func acceptIncomingChanges(for path: String) async throws {
        try await gitService.acceptIncomingChanges(for: path)
        await loadFileStatuses()
    }

    func markConflictResolved(for path: String) async throws {
        try await gitService.markConflictResolved(for: path)
        await loadFileStatuses()
    }

    // MARK: - Diff Operations

    func getDiff(staged: Bool = false) async -> Diff {
        do {
            let options = DiffOptions(staged: staged)
            return try await gitService.getDiff(options: options)
        } catch {
            handleError(error)
            return Diff()
        }
    }

    func getDiffForFile(path: String, staged: Bool = false) async -> FileDiff? {
        do {
            return try await gitService.getDiffForFile(path: path, staged: staged)
        } catch {
            handleError(error)
            return nil
        }
    }

    func getDiffForCommit(hash: String) async -> Diff {
        do {
            return try await gitService.getDiffForCommit(hash: hash)
        } catch {
            handleError(error)
            return Diff()
        }
    }

    // MARK: - Stash Operations

    func createStash(message: String?, includeUntracked: Bool = false) async {
        do {
            _ = try await gitService.createStash(message: message, includeUntracked: includeUntracked)
            await loadStashes()
            await loadFileStatuses()
        } catch {
            handleError(error)
        }
    }

    func applyStash(_ stash: Stash, pop: Bool = false) async {
        do {
            try await gitService.applyStash(index: stash.index, pop: pop)
            await loadStashes()
            await loadFileStatuses()
        } catch {
            handleError(error)
        }
    }

    func dropStash(_ stash: Stash) async {
        do {
            try await gitService.dropStash(index: stash.index)
            await loadStashes()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Tag Operations

    func createTag(name: String, message: String?, commit: String?) async {
        do {
            _ = try await gitService.createTag(name: name, message: message, commit: commit)
            await loadTags()
        } catch {
            handleError(error)
        }
    }

    func deleteTag(_ tag: Tag) async {
        do {
            try await gitService.deleteTag(name: tag.name)
            await loadTags()
        } catch {
            handleError(error)
        }
    }

    func deleteTagFromRemote(_ tag: Tag, remote: String = "origin") async {
        do {
            // Delete from remote: git push origin --delete tag-name
            try await gitService.deleteRemoteTag(name: tag.name, remote: remote)
            await loadTags()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Advanced Operations

    // Reset

    func reset(to commit: String, mode: ResetMode) async throws -> ResetResult {
        let result = try await gitService.reset(to: commit, mode: mode)
        if result.success {
            await loadCommits()
            await loadFileStatuses()
            await loadBranches()
        }
        return result
    }

    // Cherry-Pick

    func cherryPick(commit: String) async throws -> CherryPickResult {
        let result = try await gitService.cherryPick(commit: commit)
        if result.success {
            await loadCommits()
            await loadFileStatuses()
        } else if result.hasConflicts {
            await loadFileStatuses()
        }
        return result
    }

    func cherryPickContinue() async throws -> CherryPickResult {
        let result = try await gitService.cherryPickContinue()
        if result.success {
            await loadCommits()
        }
        await loadFileStatuses()
        return result
    }

    func cherryPickAbort() async throws {
        try await gitService.cherryPickAbort()
        await loadFileStatuses()
        await loadCommits()
    }

    // Revert

    func revert(commit: String) async throws -> RevertResult {
        let result = try await gitService.revert(commit: commit)
        if result.success {
            await loadCommits()
            await loadFileStatuses()
        } else if result.hasConflicts {
            await loadFileStatuses()
        }
        return result
    }

    func revertContinue() async throws -> RevertResult {
        let result = try await gitService.revertContinue()
        if result.success {
            await loadCommits()
        }
        await loadFileStatuses()
        return result
    }

    func revertAbort() async throws {
        try await gitService.revertAbort()
        await loadFileStatuses()
        await loadCommits()
    }

    // Blame

    func blame(file: String) async throws -> BlameInfo {
        try await gitService.blame(file: file)
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let gitError = error as? GitError {
            errorMessage = gitError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        logger.error("RepositoryViewModel error: \(errorMessage ?? "Unknown")", category: .git)
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Computed Properties

    var stagedFiles: [FileStatus] {
        fileStatuses.filter { $0.isStaged }
    }

    var unstagedFiles: [FileStatus] {
        fileStatuses.filter { !$0.isStaged }
    }

    var hasChanges: Bool {
        !fileStatuses.isEmpty
    }

    var localBranches: [Branch] {
        branches.filter { $0.isLocal }
    }

    var remoteBranches: [Branch] {
        branches.filter { $0.isRemote }
    }

    var currentBranch: Branch? {
        branches.first { $0.isCurrent }
    }

    var lastCommit: Commit? {
        commits.first
    }

    var filteredUnstagedFiles: [FileStatus] {
        var filtered = unstagedFiles

        // Apply file filter
        switch fileFilter {
        case .all:
            break
        case .modified:
            filtered = filtered.filter { $0.status == .modified }
        case .added:
            filtered = filtered.filter { $0.status == .added }
        case .deleted:
            filtered = filtered.filter { $0.status == .deleted }
        case .untracked:
            filtered = filtered.filter { $0.status == .untracked }
        }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { file in
                file.path.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    var filteredStagedFiles: [FileStatus] {
        if searchText.isEmpty {
            return stagedFiles
        }
        return stagedFiles.filter { file in
            file.path.localizedCaseInsensitiveContains(searchText)
        }
    }
}
