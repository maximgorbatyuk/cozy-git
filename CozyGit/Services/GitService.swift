//
//  GitService.swift
//  CozyGit
//

import Foundation

@MainActor
final class GitService: GitServiceProtocol {
    private let shellExecutor: ShellExecutor
    private let logger = Logger.shared

    private(set) var currentRepository: Repository?

    init(shellExecutor: ShellExecutor) {
        self.shellExecutor = shellExecutor
    }

    // MARK: - Repository Operations

    func openRepository(at path: URL) async throws -> Repository {
        guard await isGitRepository(at: path) else {
            throw GitError.notARepository
        }

        let branch = try await getCurrentBranch()
        let remotes = try await listRemotes()

        let repository = Repository(
            path: path,
            currentBranch: branch,
            remotes: remotes
        )

        currentRepository = repository
        logger.info("Opened repository at \(path.path)", category: .git)
        return repository
    }

    func initRepository(at path: URL, bare: Bool = false) async throws -> Repository {
        var args = ["init"]
        if bare {
            args.append("--bare")
        }
        args.append(path.path)

        let result = await shellExecutor.executeGit(arguments: args)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to initialize repository")
        }

        return try await openRepository(at: path)
    }

    func cloneRepository(from url: URL, to path: URL) async throws -> Repository {
        let args = ["clone", url.absoluteString, path.path]
        let result = await shellExecutor.executeGit(arguments: args, timeout: 300)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to clone repository")
        }

        return try await openRepository(at: path)
    }

    func getStatus() async throws -> [FileStatus] {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["status", "--porcelain=v1"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to get status")
        }

        return parseStatusOutput(result.output)
    }

    func isGitRepository(at path: URL) async -> Bool {
        let result = await shellExecutor.executeGit(
            arguments: ["rev-parse", "--git-dir"],
            workingDirectory: path
        )
        return result.success
    }

    func getAheadBehindCount() async throws -> RemoteTrackingStatus? {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        // Check if branch has an upstream configured
        let upstreamCheck = await shellExecutor.executeGit(
            arguments: ["rev-parse", "--abbrev-ref", "@{upstream}"],
            workingDirectory: repo.path
        )

        guard upstreamCheck.success else {
            // No upstream configured
            return nil
        }

        let result = await shellExecutor.executeGit(
            arguments: ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"],
            workingDirectory: repo.path
        )

        guard result.success else {
            return nil
        }

        let parts = result.output.split(separator: "\t").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 2,
              let behind = parts[0],
              let ahead = parts[1] else {
            return nil
        }

        return RemoteTrackingStatus(ahead: ahead, behind: behind)
    }

    // MARK: - Branch Operations

    func listBranches() async throws -> [Branch] {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["branch", "-a", "--format=%(refname:short)|%(objectname:short)|%(upstream:short)|%(HEAD)"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to list branches")
        }

        return parseBranchOutput(result.output)
    }

    func createBranch(name: String, from: String? = nil) async throws -> Branch {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["branch", name]
        if let from = from {
            args.append(from)
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to create branch")
        }

        return Branch(name: name)
    }

    func checkoutBranch(name: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["checkout", name],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to checkout branch")
        }

        currentRepository?.currentBranch = name
    }

    func deleteBranch(name: String, force: Bool = false) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let flag = force ? "-D" : "-d"
        let result = await shellExecutor.executeGit(
            arguments: ["branch", flag, name],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to delete branch")
        }
    }

    func renameBranch(oldName: String, newName: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["branch", "-m", oldName, newName],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to rename branch")
        }
    }

    func getCurrentBranch() async throws -> String? {
        guard let repo = currentRepository else {
            // Allow calling without open repo for initial setup
            return nil
        }

        let result = await shellExecutor.executeGit(
            arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            workingDirectory: repo.path
        )

        return result.success ? result.output : nil
    }

    func getMergedBranches(into baseBranch: String) async throws -> [Branch] {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["branch", "--merged", baseBranch],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to get merged branches")
        }

        return result.output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
            .map { Branch(name: $0, isMerged: true) }
    }

    // MARK: - Commit Operations

    func getHistory(limit: Int = 50, branch: String? = nil) async throws -> [Commit] {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = [
            "log",
            "--format=%H|%h|%s|%an|%ae|%aI|%cn|%ce|%cI|%P|%D",
            "-n", "\(limit)"
        ]

        if let branch = branch {
            args.append(branch)
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to get history")
        }

        return parseCommitOutput(result.output)
    }

    func commit(message: String, amend: Bool = false) async throws -> Commit {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["commit", "-m", message]
        if amend {
            args.append("--amend")
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to commit")
        }

        let history = try await getHistory(limit: 1)
        guard let commit = history.first else {
            throw GitError.parseError("Could not retrieve committed commit")
        }

        return commit
    }

    func getCommit(hash: String) async throws -> Commit {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["show", "--format=%H|%h|%s|%an|%ae|%aI|%cn|%ce|%cI|%P|%D", "-s", hash],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commitNotFound(hash)
        }

        let commits = parseCommitOutput(result.output)
        guard let commit = commits.first else {
            throw GitError.commitNotFound(hash)
        }

        return commit
    }

    func stageFile(path: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["add", path],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to stage file")
        }
    }

    func unstageFile(path: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["reset", "HEAD", path],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to unstage file")
        }
    }

    func stageAllFiles() async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["add", "-A"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to stage all files")
        }
    }

    func discardChanges(path: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["checkout", "--", path],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to discard changes")
        }
    }

    // MARK: - Remote Operations

    func listRemotes() async throws -> [Remote] {
        guard let repo = currentRepository else {
            return []
        }

        let result = await shellExecutor.executeGit(
            arguments: ["remote", "-v"],
            workingDirectory: repo.path
        )

        guard result.success else {
            return []
        }

        return parseRemoteOutput(result.output)
    }

    func addRemote(name: String, url: URL) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["remote", "add", name, url.absoluteString],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to add remote")
        }
    }

    func removeRemote(name: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["remote", "remove", name],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to remove remote")
        }
    }

    func fetch(remote: String? = nil, prune: Bool = false) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["fetch"]
        if let remote = remote {
            args.append(remote)
        } else {
            args.append("--all")
        }
        if prune {
            args.append("--prune")
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path, timeout: 120)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to fetch")
        }
    }

    func pull(remote: String? = nil, branch: String? = nil) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["pull"]
        if let remote = remote {
            args.append(remote)
            if let branch = branch {
                args.append(branch)
            }
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path, timeout: 120)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to pull")
        }
    }

    func push(remote: String? = nil, branch: String? = nil, force: Bool = false) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["push"]
        if force {
            args.append("--force-with-lease")
        }
        if let remote = remote {
            args.append(remote)
            if let branch = branch {
                args.append(branch)
            }
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path, timeout: 120)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to push")
        }
    }

    // MARK: - Stash Operations

    func listStashes() async throws -> [Stash] {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["stash", "list", "--format=%gd|%gs|%aI"],
            workingDirectory: repo.path
        )

        guard result.success else {
            return []
        }

        return parseStashOutput(result.output)
    }

    func createStash(message: String? = nil, includeUntracked: Bool = false) async throws -> Stash {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["stash", "push"]
        if includeUntracked {
            args.append("-u")
        }
        if let message = message {
            args.append("-m")
            args.append(message)
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to create stash")
        }

        let stashes = try await listStashes()
        return stashes.first ?? Stash(index: 0, message: message ?? "Stash")
    }

    func applyStash(index: Int, pop: Bool = false) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let command = pop ? "pop" : "apply"
        let result = await shellExecutor.executeGit(
            arguments: ["stash", command, "stash@{\(index)}"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to apply stash")
        }
    }

    func dropStash(index: Int) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["stash", "drop", "stash@{\(index)}"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to drop stash")
        }
    }

    // MARK: - Tag Operations

    func listTags() async throws -> [Tag] {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["tag", "-l", "--format=%(refname:short)|%(objectname:short)"],
            workingDirectory: repo.path
        )

        guard result.success else {
            return []
        }

        return parseTagOutput(result.output)
    }

    func createTag(name: String, message: String? = nil, commit: String? = nil) async throws -> Tag {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["tag"]
        if let message = message {
            args.append("-a")
            args.append(name)
            args.append("-m")
            args.append(message)
        } else {
            args.append(name)
        }

        if let commit = commit {
            args.append(commit)
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to create tag")
        }

        return Tag(name: name, commitHash: commit ?? "HEAD", message: message, isAnnotated: message != nil)
    }

    func deleteTag(name: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["tag", "-d", name],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to delete tag")
        }
    }

    // MARK: - Private Parsing Methods

    private func parseStatusOutput(_ output: String) -> [FileStatus] {
        guard !output.isEmpty else { return [] }

        return output.components(separatedBy: .newlines).compactMap { line -> FileStatus? in
            guard line.count >= 3 else { return nil }

            let index = line.index(line.startIndex, offsetBy: 2)
            let statusChars = String(line[..<index])
            let path = String(line[line.index(after: index)...]).trimmingCharacters(in: .whitespaces)

            let indexStatus = statusChars.first ?? " "
            let workTreeStatus = statusChars.last ?? " "

            let status: FileChangeType
            let isStaged: Bool

            if indexStatus == "?" {
                status = .untracked
                isStaged = false
            } else if indexStatus != " " {
                status = FileChangeType(rawValue: String(indexStatus)) ?? .modified
                isStaged = true
            } else {
                status = FileChangeType(rawValue: String(workTreeStatus)) ?? .modified
                isStaged = false
            }

            return FileStatus(
                path: path,
                status: status,
                isStaged: isStaged,
                isConflicted: statusChars.contains("U")
            )
        }
    }

    private func parseBranchOutput(_ output: String) -> [Branch] {
        guard !output.isEmpty else { return [] }

        return output.components(separatedBy: .newlines).compactMap { line -> Branch? in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 4 else { return nil }

            let name = parts[0]
            let upstream = parts[2].isEmpty ? nil : parts[2]
            let isCurrent = parts[3] == "*"
            let isRemote = name.hasPrefix("remotes/") || name.contains("/")

            return Branch(
                name: name,
                isLocal: !isRemote,
                isRemote: isRemote,
                isCurrent: isCurrent,
                upstream: upstream
            )
        }
    }

    private func parseCommitOutput(_ output: String) -> [Commit] {
        guard !output.isEmpty else { return [] }

        let dateFormatter = ISO8601DateFormatter()

        return output.components(separatedBy: .newlines).compactMap { line -> Commit? in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 10 else { return nil }

            let hash = parts[0]
            let shortHash = parts[1]
            let message = parts[2]
            let author = parts[3]
            let authorEmail = parts[4]
            let dateStr = parts[5]
            let committer = parts[6]
            let committerEmail = parts[7]
            let committerDateStr = parts[8]
            let parents = parts[9].split(separator: " ").map(String.init)
            let refs = parts.count > 10 ? parts[10].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } : []

            guard let date = dateFormatter.date(from: dateStr) else { return nil }
            let committerDate = dateFormatter.date(from: committerDateStr) ?? date

            return Commit(
                hash: hash,
                shortHash: shortHash,
                message: message,
                author: author,
                authorEmail: authorEmail,
                date: date,
                committer: committer,
                committerEmail: committerEmail,
                committerDate: committerDate,
                parents: parents,
                refs: refs
            )
        }
    }

    private func parseRemoteOutput(_ output: String) -> [Remote] {
        guard !output.isEmpty else { return [] }

        var remotes: [String: (fetch: URL?, push: URL?)] = [:]

        for line in output.components(separatedBy: .newlines) {
            let parts = line.split(separator: "\t").map(String.init)
            guard parts.count >= 2 else { continue }

            let name = parts[0]
            let urlAndType = parts[1].split(separator: " ").map(String.init)
            guard let urlString = urlAndType.first,
                  let url = URL(string: urlString) else { continue }

            let isFetch = urlAndType.last == "(fetch)"

            var existing = remotes[name] ?? (nil, nil)
            if isFetch {
                existing.fetch = url
            } else {
                existing.push = url
            }
            remotes[name] = existing
        }

        return remotes.map { Remote(name: $0.key, fetchURL: $0.value.fetch, pushURL: $0.value.push) }
    }

    private func parseStashOutput(_ output: String) -> [Stash] {
        guard !output.isEmpty else { return [] }

        let dateFormatter = ISO8601DateFormatter()

        return output.components(separatedBy: .newlines).enumerated().compactMap { (index, line) -> Stash? in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3 else { return nil }

            let message = parts[1]
            let dateStr = parts[2]
            let date = dateFormatter.date(from: dateStr) ?? Date()

            return Stash(index: index, message: message, date: date)
        }
    }

    private func parseTagOutput(_ output: String) -> [Tag] {
        guard !output.isEmpty else { return [] }

        return output.components(separatedBy: .newlines).compactMap { line -> Tag? in
            let parts = line.split(separator: "|").map(String.init)
            guard parts.count >= 2 else { return nil }

            return Tag(name: parts[0], commitHash: parts[1])
        }
    }
}
