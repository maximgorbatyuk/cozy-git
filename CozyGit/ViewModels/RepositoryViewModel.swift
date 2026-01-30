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
        async let remoteStatusTask = loadRemoteStatus()

        _ = await (branchesTask, commitsTask, statusTask, stashTask, tagsTask, remoteStatusTask)

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

    func setUpstream(remote: String, branch: String) async throws {
        try await gitService.setUpstream(remote: remote, branch: branch)
        await loadBranches()
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
