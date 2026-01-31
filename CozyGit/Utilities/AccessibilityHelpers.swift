//
//  AccessibilityHelpers.swift
//  CozyGit
//
//  Phase 20: Accessibility & Localization

import SwiftUI
import Combine

// MARK: - Accessibility Identifiers

/// Centralized accessibility identifiers for UI testing and automation
enum AccessibilityID {
    // Navigation
    static let sidebar = "sidebar"
    static let detailView = "detailView"
    static let tabBar = "tabBar"

    // Tabs
    static let overviewTab = "overviewTab"
    static let changesTab = "changesTab"
    static let branchesTab = "branchesTab"
    static let historyTab = "historyTab"
    static let stashTab = "stashTab"
    static let tagsTab = "tagsTab"
    static let remotesTab = "remotesTab"
    static let submodulesTab = "submodulesTab"
    static let gitignoreTab = "gitignoreTab"
    static let automateTab = "automateTab"
    static let cleanupTab = "cleanupTab"

    // Actions
    static let commitButton = "commitButton"
    static let pushButton = "pushButton"
    static let pullButton = "pullButton"
    static let fetchButton = "fetchButton"
    static let stageButton = "stageButton"
    static let unstageButton = "unstageButton"
    static let discardButton = "discardButton"
    static let refreshButton = "refreshButton"

    // Lists
    static let fileList = "fileList"
    static let branchList = "branchList"
    static let commitList = "commitList"
    static let stashList = "stashList"
    static let tagList = "tagList"

    // Diff View
    static let diffView = "diffView"
    static let unifiedDiffView = "unifiedDiffView"
    static let sideBySideDiffView = "sideBySideDiffView"

    // Dialogs
    static let commitDialog = "commitDialog"
    static let commitMessageField = "commitMessageField"
    static let newBranchDialog = "newBranchDialog"
    static let mergeDialog = "mergeDialog"
}

// MARK: - Accessibility Labels

/// Centralized accessibility labels for VoiceOver
enum AccessibilityLabel {
    // File Status
    static func fileStatus(_ status: FileChangeType) -> String {
        switch status {
        case .modified: return String(localized: "Modified file", comment: "Accessibility label for modified file status")
        case .added: return String(localized: "New file", comment: "Accessibility label for added file status")
        case .deleted: return String(localized: "Deleted file", comment: "Accessibility label for deleted file status")
        case .renamed: return String(localized: "Renamed file", comment: "Accessibility label for renamed file status")
        case .copied: return String(localized: "Copied file", comment: "Accessibility label for copied file status")
        case .untracked: return String(localized: "Untracked file", comment: "Accessibility label for untracked file status")
        case .ignored: return String(localized: "Ignored file", comment: "Accessibility label for ignored file status")
        }
    }

    static func fileRow(name: String, status: FileChangeType, isStaged: Bool) -> String {
        let stageState = isStaged
            ? String(localized: "staged", comment: "File is staged")
            : String(localized: "unstaged", comment: "File is not staged")
        return "\(name), \(fileStatus(status)), \(stageState)"
    }

    // Branch
    static func branch(name: String, isCurrent: Bool, isRemote: Bool) -> String {
        var parts = [name]
        if isCurrent {
            parts.append(String(localized: "current branch", comment: "Current branch indicator"))
        }
        if isRemote {
            parts.append(String(localized: "remote branch", comment: "Remote branch indicator"))
        }
        return parts.joined(separator: ", ")
    }

    // Commit
    static func commit(message: String, author: String, date: Date) -> String {
        let dateString = date.formatted(date: .abbreviated, time: .shortened)
        return String(localized: "Commit: \(message), by \(author), \(dateString)", comment: "Commit accessibility label")
    }

    // Diff
    static func diffLine(type: DiffLineType, lineNumber: Int?, content: String) -> String {
        let typeLabel: String
        switch type {
        case .addition:
            typeLabel = String(localized: "Added line", comment: "Diff line added")
        case .deletion:
            typeLabel = String(localized: "Removed line", comment: "Diff line removed")
        case .context:
            typeLabel = String(localized: "Unchanged line", comment: "Diff line unchanged")
        case .hunkHeader:
            typeLabel = String(localized: "Section header", comment: "Diff hunk header")
        case .noNewline:
            typeLabel = String(localized: "No newline at end of file", comment: "No newline indicator")
        }

        if let lineNumber = lineNumber {
            return "\(typeLabel) \(lineNumber): \(content)"
        }
        return "\(typeLabel): \(content)"
    }

    // Actions
    static let stageFile = String(localized: "Stage file", comment: "Stage file action")
    static let unstageFile = String(localized: "Unstage file", comment: "Unstage file action")
    static let discardChanges = String(localized: "Discard changes", comment: "Discard changes action")
    static let commit = String(localized: "Commit changes", comment: "Commit action")
    static let push = String(localized: "Push to remote", comment: "Push action")
    static let pull = String(localized: "Pull from remote", comment: "Pull action")
    static let fetch = String(localized: "Fetch from remote", comment: "Fetch action")
    static let refresh = String(localized: "Refresh", comment: "Refresh action")
    static let createBranch = String(localized: "Create new branch", comment: "Create branch action")
    static let deleteBranch = String(localized: "Delete branch", comment: "Delete branch action")
    static let checkoutBranch = String(localized: "Switch to branch", comment: "Checkout branch action")
    static let mergeBranch = String(localized: "Merge branch", comment: "Merge branch action")

    // Status
    static func remoteStatus(ahead: Int, behind: Int) -> String {
        if ahead == 0 && behind == 0 {
            return String(localized: "Up to date with remote", comment: "Remote status up to date")
        }
        var parts: [String] = []
        if ahead > 0 {
            parts.append(String(localized: "\(ahead) commits ahead", comment: "Commits ahead count"))
        }
        if behind > 0 {
            parts.append(String(localized: "\(behind) commits behind", comment: "Commits behind count"))
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Accessibility Hints

/// Accessibility hints for complex controls
enum AccessibilityHint {
    static let fileRow = String(localized: "Double-tap to view diff. Swipe actions available.", comment: "File row hint")
    static let branchRow = String(localized: "Double-tap to switch to this branch.", comment: "Branch row hint")
    static let commitRow = String(localized: "Double-tap to view commit details.", comment: "Commit row hint")
    static let diffModeToggle = String(localized: "Switch between unified and side-by-side diff views.", comment: "Diff mode toggle hint")
    static let stageButton = String(localized: "Add file to staging area for next commit.", comment: "Stage button hint")
    static let unstageButton = String(localized: "Remove file from staging area.", comment: "Unstage button hint")
    static let discardButton = String(localized: "Revert file to last committed state. This cannot be undone.", comment: "Discard button hint")
}

// MARK: - Accessibility View Modifiers

/// Modifier to add comprehensive accessibility to file rows
struct FileAccessibilityModifier: ViewModifier {
    let file: FileStatus
    let isStaged: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityLabel.fileRow(name: file.path, status: file.status, isStaged: isStaged))
            .accessibilityHint(AccessibilityHint.fileRow)
            .accessibilityAddTraits(.isButton)
    }
}

/// Modifier to add accessibility to branch rows
struct BranchAccessibilityModifier: ViewModifier {
    let branch: Branch

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityLabel.branch(name: branch.name, isCurrent: branch.isCurrent, isRemote: branch.isRemote))
            .accessibilityHint(AccessibilityHint.branchRow)
            .accessibilityAddTraits(branch.isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}

/// Modifier to add accessibility to commit rows
struct CommitAccessibilityModifier: ViewModifier {
    let commit: Commit

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityLabel.commit(message: commit.message, author: commit.author, date: commit.date))
            .accessibilityHint(AccessibilityHint.commitRow)
            .accessibilityAddTraits(.isButton)
    }
}

/// Modifier to add accessibility to diff lines
struct DiffLineAccessibilityModifier: ViewModifier {
    let line: DiffLine

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityLabel.diffLine(
                type: line.type,
                lineNumber: line.newLineNumber ?? line.oldLineNumber,
                content: line.content
            ))
    }
}

// MARK: - View Extensions

extension View {
    /// Add file accessibility
    func fileAccessibility(file: FileStatus, isStaged: Bool) -> some View {
        modifier(FileAccessibilityModifier(file: file, isStaged: isStaged))
    }

    /// Add branch accessibility
    func branchAccessibility(branch: Branch) -> some View {
        modifier(BranchAccessibilityModifier(branch: branch))
    }

    /// Add commit accessibility
    func commitAccessibility(commit: Commit) -> some View {
        modifier(CommitAccessibilityModifier(commit: commit))
    }

    /// Add diff line accessibility
    func diffLineAccessibility(line: DiffLine) -> some View {
        modifier(DiffLineAccessibilityModifier(line: line))
    }

    /// Announce a message to VoiceOver
    func announceOnAppear(_ message: String) -> some View {
        self.onAppear {
            AccessibilityAnnouncer.shared.announce(message)
        }
    }

    /// Add standard accessibility identifier
    func accessibilityID(_ id: String) -> some View {
        self.accessibilityIdentifier(id)
    }
}

// MARK: - Accessibility Announcer

/// Announces messages to VoiceOver
@MainActor
final class AccessibilityAnnouncer: ObservableObject {
    static let shared = AccessibilityAnnouncer()

    /// Priority levels for accessibility announcements
    enum Priority: Int {
        case low = 0
        case medium = 50
        case high = 100
    }

    private init() {}

    /// Announce a message to VoiceOver
    func announce(_ message: String, priority: Priority = .medium) {
        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSNumber(value: priority.rawValue)
            ]
        )
    }

    /// Announce file staged
    func announceFileStaged(_ fileName: String) {
        announce(String(localized: "\(fileName) staged", comment: "File staged announcement"))
    }

    /// Announce file unstaged
    func announceFileUnstaged(_ fileName: String) {
        announce(String(localized: "\(fileName) unstaged", comment: "File unstaged announcement"))
    }

    /// Announce commit success
    func announceCommitSuccess() {
        announce(String(localized: "Changes committed successfully", comment: "Commit success announcement"), priority: .high)
    }

    /// Announce push success
    func announcePushSuccess() {
        announce(String(localized: "Changes pushed to remote", comment: "Push success announcement"), priority: .high)
    }

    /// Announce pull success
    func announcePullSuccess() {
        announce(String(localized: "Changes pulled from remote", comment: "Pull success announcement"), priority: .high)
    }

    /// Announce branch switch
    func announceBranchSwitch(_ branchName: String) {
        announce(String(localized: "Switched to branch \(branchName)", comment: "Branch switch announcement"), priority: .high)
    }

    /// Announce error
    func announceError(_ message: String) {
        announce(String(localized: "Error: \(message)", comment: "Error announcement"), priority: .high)
    }

    /// Announce loading state
    func announceLoading() {
        announce(String(localized: "Loading", comment: "Loading announcement"))
    }

    /// Announce loading complete
    func announceLoadingComplete() {
        announce(String(localized: "Loading complete", comment: "Loading complete announcement"))
    }

    /// Announce diff navigation
    func announceDiffChange(changeNumber: Int, totalChanges: Int) {
        announce(String(localized: "Change \(changeNumber) of \(totalChanges)", comment: "Diff change navigation"))
    }
}

// MARK: - Focus Management

/// Manages keyboard focus for accessibility
@MainActor
final class FocusManager: ObservableObject {
    static let shared = FocusManager()

    @Published var focusedElement: FocusableElement?

    enum FocusableElement: Hashable {
        case fileList
        case diffView
        case commitMessage
        case branchList
        case searchField
        case sidebar
    }

    private init() {}

    func focus(_ element: FocusableElement) {
        focusedElement = element
    }

    func clearFocus() {
        focusedElement = nil
    }
}

// MARK: - Keyboard Navigation State

/// Tracks keyboard navigation state
struct KeyboardNavigationState {
    var selectedIndex: Int = 0
    var itemCount: Int = 0

    mutating func moveUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    mutating func moveDown() {
        if selectedIndex < itemCount - 1 {
            selectedIndex += 1
        }
    }

    mutating func moveToFirst() {
        selectedIndex = 0
    }

    mutating func moveToLast() {
        selectedIndex = max(0, itemCount - 1)
    }
}

// MARK: - Rotor Support

/// Custom rotor actions for diff navigation
struct DiffRotorAction {
    let label: String
    let action: () -> Void
}

// MARK: - High Contrast Support

/// Provides colors optimized for high contrast mode
enum HighContrastColors {
    static var addition: Color {
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            return Color.green
        }
        return Color.green.opacity(0.15)
    }

    static var deletion: Color {
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            return Color.red
        }
        return Color.red.opacity(0.15)
    }

    static var modification: Color {
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            return Color.orange
        }
        return Color.orange.opacity(0.15)
    }

    static var selection: Color {
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            return Color.accentColor
        }
        return Color.accentColor.opacity(0.15)
    }
}

// MARK: - Dynamic Type Support

/// Font styles that respect Dynamic Type settings
enum DynamicFonts {
    static var body: Font {
        .body
    }

    static var headline: Font {
        .headline
    }

    static var subheadline: Font {
        .subheadline
    }

    static var caption: Font {
        .caption
    }

    static var monospaced: Font {
        .system(.body, design: .monospaced)
    }

    static var monospacedCaption: Font {
        .system(.caption, design: .monospaced)
    }
}

// MARK: - Reduced Motion Support

/// Checks if reduced motion is enabled
var prefersReducedMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
}

/// Animation that respects reduced motion preferences
extension Animation {
    static var accessibleSpring: Animation {
        if prefersReducedMotion {
            return .linear(duration: 0.1)
        }
        return .spring(response: 0.3, dampingFraction: 0.7)
    }

    static var accessibleEaseInOut: Animation {
        if prefersReducedMotion {
            return .linear(duration: 0.1)
        }
        return .easeInOut(duration: 0.2)
    }
}
