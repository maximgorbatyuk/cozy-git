//
//  KeyboardShortcuts.swift
//  CozyGit
//

import SwiftUI

/// Centralized keyboard shortcuts for the app
enum KeyboardShortcuts {
    // MARK: - Repository
    static let openRepository = KeyEquivalent("o")
    static let closeRepository = KeyEquivalent("w")
    static let refreshRepository = KeyEquivalent("r")
    static let cloneRepository = KeyEquivalent("n")

    // MARK: - Git Operations
    static let commit = KeyEquivalent("k")
    static let push = KeyEquivalent("p")
    static let pull = KeyEquivalent("l")
    static let fetch = KeyEquivalent("f")
    static let stageAll = KeyEquivalent("a")
    static let unstageAll = KeyEquivalent("u")

    // MARK: - Navigation
    static let overview = KeyEquivalent("1")
    static let changes = KeyEquivalent("2")
    static let branches = KeyEquivalent("3")
    static let history = KeyEquivalent("4")
    static let stash = KeyEquivalent("5")
    static let tags = KeyEquivalent("6")
    static let remotes = KeyEquivalent("7")
    static let submodules = KeyEquivalent("8")
    static let gitignore = KeyEquivalent("9")
    static let automation = KeyEquivalent("0")

    // MARK: - Search & Filter
    static let search = KeyEquivalent("f")
    static let filter = KeyEquivalent("g")

    // MARK: - Help
    static let showHelp = KeyEquivalent("?")
    static let showShortcuts = KeyEquivalent("/")
}

/// Keyboard shortcut info for display
struct ShortcutInfo: Identifiable {
    let id = UUID()
    let name: String
    let shortcut: String
    let category: ShortcutCategory

    enum ShortcutCategory: String, CaseIterable {
        case repository = "Repository"
        case gitOperations = "Git Operations"
        case navigation = "Navigation"
        case editing = "Editing"
        case help = "Help"
    }
}

/// All documented keyboard shortcuts
let allShortcuts: [ShortcutInfo] = [
    // Repository
    ShortcutInfo(name: "Open Repository", shortcut: "⌘O", category: .repository),
    ShortcutInfo(name: "Close Repository", shortcut: "⌘W", category: .repository),
    ShortcutInfo(name: "Refresh", shortcut: "⌘R", category: .repository),
    ShortcutInfo(name: "Clone Repository", shortcut: "⇧⌘N", category: .repository),

    // Git Operations
    ShortcutInfo(name: "Commit", shortcut: "⌘K", category: .gitOperations),
    ShortcutInfo(name: "Push", shortcut: "⇧⌘P", category: .gitOperations),
    ShortcutInfo(name: "Pull", shortcut: "⇧⌘L", category: .gitOperations),
    ShortcutInfo(name: "Fetch", shortcut: "⇧⌘F", category: .gitOperations),
    ShortcutInfo(name: "Stage All", shortcut: "⌥⌘A", category: .gitOperations),
    ShortcutInfo(name: "Unstage All", shortcut: "⌥⌘U", category: .gitOperations),

    // Navigation
    ShortcutInfo(name: "Overview", shortcut: "⌘1", category: .navigation),
    ShortcutInfo(name: "Changes", shortcut: "⌘2", category: .navigation),
    ShortcutInfo(name: "Branches", shortcut: "⌘3", category: .navigation),
    ShortcutInfo(name: "History", shortcut: "⌘4", category: .navigation),
    ShortcutInfo(name: "Stash", shortcut: "⌘5", category: .navigation),
    ShortcutInfo(name: "Tags", shortcut: "⌘6", category: .navigation),
    ShortcutInfo(name: "Remotes", shortcut: "⌘7", category: .navigation),
    ShortcutInfo(name: "Submodules", shortcut: "⌘8", category: .navigation),
    ShortcutInfo(name: "Gitignore", shortcut: "⌘9", category: .navigation),
    ShortcutInfo(name: "Automation", shortcut: "⌘0", category: .navigation),

    // Editing
    ShortcutInfo(name: "Search", shortcut: "⌘F", category: .editing),
    ShortcutInfo(name: "Select All", shortcut: "⌘A", category: .editing),
    ShortcutInfo(name: "Copy", shortcut: "⌘C", category: .editing),

    // Help
    ShortcutInfo(name: "Show Help", shortcut: "⌘?", category: .help),
    ShortcutInfo(name: "Show Shortcuts", shortcut: "⌘/", category: .help),
]

// MARK: - Shortcuts Help View

struct ShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Shortcuts List
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(ShortcutInfo.ShortcutCategory.allCases, id: \.self) { category in
                        shortcutSection(for: category)
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
    }

    private func shortcutSection(for category: ShortcutInfo.ShortcutCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue)
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(allShortcuts.filter { $0.category == category }) { shortcut in
                HStack {
                    Text(shortcut.name)
                    Spacer()
                    Text(shortcut.shortcut)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

#Preview {
    ShortcutsHelpView()
}
