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

    func getStaleBranches(olderThanDays: Int = 90) async throws -> [Branch] {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        // Get branch info with last commit date
        let result = await shellExecutor.executeGit(
            arguments: [
                "for-each-ref",
                "--sort=-committerdate",
                "--format=%(refname:short)|%(committerdate:iso8601)|%(objectname:short)",
                "refs/heads/"
            ],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to get branch dates")
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var staleBranches: [Branch] = []

        for line in result.output.components(separatedBy: .newlines) {
            let parts = line.split(separator: "|", maxSplits: 2)
            guard parts.count >= 2 else { continue }

            let branchName = String(parts[0])
            let dateString = String(parts[1]).trimmingCharacters(in: .whitespaces)

            // Parse date (format: 2024-01-15 10:30:45 +0000)
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withFullDate, .withTime, .withSpaceBetweenDateAndTime, .withTimeZone]

            // Try multiple date formats
            var branchDate: Date?
            if let date = isoFormatter.date(from: dateString.replacingOccurrences(of: " ", with: "T")) {
                branchDate = date
            } else {
                // Fallback: parse manually
                let components = dateString.split(separator: " ")
                if components.count >= 2 {
                    let simpleDateString = "\(components[0])T\(components[1])Z"
                    branchDate = isoFormatter.date(from: simpleDateString)
                }
            }

            if let date = branchDate, date < cutoffDate {
                var branch = Branch(name: branchName, isLocal: true)
                branch = Branch(
                    name: branchName,
                    isLocal: true,
                    isRemote: false,
                    isCurrent: false,
                    lastCommit: nil,
                    isMerged: false,
                    isProtected: false,
                    commitCount: 0,
                    upstream: nil
                )
                staleBranches.append(branch)
            }
        }

        return staleBranches
    }

    func deleteRemoteBranch(name: String, remote: String = "origin") async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["push", remote, "--delete", name],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to delete remote branch")
        }

        logger.info("Deleted remote branch: \(remote)/\(name)", category: .git)
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
        _ = try await fetchWithResult(remote: remote, prune: prune)
    }

    func fetchWithResult(remote: String? = nil, prune: Bool = false) async throws -> FetchResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["fetch", "--verbose"]
        if let remote = remote {
            args.append(remote)
        } else {
            args.append("--all")
        }
        if prune {
            args.append("--prune")
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path, timeout: 120)

        if !result.success {
            return FetchResult(
                success: false,
                errorMessage: result.error ?? "Failed to fetch",
                rawOutput: result.output
            )
        }

        // Parse fetch output for updated branches
        let output = result.output + (result.error ?? "") // git fetch outputs to stderr
        let updatedBranches = parseFetchOutput(output)

        return FetchResult(
            newCommits: 0, // Would need additional parsing
            updatedBranches: updatedBranches,
            success: true,
            rawOutput: output
        )
    }

    func pull(remote: String? = nil, branch: String? = nil) async throws {
        _ = try await pullWithStrategy(remote: remote, branch: branch, strategy: .merge)
    }

    func pullWithStrategy(remote: String? = nil, branch: String? = nil, strategy: PullStrategy = .merge) async throws -> PullResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["pull"]

        // Add strategy flag
        if let flag = strategy.gitFlag {
            args.append(flag)
        }

        if let remote = remote {
            args.append(remote)
            if let branch = branch {
                args.append(branch)
            }
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path, timeout: 120)

        let output = result.output
        let errorOutput = result.error ?? ""
        let combinedOutput = output + errorOutput

        // Check for conflicts
        let hasConflicts = combinedOutput.contains("CONFLICT") ||
                          combinedOutput.contains("Automatic merge failed") ||
                          combinedOutput.contains("error: could not apply")

        let conflictingFiles = parseConflictingFiles(combinedOutput)

        // Parse statistics
        let stats = parsePullStats(combinedOutput)

        // Check for fast-forward
        let wasFastForward = combinedOutput.contains("Fast-forward")

        // Check for merge commit
        let mergeCommitCreated = combinedOutput.contains("Merge made by")

        if !result.success && !hasConflicts {
            return PullResult(
                success: false,
                hasConflicts: false,
                errorMessage: errorOutput.isEmpty ? "Failed to pull" : errorOutput,
                rawOutput: combinedOutput,
                strategy: strategy
            )
        }

        return PullResult(
            success: result.success || hasConflicts,
            filesChanged: stats.filesChanged,
            insertions: stats.insertions,
            deletions: stats.deletions,
            hasConflicts: hasConflicts,
            conflictingFiles: conflictingFiles,
            mergeCommitCreated: mergeCommitCreated,
            wasFastForward: wasFastForward,
            rawOutput: combinedOutput,
            strategy: strategy
        )
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

    func setUpstream(remote: String = "origin", branch: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["branch", "--set-upstream-to=\(remote)/\(branch)", branch],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to set upstream")
        }
    }

    // MARK: - Fetch/Pull Output Parsing

    private func parseFetchOutput(_ output: String) -> [String] {
        var updatedBranches: [String] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // Look for lines like "   abc123..def456  main       -> origin/main"
            if line.contains("->") && (line.contains("..") || line.contains("[new branch]") || line.contains("[new tag]")) {
                let parts = line.components(separatedBy: "->")
                if parts.count >= 2 {
                    let branch = parts[1].trimmingCharacters(in: .whitespaces)
                    updatedBranches.append(branch)
                }
            }
        }

        return updatedBranches
    }

    private func parseConflictingFiles(_ output: String) -> [String] {
        var files: [String] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // Look for "CONFLICT (content): Merge conflict in <file>"
            if line.contains("CONFLICT") && line.contains("Merge conflict in") {
                if let range = line.range(of: "Merge conflict in ") {
                    let file = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    files.append(file)
                }
            }
            // Also look for "U<tab>filename" in status-like output
            if line.hasPrefix("U\t") || line.hasPrefix("UU ") {
                let file = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                files.append(file)
            }
        }

        return files
    }

    private func parsePullStats(_ output: String) -> (filesChanged: Int, insertions: Int, deletions: Int) {
        var filesChanged = 0
        var insertions = 0
        var deletions = 0

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // Look for "X files changed, Y insertions(+), Z deletions(-)"
            if line.contains("changed") && (line.contains("insertion") || line.contains("deletion")) {
                // Parse files changed
                if let filesMatch = line.range(of: #"(\d+) files? changed"#, options: .regularExpression) {
                    let match = line[filesMatch]
                    if let num = Int(match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                        filesChanged = num
                    }
                }

                // Parse insertions
                if let insertMatch = line.range(of: #"(\d+) insertions?"#, options: .regularExpression) {
                    let match = line[insertMatch]
                    if let num = Int(match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                        insertions = num
                    }
                }

                // Parse deletions
                if let deleteMatch = line.range(of: #"(\d+) deletions?"#, options: .regularExpression) {
                    let match = line[deleteMatch]
                    if let num = Int(match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                        deletions = num
                    }
                }
            }
        }

        return (filesChanged, insertions, deletions)
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
