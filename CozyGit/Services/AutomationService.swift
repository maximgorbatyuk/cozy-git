//
//  AutomationService.swift
//  CozyGit
//

import Foundation

/// Service for managing automation features (commit prefixes and script hooks)
@MainActor
final class AutomationService {
    private let shellExecutor: ShellExecutor
    private let logger = Logger.shared

    init(shellExecutor: ShellExecutor) {
        self.shellExecutor = shellExecutor
    }

    // MARK: - Configuration Management

    func loadConfig(for repository: Repository) -> AutomationConfig {
        let config = AutomationConfig.load(from: repository.path)
        logger.info("Loaded automation config for \(repository.name)", category: .app)
        return config
    }

    func saveConfig(_ config: AutomationConfig, for repository: Repository) throws {
        try config.save(to: repository.path)
        logger.info("Saved automation config for \(repository.name)", category: .app)
    }

    // MARK: - Script Execution

    /// Execute a script hook
    func runHook(_ hook: ScriptHook, in repository: Repository) async -> ScriptResult {
        guard hook.isEnabled, let scriptPath = hook.scriptPath else {
            return ScriptResult(success: true, output: "", error: "", exitCode: 0, executionTime: 0)
        }

        guard FileManager.default.fileExists(atPath: scriptPath.path) else {
            logger.warning("Script not found: \(scriptPath.path)", category: .app)
            return ScriptResult(
                success: false,
                output: "",
                error: "Script file not found: \(scriptPath.path)",
                exitCode: 1,
                executionTime: 0
            )
        }

        let startTime = Date()

        let result = await shellExecutor.execute(
            command: scriptPath.path,
            arguments: [],
            workingDirectory: repository.path,
            timeout: hook.timeout
        )

        let executionTime = Date().timeIntervalSince(startTime)

        let scriptResult = ScriptResult(
            success: result.success,
            output: result.output,
            error: result.error ?? "",
            exitCode: result.exitCode,
            executionTime: executionTime
        )

        if scriptResult.success {
            logger.info("Hook \(hook.event.rawValue) completed successfully in \(String(format: "%.2f", executionTime))s", category: .app)
        } else {
            logger.warning("Hook \(hook.event.rawValue) failed with exit code \(scriptResult.exitCode)", category: .app)
        }

        return scriptResult
    }

    /// Test a script by running it with test environment
    func testScript(at path: URL, in repository: Repository) async -> ScriptResult {
        let testHook = ScriptHook(
            event: .preCommit,
            scriptPath: path,
            isEnabled: true,
            blockOnError: false,
            timeout: 30
        )

        return await runHook(testHook, in: repository)
    }

    /// Check if a script file is valid and executable
    func validateScript(at path: URL) -> (isValid: Bool, error: String?) {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path.path) else {
            return (false, "File does not exist")
        }

        guard fileManager.isExecutableFile(atPath: path.path) else {
            return (false, "File is not executable. Run 'chmod +x \(path.path)' to make it executable.")
        }

        // Check if file has a valid shebang
        if let data = fileManager.contents(atPath: path.path),
           let content = String(data: data, encoding: .utf8) {
            let firstLine = content.components(separatedBy: .newlines).first ?? ""
            if !firstLine.hasPrefix("#!") {
                return (false, "Script should start with a shebang (e.g., #!/bin/bash)")
            }
        }

        return (true, nil)
    }

    // MARK: - Hook Lifecycle

    /// Run pre-event hooks, returns false if the operation should be blocked
    func runPreHook(event: HookEvent, config: AutomationConfig, repository: Repository) async -> (shouldProceed: Bool, result: ScriptResult?) {
        guard let hook = config.hook(for: event), hook.isEnabled, hook.scriptPath != nil else {
            return (true, nil)
        }

        let result = await runHook(hook, in: repository)

        if !result.success && hook.blockOnError {
            return (false, result)
        }

        return (true, result)
    }

    /// Run post-event hooks
    func runPostHook(event: HookEvent, config: AutomationConfig, repository: Repository) async -> ScriptResult? {
        guard let hook = config.hook(for: event), hook.isEnabled, hook.scriptPath != nil else {
            return nil
        }

        return await runHook(hook, in: repository)
    }

    // MARK: - Commit Prefix

    /// Apply selected prefix to commit message
    func applyPrefix(to message: String, config: AutomationConfig) -> String {
        guard config.autoApplyPrefix,
              let prefix = config.selectedPrefix else {
            return message
        }

        return prefix.apply(to: message)
    }

    /// Get the appropriate prefix for a commit message based on content analysis
    func suggestPrefix(for message: String, config: AutomationConfig) -> CommitPrefix? {
        let lowercased = message.lowercased()

        // Check if message already has a prefix
        for prefix in config.enabledPrefixes {
            if message.hasPrefix(prefix.prefix) {
                return nil // Already has prefix
            }
        }

        // Simple heuristic-based suggestion
        if lowercased.contains("fix") || lowercased.contains("bug") || lowercased.contains("issue") {
            return config.enabledPrefixes.first { $0.prefix.contains("fix") }
        }

        if lowercased.contains("add") || lowercased.contains("new") || lowercased.contains("feature") || lowercased.contains("implement") {
            return config.enabledPrefixes.first { $0.prefix.contains("feat") }
        }

        if lowercased.contains("doc") || lowercased.contains("readme") || lowercased.contains("comment") {
            return config.enabledPrefixes.first { $0.prefix.contains("doc") }
        }

        if lowercased.contains("test") || lowercased.contains("spec") {
            return config.enabledPrefixes.first { $0.prefix.contains("test") }
        }

        if lowercased.contains("refactor") || lowercased.contains("clean") || lowercased.contains("reorganize") {
            return config.enabledPrefixes.first { $0.prefix.contains("refactor") }
        }

        if lowercased.contains("style") || lowercased.contains("format") || lowercased.contains("lint") {
            return config.enabledPrefixes.first { $0.prefix.contains("style") }
        }

        if lowercased.contains("perf") || lowercased.contains("optim") || lowercased.contains("speed") {
            return config.enabledPrefixes.first { $0.prefix.contains("perf") }
        }

        return nil
    }
}
