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

        _ = await (branchesTask, commitsTask, statusTask, stashTask, tagsTask)

        isLoading = false
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

    func createBranch(name: String, from: String? = nil) async {
        do {
            _ = try await gitService.createBranch(name: name, from: from)
            await loadBranches()
        } catch {
            handleError(error)
        }
    }

    func checkoutBranch(_ branch: Branch) async {
        do {
            try await gitService.checkoutBranch(name: branch.name)
            await loadBranches()
        } catch {
            handleError(error)
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
        } catch {
            handleError(error)
        }
    }

    func pull() async {
        do {
            try await gitService.pull()
            await loadCommits()
            await loadFileStatuses()
        } catch {
            handleError(error)
        }
    }

    func push(force: Bool = false) async {
        do {
            try await gitService.push(force: force)
        } catch {
            handleError(error)
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
}
