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

        var args = ["checkout", name]

        let result = await shellExecutor.executeGit(
            arguments: args,
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to checkout branch")
        }

        // Get the actual current branch name after checkout
        // This handles the case where checking out a remote branch creates a local tracking branch
        if let currentBranch = try? await getCurrentBranch() {
            currentRepository?.currentBranch = currentBranch
        }
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
            "--all",
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
        let options = PushOptions(
            remote: remote ?? "origin",
            branch: branch,
            force: force,
            forceWithLease: true
        )
        _ = try await pushWithOptions(options)
    }

    func pushWithOptions(_ options: PushOptions) async throws -> PushResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["push", "--verbose"]

        // Force push options
        if options.force {
            if options.forceWithLease {
                args.append("--force-with-lease")
            } else {
                args.append("--force")
            }
        }

        // Set upstream
        if options.setUpstream {
            args.append("--set-upstream")
        }

        // Remote and branch
        args.append(options.remote)
        if let branch = options.branch {
            args.append(branch)
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path, timeout: 120)

        let output = result.output
        let errorOutput = result.error ?? ""
        let combinedOutput = output + errorOutput

        // Parse the result
        let pushResult = parsePushOutput(
            combinedOutput,
            success: result.success,
            wasForcePush: options.force
        )

        // Push tags if requested
        if options.pushTags && result.success {
            let tagResult = try await pushTags(remote: options.remote, tags: options.tags.isEmpty ? nil : options.tags)
            return PushResult(
                success: pushResult.success,
                commitsPushed: pushResult.commitsPushed,
                remoteBranch: pushResult.remoteBranch,
                createdRemoteBranch: pushResult.createdRemoteBranch,
                wasForcePush: pushResult.wasForcePush,
                tagsPushed: tagResult.tagsPushed,
                errorMessage: pushResult.errorMessage,
                rawOutput: pushResult.rawOutput + "\n" + tagResult.rawOutput,
                wasRejected: pushResult.wasRejected,
                authenticationFailed: pushResult.authenticationFailed
            )
        }

        return pushResult
    }

    func pushTags(remote: String? = nil, tags: [String]? = nil) async throws -> PushResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let remoteName = remote ?? "origin"
        var args = ["push", remoteName]

        if let specificTags = tags, !specificTags.isEmpty {
            // Push specific tags
            for tag in specificTags {
                args.append("refs/tags/\(tag)")
            }
        } else {
            // Push all tags
            args.append("--tags")
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path, timeout: 120)

        let combinedOutput = result.output + (result.error ?? "")

        // Count pushed tags
        let tagsPushed = countPushedTags(combinedOutput)

        if !result.success {
            return PushResult(
                success: false,
                tagsPushed: 0,
                errorMessage: result.error ?? "Failed to push tags",
                rawOutput: combinedOutput
            )
        }

        return PushResult(
            success: true,
            tagsPushed: tagsPushed,
            rawOutput: combinedOutput
        )
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

    // MARK: - Push Output Parsing

    private func parsePushOutput(_ output: String, success: Bool, wasForcePush: Bool) -> PushResult {
        // Check for rejection
        let wasRejected = output.contains("[rejected]") ||
                          output.contains("non-fast-forward") ||
                          output.contains("fetch first") ||
                          output.contains("Updates were rejected")

        // Check for authentication failure
        let authFailed = output.contains("Authentication failed") ||
                         output.contains("Permission denied") ||
                         output.contains("could not read Username") ||
                         output.contains("fatal: unable to access")

        // Check if new branch was created
        let createdRemoteBranch = output.contains("[new branch]") ||
                                  output.contains("* [new branch]")

        // Parse commits pushed - look for "abc123..def456" pattern
        var commitsPushed = 0
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            // Look for lines like "   abc123..def456  main -> main"
            if line.contains("..") && line.contains("->") {
                // Try to count commits
                commitsPushed += 1
            }
        }

        // Parse remote branch name
        var remoteBranch: String?
        for line in lines {
            if line.contains("->") {
                let parts = line.components(separatedBy: "->")
                if parts.count >= 2 {
                    remoteBranch = parts[1].trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }

        // Extract error message if failed
        var errorMessage: String?
        if !success {
            for line in lines {
                if line.contains("error:") || line.contains("fatal:") {
                    errorMessage = line.trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            if errorMessage == nil && wasRejected {
                errorMessage = "Push rejected - remote contains changes you don't have locally"
            }
            if errorMessage == nil && authFailed {
                errorMessage = "Authentication failed"
            }
        }

        return PushResult(
            success: success && !wasRejected && !authFailed,
            commitsPushed: commitsPushed,
            remoteBranch: remoteBranch,
            createdRemoteBranch: createdRemoteBranch,
            wasForcePush: wasForcePush,
            tagsPushed: 0,
            errorMessage: errorMessage,
            rawOutput: output,
            wasRejected: wasRejected,
            authenticationFailed: authFailed
        )
    }

    private func countPushedTags(_ output: String) -> Int {
        var count = 0
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // Look for lines indicating tag push like "* [new tag]" or "refs/tags/"
            if line.contains("[new tag]") ||
               (line.contains("->") && line.contains("refs/tags/")) ||
               (line.contains("->") && !line.contains("refs/heads/") && line.trimmingCharacters(in: .whitespaces).first != " ") {
                // Check if this is actually a tag (not a branch)
                if line.contains("[new tag]") {
                    count += 1
                }
            }
        }

        // If no explicit tag markers, check for "Everything up-to-date" (0 tags)
        // or try to count from verbose output
        if count == 0 && !output.contains("Everything up-to-date") {
            // Count occurrences of tag references
            let tagMatches = output.components(separatedBy: "refs/tags/").count - 1
            count = max(0, tagMatches)
        }

        return count
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

    func getStashDiff(index: Int) async throws -> Diff {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        // Get the diff for the stash
        let result = await shellExecutor.executeGit(
            arguments: ["stash", "show", "-p", "--stat", "stash@{\(index)}"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to get stash diff")
        }

        return parseDiffOutput(result.output)
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

    func deleteRemoteTag(name: String, remote: String = "origin") async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["push", remote, "--delete", "refs/tags/\(name)"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to delete remote tag")
        }
    }

    // MARK: - Private Parsing Methods

    private func parseStatusOutput(_ output: String) -> [FileStatus] {
        guard !output.isEmpty else { return [] }

        var results: [FileStatus] = []

        for line in output.components(separatedBy: .newlines) {
            guard line.count >= 3 else { continue }

            let index = line.index(line.startIndex, offsetBy: 2)
            let statusChars = String(line[..<index])
            let path = String(line[line.index(after: index)...]).trimmingCharacters(in: .whitespaces)

            guard !path.isEmpty else { continue }

            let indexStatus = statusChars.first ?? " "
            let workTreeStatus = statusChars.last ?? " "
            let isConflicted = statusChars.contains("U")

            // Handle untracked files
            if indexStatus == "?" {
                results.append(FileStatus(
                    path: path,
                    status: .untracked,
                    isStaged: false,
                    isConflicted: false
                ))
                continue
            }

            // Create staged entry if there are staged changes
            if indexStatus != " " {
                let stagedStatus = FileChangeType(rawValue: String(indexStatus)) ?? .modified
                results.append(FileStatus(
                    path: path,
                    status: stagedStatus,
                    isStaged: true,
                    isConflicted: isConflicted
                ))
            }

            // Create unstaged entry if there are unstaged changes
            if workTreeStatus != " " {
                let unstagedStatus = FileChangeType(rawValue: String(workTreeStatus)) ?? .modified
                results.append(FileStatus(
                    path: path,
                    status: unstagedStatus,
                    isStaged: false,
                    isConflicted: isConflicted
                ))
            }
        }

        return results
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

    // MARK: - Merge Operations

    func mergeBranch(_ branch: String, strategy: MergeStrategy = .merge, message: String? = nil) async throws -> MergeResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["merge"]

        // Add strategy flag
        if let flag = strategy.gitFlag {
            args.append(flag)
        }

        // Add custom message for non-fast-forward merges
        if let message = message, strategy != .fastForwardOnly {
            args.append("-m")
            args.append(message)
        }

        args.append(branch)

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path, timeout: 120)

        let output = result.output
        let errorOutput = result.error ?? ""
        let combinedOutput = output + errorOutput

        // Check for conflicts
        let hasConflicts = combinedOutput.contains("CONFLICT") ||
                          combinedOutput.contains("Automatic merge failed") ||
                          combinedOutput.contains("fix conflicts")

        let conflictingFiles = parseConflictingFiles(combinedOutput)

        // Parse statistics
        let stats = parsePullStats(combinedOutput)

        // Check merge type
        let wasFastForward = combinedOutput.contains("Fast-forward")
        let mergeCommitCreated = combinedOutput.contains("Merge made by")

        // Check for already up to date
        let alreadyUpToDate = combinedOutput.contains("Already up to date")

        if !result.success && !hasConflicts {
            return MergeResult(
                success: false,
                sourceBranch: branch,
                errorMessage: errorOutput.isEmpty ? "Merge failed" : errorOutput,
                rawOutput: combinedOutput,
                strategy: strategy
            )
        }

        return MergeResult(
            success: result.success || hasConflicts,
            wasFastForward: wasFastForward,
            mergeCommitCreated: mergeCommitCreated,
            wasSquash: strategy == .squash,
            commitsMerged: alreadyUpToDate ? 0 : 1,
            filesChanged: stats.filesChanged,
            insertions: stats.insertions,
            deletions: stats.deletions,
            hasConflicts: hasConflicts,
            conflictingFiles: conflictingFiles,
            sourceBranch: branch,
            rawOutput: combinedOutput,
            strategy: strategy
        )
    }

    func abortMerge() async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["merge", "--abort"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to abort merge")
        }

        logger.info("Merge aborted", category: .git)
    }

    func continueMerge() async throws -> MergeResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["merge", "--continue"],
            workingDirectory: repo.path
        )

        let combinedOutput = result.output + (result.error ?? "")

        if !result.success {
            // Check if there are still conflicts
            let hasConflicts = combinedOutput.contains("CONFLICT") ||
                              combinedOutput.contains("fix conflicts")

            return MergeResult(
                success: false,
                hasConflicts: hasConflicts,
                conflictingFiles: hasConflicts ? try await getConflictedFiles().map { $0.path } : [],
                errorMessage: result.error ?? "Failed to continue merge",
                rawOutput: combinedOutput
            )
        }

        return MergeResult(
            success: true,
            mergeCommitCreated: true,
            rawOutput: combinedOutput
        )
    }

    // MARK: - Rebase Operations

    func rebase(onto branch: String) async throws -> RebaseResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["rebase", branch],
            workingDirectory: repo.path,
            timeout: 120
        )

        let output = result.output
        let errorOutput = result.error ?? ""
        let combinedOutput = output + errorOutput

        // Check for conflicts
        let hasConflicts = combinedOutput.contains("CONFLICT") ||
                          combinedOutput.contains("error: could not apply") ||
                          combinedOutput.contains("fix conflicts")

        let conflictingFiles = parseConflictingFiles(combinedOutput)

        // Check if rebase is in progress
        let isInProgress = hasConflicts ||
                          combinedOutput.contains("rebase in progress") ||
                          combinedOutput.contains("git rebase --continue")

        // Parse progress
        let (current, total) = parseRebaseProgress(combinedOutput)

        if !result.success && !hasConflicts {
            return RebaseResult(
                success: false,
                hasConflicts: false,
                isInProgress: false,
                targetBranch: branch,
                errorMessage: errorOutput.isEmpty ? "Rebase failed" : errorOutput,
                rawOutput: combinedOutput
            )
        }

        return RebaseResult(
            success: result.success && !hasConflicts,
            commitsRebased: total,
            currentCommit: current,
            totalCommits: total,
            hasConflicts: hasConflicts,
            conflictingFiles: conflictingFiles,
            isInProgress: isInProgress,
            targetBranch: branch,
            rawOutput: combinedOutput
        )
    }

    func continueRebase() async throws -> RebaseResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["rebase", "--continue"],
            workingDirectory: repo.path,
            timeout: 120
        )

        let combinedOutput = result.output + (result.error ?? "")

        // Check for more conflicts
        let hasConflicts = combinedOutput.contains("CONFLICT") ||
                          combinedOutput.contains("fix conflicts")

        let isInProgress = hasConflicts ||
                          combinedOutput.contains("rebase in progress")

        if !result.success {
            return RebaseResult(
                success: false,
                hasConflicts: hasConflicts,
                conflictingFiles: hasConflicts ? try await getConflictedFiles().map { $0.path } : [],
                isInProgress: isInProgress,
                errorMessage: result.error ?? "Failed to continue rebase",
                rawOutput: combinedOutput
            )
        }

        return RebaseResult(
            success: true,
            isInProgress: false,
            rawOutput: combinedOutput
        )
    }

    func abortRebase() async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["rebase", "--abort"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to abort rebase")
        }

        logger.info("Rebase aborted", category: .git)
    }

    func skipRebaseCommit() async throws -> RebaseResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["rebase", "--skip"],
            workingDirectory: repo.path,
            timeout: 120
        )

        let combinedOutput = result.output + (result.error ?? "")

        let hasConflicts = combinedOutput.contains("CONFLICT")
        let isInProgress = combinedOutput.contains("rebase in progress")

        return RebaseResult(
            success: result.success && !hasConflicts,
            hasConflicts: hasConflicts,
            isInProgress: isInProgress,
            rawOutput: combinedOutput
        )
    }

    // MARK: - Operation State

    func getOperationState() async throws -> OperationState {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let gitDir = repo.path.appendingPathComponent(".git")

        // Check for merge in progress
        let mergeHeadPath = gitDir.appendingPathComponent("MERGE_HEAD")
        if FileManager.default.fileExists(atPath: mergeHeadPath.path) {
            let conflicts = try await getConflictedFiles()
            return .mergeInProgress(conflictCount: conflicts.count)
        }

        // Check for rebase in progress
        let rebaseApplyPath = gitDir.appendingPathComponent("rebase-apply")
        let rebaseMergePath = gitDir.appendingPathComponent("rebase-merge")

        if FileManager.default.fileExists(atPath: rebaseApplyPath.path) ||
           FileManager.default.fileExists(atPath: rebaseMergePath.path) {
            // Try to get progress
            let (current, total) = try await getRebaseProgress(repo: repo)
            return .rebaseInProgress(current: current, total: total)
        }

        // Check for cherry-pick in progress
        let cherryPickHeadPath = gitDir.appendingPathComponent("CHERRY_PICK_HEAD")
        if FileManager.default.fileExists(atPath: cherryPickHeadPath.path) {
            return .cherryPickInProgress
        }

        return .none
    }

    func getConflictedFiles() async throws -> [ConflictedFile] {
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

        var conflicts: [ConflictedFile] = []

        for line in result.output.components(separatedBy: .newlines) {
            guard line.count >= 3 else { continue }

            let statusChars = String(line.prefix(2))
            let path = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)

            // Conflict markers: UU, AA, DD, AU, UA, DU, UD
            let conflictType: ConflictedFile.ConflictType?

            switch statusChars {
            case "UU":
                conflictType = .content
            case "AA":
                conflictType = .addAdd
            case "DD":
                conflictType = .content
            case "AU", "UA":
                conflictType = .modifyDelete
            case "DU", "UD":
                conflictType = .deleteModify
            default:
                conflictType = nil
            }

            if let type = conflictType {
                conflicts.append(ConflictedFile(path: path, conflictType: type))
            }
        }

        return conflicts
    }

    // MARK: - Conflict Resolution

    func acceptCurrentChanges(for path: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["checkout", "--ours", path],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to accept current changes")
        }

        // Stage the resolved file
        try await stageFile(path: path)
    }

    func acceptIncomingChanges(for path: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["checkout", "--theirs", path],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to accept incoming changes")
        }

        // Stage the resolved file
        try await stageFile(path: path)
    }

    func markConflictResolved(for path: String) async throws {
        try await stageFile(path: path)
    }

    // MARK: - Private Rebase Helpers

    private func parseRebaseProgress(_ output: String) -> (current: Int, total: Int) {
        // Look for "Rebasing (X/Y)" pattern
        let pattern = #"Rebasing \((\d+)/(\d+)\)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)) {
            if let currentRange = Range(match.range(at: 1), in: output),
               let totalRange = Range(match.range(at: 2), in: output),
               let current = Int(output[currentRange]),
               let total = Int(output[totalRange]) {
                return (current, total)
            }
        }
        return (0, 0)
    }

    private func getRebaseProgress(repo: Repository) async throws -> (current: Int, total: Int) {
        let gitDir = repo.path.appendingPathComponent(".git")

        // Try rebase-merge first (most common)
        let rebaseMergePath = gitDir.appendingPathComponent("rebase-merge")
        if FileManager.default.fileExists(atPath: rebaseMergePath.path) {
            let msgNumPath = rebaseMergePath.appendingPathComponent("msgnum")
            let endPath = rebaseMergePath.appendingPathComponent("end")

            if let msgNumData = try? String(contentsOf: msgNumPath),
               let endData = try? String(contentsOf: endPath),
               let current = Int(msgNumData.trimmingCharacters(in: .whitespacesAndNewlines)),
               let total = Int(endData.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return (current, total)
            }
        }

        // Try rebase-apply (for am-style rebases)
        let rebaseApplyPath = gitDir.appendingPathComponent("rebase-apply")
        if FileManager.default.fileExists(atPath: rebaseApplyPath.path) {
            let nextPath = rebaseApplyPath.appendingPathComponent("next")
            let lastPath = rebaseApplyPath.appendingPathComponent("last")

            if let nextData = try? String(contentsOf: nextPath),
               let lastData = try? String(contentsOf: lastPath),
               let current = Int(nextData.trimmingCharacters(in: .whitespacesAndNewlines)),
               let total = Int(lastData.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return (current, total)
            }
        }

        return (0, 0)
    }

    // MARK: - Diff Operations

    func getDiff(options: DiffOptions = DiffOptions()) async throws -> Diff {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var args = ["diff"]

        // Staged vs unstaged
        if options.staged {
            args.append("--cached")
        }

        // Context lines
        args.append("-U\(options.contextLines)")

        // Rename detection
        if options.detectRenames {
            args.append("-M")
        }

        // Whitespace options
        if options.ignoreAllWhitespace {
            args.append("-w")
        } else if options.ignoreWhitespace {
            args.append("-b")
        }

        // Specific commit
        if let commit = options.commit {
            args.append(commit)
        }

        // Specific file
        if let filePath = options.filePath {
            args.append("--")
            args.append(filePath)
        }

        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to get diff")
        }

        return parseDiffOutput(result.output)
    }

    func getDiffForFile(path: String, staged: Bool = false) async throws -> FileDiff? {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        // First try the normal diff
        let options = DiffOptions(staged: staged, filePath: path)
        let diff = try await getDiff(options: options)

        // If we got a valid diff with content, return it
        if let fileDiff = diff.files.first {
            // Return if we have hunks, or if it's marked as binary, or if it has paths set
            if !fileDiff.hunks.isEmpty || fileDiff.isBinary || !fileDiff.newPath.isEmpty {
                return fileDiff
            }
        }

        // If no diff found, check if it's an untracked file
        // For untracked files, git diff returns nothing - we need to show the entire file as new
        let fullPath = repo.path.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: fullPath.path) {
            // Check if the file is untracked (not yet tracked by git)
            let statusResult = await shellExecutor.executeGit(
                arguments: ["status", "--porcelain", "--", path],
                workingDirectory: repo.path
            )

            let statusOutput = statusResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            let isUntracked = statusOutput.hasPrefix("??")
            let isNewlyAdded = statusOutput.hasPrefix("A ") || statusOutput.hasPrefix(" A")

            // For untracked files, or newly added files when viewing staged diff
            if isUntracked || (isNewlyAdded && staged) {
                // Read the file content and create a diff showing all lines as additions
                do {
                    let content = try String(contentsOf: fullPath, encoding: .utf8)
                    let lines = content.components(separatedBy: .newlines)

                    // Create diff lines (all additions)
                    var diffLines: [DiffLine] = []
                    for (index, line) in lines.enumerated() {
                        // Skip empty last line that results from trailing newline
                        if index == lines.count - 1 && line.isEmpty {
                            continue
                        }
                        diffLines.append(DiffLine(
                            type: .addition,
                            content: line,
                            oldLineNumber: nil,
                            newLineNumber: index + 1
                        ))
                    }

                    // Create a hunk with all the additions
                    let hunk = DiffHunk(
                        oldStart: 0,
                        oldCount: 0,
                        newStart: 1,
                        newCount: diffLines.count,
                        header: "@@ -0,0 +1,\(diffLines.count) @@",
                        lines: diffLines
                    )

                    return FileDiff(
                        oldPath: "/dev/null",
                        newPath: path,
                        hunks: [hunk],
                        isBinary: false,
                        isNewFile: true,
                        isDeletedFile: false
                    )
                } catch {
                    // If we can't read the file, it might be binary
                    return FileDiff(
                        oldPath: "/dev/null",
                        newPath: path,
                        hunks: [],
                        isBinary: true,
                        isNewFile: true,
                        isDeletedFile: false
                    )
                }
            }
        }

        // Return whatever we got from the original diff (might be nil if no changes)
        return diff.files.first
    }

    func getDiffForCommit(hash: String) async throws -> Diff {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let args = ["show", "--format=", "-p", hash]
        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to get commit diff")
        }

        return parseDiffOutput(result.output)
    }

    func getDiffBetweenCommits(from: String, to: String) async throws -> Diff {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let args = ["diff", from, to]
        let result = await shellExecutor.executeGit(arguments: args, workingDirectory: repo.path)

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to get diff between commits")
        }

        return parseDiffOutput(result.output)
    }

    // MARK: - Diff Parsing

    private func parseDiffOutput(_ output: String) -> Diff {
        guard !output.isEmpty else {
            return Diff(rawOutput: output)
        }

        var files: [FileDiff] = []
        let lines = output.components(separatedBy: "\n")
        var currentFileLines: [String] = []
        var inFileDiff = false

        for line in lines {
            if line.hasPrefix("diff --git") {
                // Start of a new file diff
                if inFileDiff && !currentFileLines.isEmpty {
                    if let fileDiff = parseFileDiff(currentFileLines) {
                        files.append(fileDiff)
                    }
                }
                currentFileLines = [line]
                inFileDiff = true
            } else if inFileDiff {
                currentFileLines.append(line)
            }
        }

        // Don't forget the last file
        if inFileDiff && !currentFileLines.isEmpty {
            if let fileDiff = parseFileDiff(currentFileLines) {
                files.append(fileDiff)
            }
        }

        return Diff(files: files, rawOutput: output)
    }

    private func parseFileDiff(_ lines: [String]) -> FileDiff? {
        guard !lines.isEmpty else { return nil }

        var oldPath = ""
        var newPath = ""
        var hunks: [DiffHunk] = []
        var isBinary = false
        var isNewFile = false
        var isDeletedFile = false
        var fileMode: String?

        var currentHunkLines: [String] = []
        var currentHunkHeader: (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int, header: String?)?

        for line in lines {
            if line.hasPrefix("diff --git") {
                // Parse file paths from diff --git a/path b/path
                let parts = line.components(separatedBy: " ")
                if parts.count >= 4 {
                    oldPath = String(parts[2].dropFirst(2)) // Remove "a/"
                    newPath = String(parts[3].dropFirst(2)) // Remove "b/"
                }
            } else if line.hasPrefix("---") {
                // Old file path
                let path = String(line.dropFirst(4))
                if path != "/dev/null" {
                    oldPath = path.hasPrefix("a/") ? String(path.dropFirst(2)) : path
                }
            } else if line.hasPrefix("+++") {
                // New file path
                let path = String(line.dropFirst(4))
                if path != "/dev/null" {
                    newPath = path.hasPrefix("b/") ? String(path.dropFirst(2)) : path
                }
            } else if line.hasPrefix("new file mode") {
                isNewFile = true
                fileMode = String(line.dropFirst(14))
            } else if line.hasPrefix("deleted file mode") {
                isDeletedFile = true
                fileMode = String(line.dropFirst(18))
            } else if line.contains("Binary files") {
                isBinary = true
            } else if line.hasPrefix("@@") {
                // Save previous hunk
                if let header = currentHunkHeader, !currentHunkLines.isEmpty {
                    let hunk = createHunk(header: header, lines: currentHunkLines)
                    hunks.append(hunk)
                }

                // Parse new hunk header
                currentHunkHeader = parseHunkHeader(line)
                currentHunkLines = []
            } else if currentHunkHeader != nil {
                // Content line in a hunk
                currentHunkLines.append(line)
            }
        }

        // Save last hunk
        if let header = currentHunkHeader, !currentHunkLines.isEmpty {
            let hunk = createHunk(header: header, lines: currentHunkLines)
            hunks.append(hunk)
        }

        return FileDiff(
            oldPath: oldPath,
            newPath: newPath,
            hunks: hunks,
            isBinary: isBinary,
            isNewFile: isNewFile,
            isDeletedFile: isDeletedFile,
            fileMode: fileMode
        )
    }

    private func parseHunkHeader(_ line: String) -> (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int, header: String?)? {
        // Parse "@@ -1,5 +1,7 @@ optional header"
        let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)?$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        func extractInt(_ index: Int) -> Int {
            guard let range = Range(match.range(at: index), in: line) else { return 1 }
            return Int(line[range]) ?? 1
        }

        let oldStart = extractInt(1)
        let oldCount = match.range(at: 2).location != NSNotFound ? extractInt(2) : 1
        let newStart = extractInt(3)
        let newCount = match.range(at: 4).location != NSNotFound ? extractInt(4) : 1

        var header: String?
        if let headerRange = Range(match.range(at: 5), in: line) {
            let h = line[headerRange].trimmingCharacters(in: .whitespaces)
            if !h.isEmpty {
                header = h
            }
        }

        return (oldStart, oldCount, newStart, newCount, header)
    }

    private func createHunk(
        header: (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int, header: String?),
        lines: [String]
    ) -> DiffHunk {
        var diffLines: [DiffLine] = []
        var oldLine = header.oldStart
        var newLine = header.newStart

        for line in lines {
            guard !line.isEmpty else { continue }

            let firstChar = line.first
            let content = String(line.dropFirst())

            switch firstChar {
            case "+":
                diffLines.append(DiffLine(
                    type: .addition,
                    content: content,
                    oldLineNumber: nil,
                    newLineNumber: newLine
                ))
                newLine += 1

            case "-":
                diffLines.append(DiffLine(
                    type: .deletion,
                    content: content,
                    oldLineNumber: oldLine,
                    newLineNumber: nil
                ))
                oldLine += 1

            case " ":
                diffLines.append(DiffLine(
                    type: .context,
                    content: content,
                    oldLineNumber: oldLine,
                    newLineNumber: newLine
                ))
                oldLine += 1
                newLine += 1

            case "\\":
                // "\ No newline at end of file"
                if let lastLine = diffLines.last {
                    diffLines[diffLines.count - 1] = DiffLine(
                        type: lastLine.type,
                        content: lastLine.content,
                        oldLineNumber: lastLine.oldLineNumber,
                        newLineNumber: lastLine.newLineNumber,
                        hasNewline: false
                    )
                }

            default:
                // Context line without space prefix (shouldn't happen normally)
                diffLines.append(DiffLine(
                    type: .context,
                    content: line,
                    oldLineNumber: oldLine,
                    newLineNumber: newLine
                ))
                oldLine += 1
                newLine += 1
            }
        }

        return DiffHunk(
            oldStart: header.oldStart,
            oldCount: header.oldCount,
            newStart: header.newStart,
            newCount: header.newCount,
            header: header.header,
            lines: diffLines
        )
    }

    // MARK: - Advanced Operations

    // MARK: Reset

    func reset(to commit: String, mode: ResetMode) async throws -> ResetResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["reset", "--\(mode.rawValue)", commit],
            workingDirectory: repo.path
        )

        if result.success {
            return ResetResult(success: true, targetCommit: commit, mode: mode)
        } else {
            return ResetResult(
                success: false,
                targetCommit: commit,
                mode: mode,
                errorMessage: result.error ?? "Reset failed"
            )
        }
    }

    // MARK: Cherry-Pick

    func cherryPick(commit: String) async throws -> CherryPickResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["cherry-pick", commit],
            workingDirectory: repo.path
        )

        if result.success {
            // Get the new commit hash
            let headResult = await shellExecutor.executeGit(
                arguments: ["rev-parse", "HEAD"],
                workingDirectory: repo.path
            )
            let newHash = headResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(commitHash: newHash.isEmpty ? commit : newHash)
        } else {
            // Check if there are conflicts
            let output = result.output
            let errorOutput = result.error ?? ""

            if output.contains("CONFLICT") || errorOutput.contains("CONFLICT") ||
               output.contains("could not apply") || errorOutput.contains("could not apply") {
                return .conflict()
            }

            return .failure(result.error ?? "Cherry-pick failed")
        }
    }

    func cherryPickContinue() async throws -> CherryPickResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["cherry-pick", "--continue"],
            workingDirectory: repo.path
        )

        if result.success {
            let headResult = await shellExecutor.executeGit(
                arguments: ["rev-parse", "HEAD"],
                workingDirectory: repo.path
            )
            let newHash = headResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(commitHash: newHash)
        } else {
            let output = result.output
            let errorOutput = result.error ?? ""

            if output.contains("CONFLICT") || errorOutput.contains("CONFLICT") {
                return .conflict()
            }

            return .failure(result.error ?? "Cherry-pick continue failed")
        }
    }

    func cherryPickAbort() async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["cherry-pick", "--abort"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to abort cherry-pick")
        }
    }

    // MARK: Revert

    func revert(commit: String) async throws -> RevertResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["revert", "--no-edit", commit],
            workingDirectory: repo.path
        )

        if result.success {
            // Get the new revert commit hash
            let headResult = await shellExecutor.executeGit(
                arguments: ["rev-parse", "HEAD"],
                workingDirectory: repo.path
            )
            let newHash = headResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(revertCommitHash: newHash)
        } else {
            // Check if there are conflicts
            let output = result.output
            let errorOutput = result.error ?? ""

            if output.contains("CONFLICT") || errorOutput.contains("CONFLICT") ||
               output.contains("could not revert") || errorOutput.contains("could not revert") {
                return .conflict()
            }

            return .failure(result.error ?? "Revert failed")
        }
    }

    func revertContinue() async throws -> RevertResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["revert", "--continue"],
            workingDirectory: repo.path
        )

        if result.success {
            let headResult = await shellExecutor.executeGit(
                arguments: ["rev-parse", "HEAD"],
                workingDirectory: repo.path
            )
            let newHash = headResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(revertCommitHash: newHash)
        } else {
            let output = result.output
            let errorOutput = result.error ?? ""

            if output.contains("CONFLICT") || errorOutput.contains("CONFLICT") {
                return .conflict()
            }

            return .failure(result.error ?? "Revert continue failed")
        }
    }

    func revertAbort() async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["revert", "--abort"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to abort revert")
        }
    }

    // MARK: Blame

    func blame(file: String) async throws -> BlameInfo {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        // Use git blame with porcelain format for easier parsing
        let result = await shellExecutor.executeGit(
            arguments: ["blame", "--porcelain", file],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Blame failed")
        }

        return parseBlameOutput(result.output, filePath: file)
    }

    private func parseBlameOutput(_ output: String, filePath: String) -> BlameInfo {
        var lines: [BlameLine] = []
        var commits: [String: Commit] = [:]

        let outputLines = output.components(separatedBy: "\n")
        var lineIndex = 0
        var currentLineNumber = 0

        // Temporary storage for current blame entry
        var currentHash = ""
        var currentAuthor = ""
        var currentAuthorEmail = ""
        var currentAuthorTime: Date = Date()
        var isOriginal = false

        while lineIndex < outputLines.count {
            let line = outputLines[lineIndex]

            if line.isEmpty {
                lineIndex += 1
                continue
            }

            // Check if this is a commit hash line (40 hex chars + line numbers)
            if line.count >= 40 && line.prefix(40).allSatisfy({ $0.isHexDigit }) {
                let parts = line.split(separator: " ")
                if parts.count >= 3 {
                    currentHash = String(parts[0])
                    currentLineNumber = Int(parts[2]) ?? 0
                    // Check if this line is original to this commit
                    isOriginal = parts.count >= 4 && parts[1] == parts[2]
                }
                lineIndex += 1
                continue
            }

            // Parse blame headers
            if line.hasPrefix("author ") {
                currentAuthor = String(line.dropFirst(7))
            } else if line.hasPrefix("author-mail ") {
                let email = String(line.dropFirst(12))
                currentAuthorEmail = email.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            } else if line.hasPrefix("author-time ") {
                if let timestamp = TimeInterval(String(line.dropFirst(12))) {
                    currentAuthorTime = Date(timeIntervalSince1970: timestamp)
                }
            } else if line.hasPrefix("\t") {
                // This is the actual line content
                let content = String(line.dropFirst(1))

                let blameLine = BlameLine(
                    lineNumber: currentLineNumber,
                    commitHash: currentHash,
                    author: currentAuthor,
                    authorEmail: currentAuthorEmail,
                    date: currentAuthorTime,
                    content: content,
                    isOriginal: isOriginal
                )
                lines.append(blameLine)

                // Store commit info if not already stored
                if commits[currentHash] == nil {
                    commits[currentHash] = Commit(
                        hash: currentHash,
                        message: "",
                        author: currentAuthor,
                        authorEmail: currentAuthorEmail,
                        date: currentAuthorTime
                    )
                }
            }

            lineIndex += 1
        }

        return BlameInfo(filePath: filePath, lines: lines, commits: commits)
    }

    // MARK: - Submodule Operations

    func listSubmodules() async throws -> [Submodule] {
        guard let repo = currentRepository else {
            return []
        }

        // First, check if there are any submodules configured
        let statusResult = await shellExecutor.executeGit(
            arguments: ["submodule", "status"],
            workingDirectory: repo.path
        )

        guard statusResult.success else {
            return []
        }

        let output = statusResult.output
        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }

        var submodules: [Submodule] = []

        // Parse submodule status output
        // Format: " <commit> <path> (<branch>)" or "-<commit> <path>" (not initialized)
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let isInitialized = !trimmed.hasPrefix("-")
            let hasChanges = trimmed.hasPrefix("+")

            // Remove status prefix
            var cleanLine = trimmed
            if cleanLine.hasPrefix("-") || cleanLine.hasPrefix("+") || cleanLine.hasPrefix(" ") {
                cleanLine = String(cleanLine.dropFirst())
            }

            let parts = cleanLine.split(separator: " ", maxSplits: 2)
            guard parts.count >= 2 else { continue }

            let commitHash = String(parts[0])
            let path = String(parts[1])

            // Extract branch if present (in parentheses)
            var branch: String?
            if parts.count > 2 {
                let branchPart = String(parts[2])
                if branchPart.hasPrefix("(") && branchPart.hasSuffix(")") {
                    branch = String(branchPart.dropFirst().dropLast())
                }
            }

            // Get URL from .gitmodules
            let url = await getSubmoduleURL(path: path, repo: repo)

            let submodule = Submodule(
                name: path.components(separatedBy: "/").last ?? path,
                path: path,
                url: url,
                branch: branch,
                commitHash: commitHash,
                isInitialized: isInitialized,
                hasChanges: hasChanges
            )
            submodules.append(submodule)
        }

        return submodules
    }

    private func getSubmoduleURL(path: String, repo: Repository) async -> URL? {
        let result = await shellExecutor.executeGit(
            arguments: ["config", "--file", ".gitmodules", "submodule.\(path).url"],
            workingDirectory: repo.path
        )

        guard result.success else { return nil }

        let urlString = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: urlString)
    }

    func addSubmodule(url: URL, path: String, branch: String?) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var arguments = ["submodule", "add"]

        if let branch = branch {
            arguments.append(contentsOf: ["-b", branch])
        }

        arguments.append(url.absoluteString)
        arguments.append(path)

        let result = await shellExecutor.executeGit(
            arguments: arguments,
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to add submodule")
        }
    }

    func initSubmodule(path: String?) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var arguments = ["submodule", "init"]

        if let path = path {
            arguments.append(path)
        }

        let result = await shellExecutor.executeGit(
            arguments: arguments,
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to initialize submodule")
        }
    }

    func updateSubmodules(recursive: Bool, init initSubmodules: Bool) async throws -> [SubmoduleUpdateResult] {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var arguments = ["submodule", "update"]

        if initSubmodules {
            arguments.append("--init")
        }

        if recursive {
            arguments.append("--recursive")
        }

        let result = await shellExecutor.executeGit(
            arguments: arguments,
            workingDirectory: repo.path,
            timeout: 120  // Longer timeout for submodule updates
        )

        if result.success {
            // Get updated submodules to return their status
            let submodules = try await listSubmodules()
            return submodules.map { submodule in
                SubmoduleUpdateResult.success(path: submodule.path, commit: submodule.commitHash)
            }
        } else {
            return [SubmoduleUpdateResult.failure(path: "*", error: result.error ?? "Failed to update submodules")]
        }
    }

    func updateSubmodule(path: String, recursive: Bool) async throws -> SubmoduleUpdateResult {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var arguments = ["submodule", "update"]

        if recursive {
            arguments.append("--recursive")
        }

        arguments.append("--")
        arguments.append(path)

        let result = await shellExecutor.executeGit(
            arguments: arguments,
            workingDirectory: repo.path,
            timeout: 120
        )

        if result.success {
            // Get updated commit hash
            let submodules = try await listSubmodules()
            let updated = submodules.first { $0.path == path }
            return SubmoduleUpdateResult.success(path: path, commit: updated?.commitHash)
        } else {
            return SubmoduleUpdateResult.failure(path: path, error: result.error ?? "Failed to update submodule")
        }
    }

    func removeSubmodule(path: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        // Step 1: Deinit the submodule
        let deinitResult = await shellExecutor.executeGit(
            arguments: ["submodule", "deinit", "-f", path],
            workingDirectory: repo.path
        )

        guard deinitResult.success else {
            throw GitError.commandFailed(deinitResult.error ?? "Failed to deinit submodule")
        }

        // Step 2: Remove the submodule from .git/modules
        let rmModuleResult = await shellExecutor.executeGit(
            arguments: ["rm", "-f", path],
            workingDirectory: repo.path
        )

        guard rmModuleResult.success else {
            throw GitError.commandFailed(rmModuleResult.error ?? "Failed to remove submodule")
        }

        // Step 3: Remove the submodule directory from .git/modules (if exists)
        let modulesPath = repo.path.appendingPathComponent(".git/modules/\(path)")
        if FileManager.default.fileExists(atPath: modulesPath.path) {
            try? FileManager.default.removeItem(at: modulesPath)
        }
    }

    func syncSubmodules() async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["submodule", "sync", "--recursive"],
            workingDirectory: repo.path
        )

        guard result.success else {
            throw GitError.commandFailed(result.error ?? "Failed to sync submodules")
        }
    }

    // MARK: - Ignore Operations

    func getIgnoreFiles() async throws -> [IgnoreFile] {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        var ignoreFiles: [IgnoreFile] = []

        // Local .gitignore
        let localIgnorePath = repo.path.appendingPathComponent(".gitignore")
        let localIgnore = await parseIgnoreFile(at: localIgnorePath, source: .local)
        ignoreFiles.append(localIgnore)

        // Global gitignore
        if let globalPath = await getGlobalIgnorePath() {
            let globalIgnore = await parseIgnoreFile(at: globalPath, source: .global)
            ignoreFiles.append(globalIgnore)
        }

        // .git/info/exclude
        let excludePath = repo.path.appendingPathComponent(".git/info/exclude")
        let excludeIgnore = await parseIgnoreFile(at: excludePath, source: .excludeFile)
        ignoreFiles.append(excludeIgnore)

        return ignoreFiles
    }

    func getLocalIgnoreFile() async throws -> IgnoreFile {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let localIgnorePath = repo.path.appendingPathComponent(".gitignore")
        return await parseIgnoreFile(at: localIgnorePath, source: .local)
    }

    func addIgnorePattern(_ pattern: String) async throws {
        try await addIgnorePatterns([pattern])
    }

    func addIgnorePatterns(_ patterns: [String]) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let ignorePath = repo.path.appendingPathComponent(".gitignore")
        var content = ""

        // Read existing content
        if FileManager.default.fileExists(atPath: ignorePath.path) {
            content = (try? String(contentsOf: ignorePath, encoding: .utf8)) ?? ""
        }

        // Add newline if needed
        if !content.isEmpty && !content.hasSuffix("\n") {
            content += "\n"
        }

        // Add new patterns
        for pattern in patterns {
            let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPattern.isEmpty {
                // Check if pattern already exists
                let existingPatterns = content.components(separatedBy: .newlines)
                if !existingPatterns.contains(trimmedPattern) {
                    content += trimmedPattern + "\n"
                }
            }
        }

        // Write back
        try content.write(to: ignorePath, atomically: true, encoding: .utf8)
        logger.info("Added \(patterns.count) pattern(s) to .gitignore", category: .git)
    }

    func removeIgnorePattern(_ pattern: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let ignorePath = repo.path.appendingPathComponent(".gitignore")

        guard FileManager.default.fileExists(atPath: ignorePath.path) else {
            throw GitError.commandFailed(".gitignore file does not exist")
        }

        let content = try String(contentsOf: ignorePath, encoding: .utf8)
        var lines = content.components(separatedBy: .newlines)

        // Remove the pattern
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.removeAll { $0.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedPattern }

        // Write back
        let newContent = lines.joined(separator: "\n")
        try newContent.write(to: ignorePath, atomically: true, encoding: .utf8)
        logger.info("Removed pattern '\(pattern)' from .gitignore", category: .git)
    }

    func setIgnoreContent(_ content: String) async throws {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let ignorePath = repo.path.appendingPathComponent(".gitignore")
        try content.write(to: ignorePath, atomically: true, encoding: .utf8)
        logger.info("Updated .gitignore content", category: .git)
    }

    func isPathIgnored(_ path: String) async throws -> Bool {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let result = await shellExecutor.executeGit(
            arguments: ["check-ignore", "-q", path],
            workingDirectory: repo.path
        )

        // Exit code 0 means ignored, 1 means not ignored
        return result.exitCode == 0
    }

    func getIgnoredFiles() async throws -> [String] {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        // Get all ignored files (including untracked)
        let result = await shellExecutor.executeGit(
            arguments: ["ls-files", "--others", "--ignored", "--exclude-standard"],
            workingDirectory: repo.path
        )

        guard result.success else {
            return []
        }

        return result.output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
    }

    // MARK: - Ignore Helpers

    private func parseIgnoreFile(at path: URL, source: IgnoreSource) async -> IgnoreFile {
        let exists = FileManager.default.fileExists(atPath: path.path)

        guard exists else {
            return IgnoreFile(path: path, source: source, patterns: [], exists: false)
        }

        guard let content = try? String(contentsOf: path, encoding: .utf8) else {
            return IgnoreFile(path: path, source: source, patterns: [], exists: true)
        }

        let lines = content.components(separatedBy: .newlines)
        var patterns: [IgnorePattern] = []

        for (index, line) in lines.enumerated() {
            let pattern = IgnorePattern(
                pattern: line,
                lineNumber: index + 1,
                source: source
            )
            patterns.append(pattern)
        }

        return IgnoreFile(path: path, source: source, patterns: patterns, exists: true)
    }

    private func getGlobalIgnorePath() async -> URL? {
        // Try to get global gitignore path from git config
        let result = await shellExecutor.executeGit(
            arguments: ["config", "--global", "core.excludesfile"]
        )

        if result.success {
            let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty {
                // Expand ~ if present
                let expandedPath = (path as NSString).expandingTildeInPath
                return URL(fileURLWithPath: expandedPath)
            }
        }

        // Default location: ~/.gitignore_global
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let defaultPath = homeDir.appendingPathComponent(".gitignore_global")
        if FileManager.default.fileExists(atPath: defaultPath.path) {
            return defaultPath
        }

        // Also check ~/.config/git/ignore
        let configPath = homeDir.appendingPathComponent(".config/git/ignore")
        if FileManager.default.fileExists(atPath: configPath.path) {
            return configPath
        }

        return nil
    }

    // MARK: - Statistics Operations

    /// Get repository statistics for a time period
    func getRepositoryStatistics(since: Date) async throws -> RepositoryStatistics {
        guard let repo = currentRepository else {
            throw GitError.repositoryNotOpen
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let sinceString = dateFormatter.string(from: since)

        // Get all stats in parallel
        async let commitCount = getCommitCount(since: sinceString, repoPath: repo.path)
        async let branchCount = getBranchCount(repoPath: repo.path)
        async let authorStats = getAuthorStats(since: sinceString, repoPath: repo.path)
        async let dailyActivity = getDailyActivity(since: sinceString, repoPath: repo.path)

        return RepositoryStatistics(
            periodStart: since,
            periodEnd: Date(),
            totalCommits: try await commitCount,
            totalBranches: try await branchCount,
            authorStats: try await authorStats,
            dailyActivity: try await dailyActivity
        )
    }

    /// Get commit count since a date
    private func getCommitCount(since: String, repoPath: URL) async throws -> Int {
        let result = await shellExecutor.executeGit(
            arguments: ["rev-list", "--count", "--since=\(since)", "HEAD"],
            workingDirectory: repoPath
        )

        if result.success {
            let countStr = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return Int(countStr) ?? 0
        }
        return 0
    }

    /// Get total branch count
    private func getBranchCount(repoPath: URL) async throws -> Int {
        let result = await shellExecutor.executeGit(
            arguments: ["branch", "-a"],
            workingDirectory: repoPath
        )

        if result.success {
            let lines = result.output.components(separatedBy: CharacterSet.newlines)
            return lines.filter { !$0.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty }.count
        }
        return 0
    }

    /// Get author statistics since a date
    private func getAuthorStats(since: String, repoPath: URL) async throws -> [AuthorStats] {
        let result = await shellExecutor.executeGit(
            arguments: ["shortlog", "-sne", "--since=\(since)", "HEAD"],
            workingDirectory: repoPath
        )

        guard result.success else { return [] }

        var authors: [AuthorStats] = []
        var totalCommits = 0

        // Parse output: "    42\tJohn Doe <john@example.com>"
        let lines = result.output.components(separatedBy: CharacterSet.newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Split by tab
            let parts = trimmed.components(separatedBy: "\t")
            guard parts.count >= 2,
                  let count = Int(parts[0].trimmingCharacters(in: CharacterSet.whitespaces)) else { continue }

            let nameEmail = parts[1]
            var name = nameEmail
            var email = ""

            // Extract email from "Name <email>"
            if let emailStart = nameEmail.firstIndex(of: "<"),
               let emailEnd = nameEmail.firstIndex(of: ">") {
                name = String(nameEmail[..<emailStart]).trimmingCharacters(in: CharacterSet.whitespaces)
                email = String(nameEmail[nameEmail.index(after: emailStart)..<emailEnd])
            }

            authors.append(AuthorStats(
                name: name,
                email: email,
                commitCount: count,
                percentage: 0 // Will be calculated after
            ))
            totalCommits += count
        }

        // Calculate percentages
        if totalCommits > 0 {
            authors = authors.map { author in
                AuthorStats(
                    name: author.name,
                    email: author.email,
                    commitCount: author.commitCount,
                    percentage: Double(author.commitCount) / Double(totalCommits) * 100
                )
            }
        }

        // Sort by commit count descending
        return authors.sorted { $0.commitCount > $1.commitCount }
    }

    /// Get daily activity since a date
    private func getDailyActivity(since: String, repoPath: URL) async throws -> [DailyActivity] {
        let result = await shellExecutor.executeGit(
            arguments: ["log", "--since=\(since)", "--format=%ad", "--date=short"],
            workingDirectory: repoPath
        )

        guard result.success else { return [] }

        // Count commits per day manually
        var dateCounts: [String: Int] = [:]
        let lines = result.output.components(separatedBy: CharacterSet.newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
            guard !trimmed.isEmpty else { continue }
            dateCounts[trimmed, default: 0] += 1
        }

        var activities: [DailyActivity] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for (dateStr, count) in dateCounts {
            if let date = dateFormatter.date(from: dateStr) {
                activities.append(DailyActivity(date: date, commitCount: count))
            }
        }

        // Fill in missing days with zero commits
        let sinceDate = dateFormatter.date(from: String(since.prefix(10))) ?? Date().addingTimeInterval(-180 * 24 * 3600)
        return fillMissingDays(activities: activities, since: sinceDate)
    }

    /// Fill in missing days with zero activity
    private func fillMissingDays(activities: [DailyActivity], since: Date) -> [DailyActivity] {
        let calendar = Calendar.current
        let endDate = Date()

        // Create a dictionary for quick lookup
        var activityByDate: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for activity in activities {
            let key = dateFormatter.string(from: activity.date)
            activityByDate[key] = activity.commitCount
        }

        // Generate all days in the range
        var result: [DailyActivity] = []
        var currentDate = since

        while currentDate <= endDate {
            let key = dateFormatter.string(from: currentDate)
            let count = activityByDate[key] ?? 0
            result.append(DailyActivity(date: currentDate, commitCount: count))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }

        return result
    }
}
