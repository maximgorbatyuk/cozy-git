//
//  AutomationModels.swift
//  CozyGit
//

import Foundation

// MARK: - Commit Prefix

/// A commit message prefix template
struct CommitPrefix: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var prefix: String
    var description: String
    var color: PrefixColor
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        prefix: String,
        description: String = "",
        color: PrefixColor = .gray,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.prefix = prefix
        self.description = description
        self.color = color
        self.isEnabled = isEnabled
    }

    /// Apply this prefix to a commit message
    func apply(to message: String) -> String {
        if message.hasPrefix(prefix) {
            return message
        }
        return "\(prefix) \(message)"
    }

    /// Common prefixes used in conventional commits
    static let conventionalCommits: [CommitPrefix] = [
        CommitPrefix(name: "Feature", prefix: "feat:", description: "A new feature", color: .green),
        CommitPrefix(name: "Fix", prefix: "fix:", description: "A bug fix", color: .red),
        CommitPrefix(name: "Docs", prefix: "docs:", description: "Documentation changes", color: .blue),
        CommitPrefix(name: "Style", prefix: "style:", description: "Code style changes (formatting)", color: .purple),
        CommitPrefix(name: "Refactor", prefix: "refactor:", description: "Code refactoring", color: .orange),
        CommitPrefix(name: "Test", prefix: "test:", description: "Adding or updating tests", color: .yellow),
        CommitPrefix(name: "Chore", prefix: "chore:", description: "Maintenance tasks", color: .gray),
        CommitPrefix(name: "Performance", prefix: "perf:", description: "Performance improvements", color: .cyan),
        CommitPrefix(name: "CI", prefix: "ci:", description: "CI/CD changes", color: .indigo),
        CommitPrefix(name: "Build", prefix: "build:", description: "Build system changes", color: .brown)
    ]

    /// Emoji-based prefixes
    static let emojiPrefixes: [CommitPrefix] = [
        CommitPrefix(name: "Feature", prefix: "✨", description: "New feature", color: .green),
        CommitPrefix(name: "Bug Fix", prefix: "🐛", description: "Bug fix", color: .red),
        CommitPrefix(name: "Docs", prefix: "📝", description: "Documentation", color: .blue),
        CommitPrefix(name: "Refactor", prefix: "♻️", description: "Refactoring", color: .orange),
        CommitPrefix(name: "Test", prefix: "✅", description: "Tests", color: .yellow),
        CommitPrefix(name: "Style", prefix: "💄", description: "UI/Style", color: .purple),
        CommitPrefix(name: "Performance", prefix: "⚡️", description: "Performance", color: .cyan),
        CommitPrefix(name: "Security", prefix: "🔒", description: "Security fix", color: .red),
        CommitPrefix(name: "WIP", prefix: "🚧", description: "Work in progress", color: .orange),
        CommitPrefix(name: "Release", prefix: "🎉", description: "Release", color: .green)
    ]
}

/// Colors for prefix badges
enum PrefixColor: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, blue, purple, cyan, indigo, brown, gray

    var id: String { rawValue }
}

// MARK: - Script Hook

/// Events that can trigger script hooks
enum HookEvent: String, Codable, CaseIterable, Identifiable {
    case preCommit = "pre-commit"
    case postCommit = "post-commit"
    case prePush = "pre-push"
    case postPush = "post-push"
    case prePull = "pre-pull"
    case postPull = "post-pull"
    case preMerge = "pre-merge"
    case postMerge = "post-merge"
    case preCheckout = "pre-checkout"
    case postCheckout = "post-checkout"
    case preFetch = "pre-fetch"
    case postFetch = "post-fetch"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preCommit: return "Pre-Commit"
        case .postCommit: return "Post-Commit"
        case .prePush: return "Pre-Push"
        case .postPush: return "Post-Push"
        case .prePull: return "Pre-Pull"
        case .postPull: return "Post-Pull"
        case .preMerge: return "Pre-Merge"
        case .postMerge: return "Post-Merge"
        case .preCheckout: return "Pre-Checkout"
        case .postCheckout: return "Post-Checkout"
        case .preFetch: return "Pre-Fetch"
        case .postFetch: return "Post-Fetch"
        }
    }

    var description: String {
        switch self {
        case .preCommit: return "Runs before creating a commit"
        case .postCommit: return "Runs after a commit is created"
        case .prePush: return "Runs before pushing to remote"
        case .postPush: return "Runs after pushing to remote"
        case .prePull: return "Runs before pulling from remote"
        case .postPull: return "Runs after pulling from remote"
        case .preMerge: return "Runs before merging branches"
        case .postMerge: return "Runs after merging branches"
        case .preCheckout: return "Runs before checking out a branch"
        case .postCheckout: return "Runs after checking out a branch"
        case .preFetch: return "Runs before fetching from remote"
        case .postFetch: return "Runs after fetching from remote"
        }
    }

    var iconName: String {
        switch self {
        case .preCommit, .postCommit: return "checkmark.circle"
        case .prePush, .postPush: return "arrow.up.circle"
        case .prePull, .postPull: return "arrow.down.circle"
        case .preMerge, .postMerge: return "arrow.triangle.merge"
        case .preCheckout, .postCheckout: return "arrow.triangle.branch"
        case .preFetch, .postFetch: return "arrow.clockwise.circle"
        }
    }

    var isPre: Bool {
        rawValue.hasPrefix("pre-")
    }
}

/// Configuration for a script hook
struct ScriptHook: Identifiable, Codable, Equatable {
    let id: UUID
    var event: HookEvent
    var scriptPath: URL?
    var isEnabled: Bool
    var blockOnError: Bool
    var timeout: TimeInterval
    var description: String

    init(
        id: UUID = UUID(),
        event: HookEvent,
        scriptPath: URL? = nil,
        isEnabled: Bool = false,
        blockOnError: Bool = true,
        timeout: TimeInterval = 30,
        description: String = ""
    ) {
        self.id = id
        self.event = event
        self.scriptPath = scriptPath
        self.isEnabled = isEnabled
        self.blockOnError = blockOnError
        self.timeout = timeout
        self.description = description
    }

    var isConfigured: Bool {
        scriptPath != nil
    }
}

/// Result of running a script hook
struct ScriptResult: Equatable {
    let success: Bool
    let output: String
    let error: String
    let exitCode: Int32
    let executionTime: TimeInterval

    var wasBlocked: Bool {
        !success && exitCode != 0
    }
}

// MARK: - Automation Configuration

/// Complete automation configuration for a repository
struct AutomationConfig: Codable, Equatable {
    var prefixes: [CommitPrefix]
    var selectedPrefixId: UUID?
    var hooks: [ScriptHook]
    var autoApplyPrefix: Bool
    var showPrefixInCommitDialog: Bool

    init(
        prefixes: [CommitPrefix] = CommitPrefix.conventionalCommits,
        selectedPrefixId: UUID? = nil,
        hooks: [ScriptHook] = HookEvent.allCases.map { ScriptHook(event: $0) },
        autoApplyPrefix: Bool = false,
        showPrefixInCommitDialog: Bool = true
    ) {
        self.prefixes = prefixes
        self.selectedPrefixId = selectedPrefixId
        self.hooks = hooks
        self.autoApplyPrefix = autoApplyPrefix
        self.showPrefixInCommitDialog = showPrefixInCommitDialog
    }

    var selectedPrefix: CommitPrefix? {
        guard let id = selectedPrefixId else { return nil }
        return prefixes.first { $0.id == id }
    }

    var enabledPrefixes: [CommitPrefix] {
        prefixes.filter { $0.isEnabled }
    }

    func hook(for event: HookEvent) -> ScriptHook? {
        hooks.first { $0.event == event }
    }

    mutating func updateHook(_ hook: ScriptHook) {
        if let index = hooks.firstIndex(where: { $0.id == hook.id }) {
            hooks[index] = hook
        }
    }

    mutating func updatePrefix(_ prefix: CommitPrefix) {
        if let index = prefixes.firstIndex(where: { $0.id == prefix.id }) {
            prefixes[index] = prefix
        }
    }

    // MARK: - Persistence

    static let configFileName = ".cozygit-automation.json"

    static func load(from repositoryPath: URL) -> AutomationConfig {
        let configPath = repositoryPath.appendingPathComponent(configFileName)

        guard FileManager.default.fileExists(atPath: configPath.path),
              let data = try? Data(contentsOf: configPath),
              let config = try? JSONDecoder().decode(AutomationConfig.self, from: data) else {
            return AutomationConfig()
        }

        return config
    }

    func save(to repositoryPath: URL) throws {
        let configPath = repositoryPath.appendingPathComponent(Self.configFileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: configPath)
    }
}
