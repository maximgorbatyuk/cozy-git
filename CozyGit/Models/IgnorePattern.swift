//
//  IgnorePattern.swift
//  CozyGit
//

import Foundation

/// Represents a single pattern in a .gitignore file
struct IgnorePattern: Identifiable, Equatable, Hashable {
    let id: UUID
    let pattern: String
    let lineNumber: Int
    let source: IgnoreSource
    let isNegation: Bool
    let isComment: Bool
    let isBlank: Bool

    init(
        id: UUID = UUID(),
        pattern: String,
        lineNumber: Int,
        source: IgnoreSource = .local
    ) {
        self.id = id
        self.pattern = pattern
        self.lineNumber = lineNumber
        self.source = source
        self.isNegation = pattern.hasPrefix("!")
        self.isComment = pattern.hasPrefix("#")
        self.isBlank = pattern.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The effective pattern (without negation prefix if present)
    var effectivePattern: String {
        if isNegation {
            return String(pattern.dropFirst())
        }
        return pattern
    }

    /// Whether this pattern matches directories only
    var isDirectoryOnly: Bool {
        pattern.hasSuffix("/")
    }

    /// Human-readable description of what this pattern does
    var patternDescription: String {
        if isComment {
            return "Comment"
        }
        if isBlank {
            return "Empty line"
        }
        if isNegation {
            return "Includes: \(effectivePattern)"
        }
        if isDirectoryOnly {
            return "Ignores directory: \(pattern.dropLast())"
        }
        if pattern.contains("*") {
            return "Ignores files matching: \(pattern)"
        }
        return "Ignores: \(pattern)"
    }
}

/// Source of the ignore pattern
enum IgnoreSource: String, CaseIterable, Identifiable {
    case local = "local"           // .gitignore in repo root
    case global = "global"         // ~/.gitignore_global
    case nested = "nested"         // .gitignore in subdirectory
    case excludeFile = "exclude"   // .git/info/exclude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local: return "Local (.gitignore)"
        case .global: return "Global (~/.gitignore_global)"
        case .nested: return "Nested .gitignore"
        case .excludeFile: return "Exclude (.git/info/exclude)"
        }
    }

    var iconName: String {
        switch self {
        case .local: return "doc.text"
        case .global: return "globe"
        case .nested: return "folder"
        case .excludeFile: return "lock.doc"
        }
    }
}

/// Result of parsing a .gitignore file
struct IgnoreFile: Identifiable, Equatable {
    let id: UUID
    let path: URL
    let source: IgnoreSource
    let patterns: [IgnorePattern]
    let exists: Bool

    init(
        id: UUID = UUID(),
        path: URL,
        source: IgnoreSource,
        patterns: [IgnorePattern] = [],
        exists: Bool = true
    ) {
        self.id = id
        self.path = path
        self.source = source
        self.patterns = patterns
        self.exists = exists
    }

    /// All non-comment, non-blank patterns
    var activePatterns: [IgnorePattern] {
        patterns.filter { !$0.isComment && !$0.isBlank }
    }

    /// Raw content of the file
    var content: String {
        patterns.map(\.pattern).joined(separator: "\n")
    }
}

/// Quick ignore template for common patterns
struct IgnoreTemplate: Identifiable {
    let id: UUID
    let name: String
    let patterns: [String]
    let description: String

    init(id: UUID = UUID(), name: String, patterns: [String], description: String) {
        self.id = id
        self.name = name
        self.patterns = patterns
        self.description = description
    }

    static let commonTemplates: [IgnoreTemplate] = [
        IgnoreTemplate(
            name: "macOS",
            patterns: [".DS_Store", ".AppleDouble", ".LSOverride", "._*"],
            description: "macOS system files"
        ),
        IgnoreTemplate(
            name: "Xcode",
            patterns: [
                "build/",
                "DerivedData/",
                "*.xcuserstate",
                "xcuserdata/",
                "*.xcscmblueprint"
            ],
            description: "Xcode build artifacts"
        ),
        IgnoreTemplate(
            name: "Swift Package Manager",
            patterns: [".build/", "Packages/", "Package.resolved"],
            description: "Swift PM files"
        ),
        IgnoreTemplate(
            name: "CocoaPods",
            patterns: ["Pods/", "Podfile.lock"],
            description: "CocoaPods dependencies"
        ),
        IgnoreTemplate(
            name: "Node.js",
            patterns: ["node_modules/", "npm-debug.log", "yarn-error.log"],
            description: "Node.js dependencies and logs"
        ),
        IgnoreTemplate(
            name: "Python",
            patterns: ["__pycache__/", "*.py[cod]", ".venv/", "venv/", "*.egg-info/"],
            description: "Python cache and virtual environments"
        ),
        IgnoreTemplate(
            name: "IDE Files",
            patterns: [".idea/", ".vscode/", "*.swp", "*.swo", "*~"],
            description: "Common IDE and editor files"
        ),
        IgnoreTemplate(
            name: "Environment",
            patterns: [".env", ".env.local", ".env.*.local", "*.pem"],
            description: "Environment files and secrets"
        ),
        IgnoreTemplate(
            name: "Logs",
            patterns: ["*.log", "logs/", "*.tmp", "*.temp"],
            description: "Log and temporary files"
        )
    ]
}
