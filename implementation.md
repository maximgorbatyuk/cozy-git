# Cozy Git - Technical Specifications

## Executive Summary

Cozy Git is a comprehensive macOS Git client providing a complete set of Git operations with focus on:
1. **CGF-1**: Git history cleanup (merged/stale branch management)
2. **CGF-2**: Automation of routine operations (commit prefixes, script hooks)
3. **Complete Git Feature Set**: Full Git CLI equivalent operations including status, commits, branches, merge, rebase, stash, tags, remotes, conflicts, and more

**Technology Stack**: SwiftUI, MVVM architecture, system Git commands, macOS native
**Design Philosophy**: Clean, warm, and intuitive interface with macOS native controls

This document provides comprehensive technical specifications including architecture, data models, API contracts, UI design, development phases, and testing strategy for a production-ready Git client.

---

## Architecture Overview

### Application Structure
- **Platform**: macOS native application
- **Language**: Swift
- **UI Framework**: SwiftUI (modern, declarative, fits "clean and warm" design)
- **Git Integration**: Custom wrapper around libgit2 or system git commands
- **Architecture Pattern**: MVVM (Model-View-ViewModel)

### Core Modules
1. **GitService** - Handles all git operations
2. **BranchManager** - Branch detection, analysis, and cleanup (CGF-1)
3. **AutomationEngine** - Script execution and commit message transformation (CGF-2)
4. **UI Components** - SwiftUI views following design guidelines

---

## Feature Specifications

### CGF-1: Git History Cleanup

#### 1.1 Merged Branch Deletion
- **Input**: User trigger (button/action)
- **Process**:
  - Fetch all remote branches
  - Identify branches merged into current/default branch
  - Filter out protected branches (main, master, develop)
  - Display branches to be deleted for confirmation
- **Output**: Delete selected merged branches (local and/or remote)
- **Git Commands**:
  - `git branch --merged` - List merged branches
  - `git branch -d <branch>` - Delete local branch
  - `git push origin --delete <branch>` - Delete remote branch

#### 1.2 Stale Branch Deletion
- **Definition**: Branches with no activity for configurable time period (default: 90 days)
- **Process**:
  - Parse `git for-each-ref` to get last commit date
  - Filter branches older than threshold
  - Exclude protected branches
  - Display for user review
- **Git Commands**:
  - `git for-each-ref --sort=-committerdate --format='%(committerdate:iso8601)%09%(refname:short)' refs/heads/`

#### 1.3 Protection Rules
- Protected branches list (configurable)
- Default protected: `main`, `master`, `develop`
- Current branch cannot be deleted
- Remote branches require separate confirmation

---

### CGF-2: Automation of Git Operations

#### 2.1 Commit Message Prefixes
- **Configuration**: Repository or global settings
- **Structure**: Prefix pattern (e.g., `[FEAT]`, `[FIX]`, `[CHORE]`)
- **Integration**: Hook into commit creation before `git commit`
- **UI**: Dropdown or selector for prefix type
- **Storage**: `.git/config` or app-specific config file

#### 2.2 Script Execution Hooks
- **Supported Events**:
  - `pre-commit`: Before commit is created
  - `post-commit`: After commit is created
  - `pre-push`: Before pushing to remote
  - `post-push`: After successful push
  - `pre-pull`: Before pulling from remote
  - `post-pull`: After successful pull
- **Configuration**:
  - Script path per event
  - Enable/disable toggle per script
  - Working directory setting
- **Execution**:
  - Run script synchronously or asynchronously (configurable)
  - Capture stdout/stderr for display
  - Exit code handling (block operation on non-zero if enabled)

#### 2.3 Automation Storage
- Repository-level: `.cozygit/config.json` (gitignored)
- Global: `~/Library/Application Support/CozyGit/config.json`
- Schema:
```json
{
  "commitPrefixes": {
    "enabled": true,
    "default": "[FEAT]",
    "options": ["[FEAT]", "[FIX]", "[CHORE]", "[DOCS]"]
  },
  "scripts": {
    "pre-commit": {
      "path": "/path/to/script.sh",
      "enabled": true,
      "blockOnError": true
    }
  },
  "protectedBranches": ["main", "master", "develop"]
}
```

---

### CGF-3: Core Git Operations

#### 3.1 Repository Management
- **Clone Repository**:
  - Input: Remote URL, local path
  - Process: Execute `git clone` with progress tracking
  - UI: Clone dialog with URL input, path selector, clone button
- **Initialize Repository**:
  - Input: Empty directory path
  - Process: Execute `git init`
  - UI: "New Repository" option in repository selector
- **Open Repository**:
  - Input: Path to existing repository
  - Process: Validate git repository, load current state
  - UI: File browser dialog, recent repositories list
- **Close Repository**:
  - Process: Clear in-memory state, stop background operations

#### 3.2 Status & Changes
- **Working Directory Status**:
  - Git Command: `git status --porcelain`
  - Display:
    - Modified files (staged and unstaged)
    - Untracked files
    - Deleted files
    - Renamed files
  - UI: File list with color-coded status indicators
    - 🟢 Staged
    - 🟡 Modified (unstaged)
    - 🔵 Untracked
    - 🔴 Deleted
    - 🟠 Renamed

#### 3.3 Commit Operations
- **Create Commit**:
  - Input: Commit message, optional prefix (from CGF-2), files to stage
  - Process:
    - Stage selected files (if not already staged)
    - Apply commit prefix (if enabled)
    - Execute pre-commit script (if configured)
    - Run `git commit -m "<message>"`
    - Execute post-commit script (if configured)
  - Git Commands:
    - `git add <files>` - Stage files
    - `git commit -m "<message>"` - Create commit
  - UI: Commit dialog with message editor, file checkboxes, stage/unstage buttons

- **Amend Commit**:
  - Input: New message or new files
  - Process: Modify last commit
  - Git Command: `git commit --amend -m "<new_message>"`
  - UI: "Amend" button in commit dialog (with warning)

- **View Commit History**:
  - Git Command: `git log --oneline --graph --all --decorate`
  - Display: List of commits with hash, author, date, message
  - UI: Scrollable commit list with search/filter
  - Details view: Show full diff, affected files

#### 3.4 Fetch & Pull
- **Fetch**:
  - Git Command: `git fetch`
  - Process: Update remote tracking branches without merging
  - UI: "Fetch" button with progress indicator
  - Feedback: Show number of new commits fetched

- **Pull**:
  - Git Command: `git pull` (or `git pull --rebase` option)
  - Process: Fetch and merge/rebase changes
  - Options:
    - Merge strategy: `--no-ff`, `--ff-only`
    - Rebase mode: `--rebase`
  - UI: "Pull" button with dropdown for strategy
  - Pre-pull script execution (if configured)
  - Post-pull script execution (if configured)
  - Conflict handling: Alert user on conflicts

#### 3.5 Push
- **Push**:
  - Git Command: `git push` or `git push origin <branch>`
  - Process: Upload local commits to remote
  - Options:
    - Force push (with warning)
    - Set upstream branch: `git push -u origin <branch>`
    - Push tags: `git push --tags`
  - Pre-push script execution (if configured)
  - Post-push script execution (if configured)
  - UI: "Push" button with options menu
  - Feedback: Show pushed commits count

#### 3.6 Branch Operations
- **Create Branch**:
  - Input: Branch name, base branch/commit
  - Git Command: `git checkout -b <branch_name>` or `git branch <branch_name>`
  - UI: "New Branch" dialog with name input, base selector

- **Checkout Branch**:
  - Input: Branch name
  - Git Command: `git checkout <branch_name>` or `git switch <branch_name>`
  - Process: Switch working directory to branch
  - Warning: Alert if uncommitted changes exist
  - Options: Stash changes, discard changes, cancel

- **Merge Branch**:
  - Input: Source branch to merge into current
  - Git Command: `git merge <branch>`
  - Options:
    - Fast-forward: `--ff` (default)
    - No fast-forward: `--no-ff` (create merge commit)
    - Squash: `--squash` (combine commits)
  - UI: "Merge" button in branch list, merge strategy dropdown
  - Conflict handling: Show conflicted files, open merge tool

- **Rebase**:
  - Input: Branch/commit to rebase onto
  - Git Commands:
    - `git rebase <branch>`
    - `git rebase -i <commit>` (interactive)
  - Process: Reapply commits on top of target
  - Options:
    - Interactive rebase for commit editing
    - Continue after conflicts: `git rebase --continue`
    - Abort: `git rebase --abort`
  - UI: Rebase dialog with target selection
  - Progress tracking during rebase
  - Conflict resolution interface

- **Reset**:
  - Input: Commit, mode (soft, mixed, hard)
  - Git Commands:
    - `git reset --soft <commit>` - Keep changes staged
    - `git reset --mixed <commit>` - Keep changes unstaged (default)
    - `git reset --hard <commit>` - Discard all changes
  - UI: Reset dialog with commit selector, mode buttons
  - Warning: Confirm destructive operations

#### 3.7 Diff & Changes View
- **View Diff**:
  - Git Commands:
    - Working directory: `git diff`
    - Staged changes: `git diff --cached`
    - Specific file: `git diff <file>`
    - Commits: `git diff <commit1> <commit2>`
  - Display: Side-by-side or unified diff view (toggleable)
  - UI: Diff viewer with:
    - Syntax highlighting
    - Line numbers
    - Inline comments
    - Copy diff button
    - Jump to next/previous change button
    - Collapse unchanged sections (context lines)
    - Export diff as file

- **Side-by-Side Diff View**:
  - **Layout**: Two synchronized scrolling panels
    - Left panel: Original version (old file/commit)
    - Right panel: New version (new file/working directory)
    - Synchronized scroll: Both panels scroll together
    - Line alignment: Matched lines horizontally aligned
  - **Line Types and Colors**:
    - Unchanged context: Warm gray background (#F5F5F5)
    - Added lines: Light green background (#D4EDDA) with green text
    - Removed lines: Light red background (#F8D7DA) with red text
    - Modified lines: Both panels show change with amber highlight (#FFF3CD)
  - **Visual Indicators**:
    - Connection lines between changed sections (curved bezier curves)
    - Gutter markers: +/- for additions/deletions
    - Line numbers: Separate column, gray text
    - Change blocks: Lighter background for entire change region
  - **Navigation**:
    - Jump to next change: Cmd+Opt+↓
    - Jump to previous change: Cmd+Opt+↑
    - Go to line: Cmd+L
  - **Line-by-Line View**:
    - For complex changes, show line-by-line comparison within changed blocks
    - Highlight character differences within modified lines
    - Word-level diff for text files
  - **File Type Handling**:
    - Text files: Full syntax highlighting, line-by-line
    - Code files: Language-specific highlighting
    - Markdown: Render preview mode option
    - Images: Side-by-side comparison (thumbnail/inline)
    - Binary files: "Binary file changed" indicator with file info
  - **Context Control**:
    - Adjustable context lines: 0, 1, 3, 5, 10
    - Collapse/expand unchanged sections
    - "Show all lines" option
  - **Selection & Actions**:
    - Select multiple lines across both panels
    - Copy selection (maintains line structure)
    - Copy entire diff (one-click)
    - Revert specific change (right-click menu)
    - Stage/unstage specific change (from working directory)
  - **Performance**:
    - Virtual scrolling for large files (1000+ lines)
    - Lazy rendering of unchanged sections
    - Debounced syntax highlighting
    - Progressive loading for very large diffs
  - **Responsiveness**:
    - Responsive panel widths (resize divider)
    - Minimum width constraints for readability
    - Panel width remembered per user
  - **Accessibility**:
    - Keyboard navigation through all changes
    - Screen reader announcements for line changes
    - High contrast mode support
    - Adjustable font size (Cmd+Plus/Minus)

- **Blame**:
  - Git Command: `git blame <file>`
  - Display: Show commit and author per line
  - UI: Annotated file view with commit details popover

#### 3.8 Stash Operations
- **Create Stash**:
  - Input: Optional message
  - Git Command: `git stash push -m "<message>"`
  - Options: Include untracked files (`-u`)
  - UI: "Stash" button with message input

- **List Stashes**:
  - Git Command: `git stash list`
  - Display: List of stashes with name, branch, date
  - UI: Stash list dropdown or panel

- **Apply Stash**:
  - Git Command: `git stash apply stash@{n}`
  - Process: Apply stashed changes to working directory
  - UI: "Apply" button per stash entry

- **Drop Stash**:
  - Git Command: `git stash drop stash@{n}`
  - UI: Delete button with confirmation

- **Pop Stash**:
  - Git Command: `git stash pop`
  - Process: Apply and remove stash
  - UI: "Pop" button

#### 3.9 Tag Operations
- **Create Tag**:
  - Input: Tag name, optional message, commit
  - Git Commands:
    - Lightweight: `git tag <name> <commit>`
    - Annotated: `git tag -a <name> -m "<message>" <commit>`
  - UI: "New Tag" dialog

- **List Tags**:
  - Git Command: `git tag --list`
  - Display: List of tags with commit info
  - UI: Tag list in commit history or separate view

- **Delete Tag**:
  - Git Command: `git tag -d <name>` (local), `git push origin --delete <name>` (remote)
  - UI: Delete button with confirmation

- **Push Tags**:
  - Git Command: `git push origin --tags`
  - UI: Push option in tag list

#### 3.10 Remote Management
- **List Remotes**:
  - Git Command: `git remote -v`
  - Display: Remote names and URLs
  - UI: Remotes list in settings

- **Add Remote**:
  - Input: Remote name, URL
  - Git Command: `git remote add <name> <url>`
  - UI: "Add Remote" dialog

- **Remove Remote**:
  - Git Command: `git remote remove <name>`
  - UI: Delete button with confirmation

- **Update Remote URL**:
  - Git Command: `git remote set-url <name> <new_url>`
  - UI: Edit button per remote

#### 3.11 Ignore File Management
- **View .gitignore**:
  - Display contents of `.gitignore` file
  - UI: Text editor for .gitignore

- **Add Ignore Patterns**:
  - Input: Pattern(s) to ignore
  - Process: Append to .gitignore
  - UI: Quick add dialog from file list

#### 3.12 Conflict Resolution
- **Detect Conflicts**:
  - Git Command: `git status` shows conflicted files
  - Process: Identify `<<<<<<<`, `=======`, `>>>>>>>` markers

- **Resolve Conflicts**:
  - Options per file:
    - Accept current: `git checkout --ours <file>`
    - Accept incoming: `git checkout --theirs <file>`
    - Manual edit: Open diff editor
    - Use external merge tool: `git mergetool`

  - UI:
    - List of conflicted files
    - Preview of both versions
    - Resolution buttons (current/incoming)
    - "Resolve" button after manual edit
    - "Continue" button (rebase) or "Commit" button (merge)

- **Abort Operation**:
  - Git Commands:
    - Abort merge: `git merge --abort`
    - Abort rebase: `git rebase --abort`
  - UI: "Abort" button in conflict resolution dialog

#### 3.13 Submodule Management
- **Add Submodule**:
  - Input: Submodule URL, path
  - Git Command: `git submodule add <url> <path>`
  - UI: "Add Submodule" dialog

- **Update Submodules**:
  - Git Command: `git submodule update --init --recursive`
  - UI: "Update Submodules" button

- **Remove Submodule**:
  - Git Commands: Multiple steps to cleanly remove
  - UI: Remove button with confirmation

#### 3.14 Cherry-Pick
- **Cherry-Pick Commit**:
  - Input: Commit hash
  - Git Command: `git cherry-pick <commit>`
  - Process: Apply commit to current branch
  - Options: Continue, skip, abort on conflicts
  - UI: "Cherry-Pick" action in commit context menu

#### 3.15 Revert
- **Revert Commit**:
  - Input: Commit hash
  - Git Command: `git revert <commit>`
  - Process: Create new commit that undoes changes
  - UI: "Revert" action in commit context menu

---

## Data Models

### Repository
```swift
struct Repository {
    let path: URL
    let name: String
    let currentBranch: String?
    let isBare: Bool
    let remotes: [Remote]
    let lastCommitDate: Date?
}
```

### Branch
```swift
struct Branch {
    let name: String
    let isLocal: Bool
    let isRemote: Bool
    let isCurrent: Bool
    let lastCommit: Commit?
    let isMerged: Bool
    let isProtected: Bool
    let commitCount: Int
    let upstream: String?
}
```

### Commit
```swift
struct Commit {
    let hash: String
    let shortHash: String
    let message: String
    let author: String
    let authorEmail: String
    let date: Date
    let committer: String
    let committerEmail: String
    let committerDate: Date
    let parents: [String]
    let refs: [String] // Branches/tags pointing to this commit
}
```

### FileStatus
```swift
struct FileStatus {
    let path: String
    let oldPath: String? // For renamed files
    let status: FileChangeType
    let isStaged: Bool
    let isConflicted: Bool
}

enum FileChangeType {
    case modified
    case added
    case deleted
    case renamed
    case copied
    case untracked
    case ignored
}
```

### Diff
```swift
struct Diff {
    let filePath: String
    let oldFilePath: String?
    let hunks: [DiffHunk]
    let isNewFile: Bool
    let isDeleted: Bool
    let isRenamed: Bool
}

struct DiffHunk {
    let oldStart: Int
    let oldLines: Int
    let newStart: Int
    let newLines: Int
    let lines: [DiffLine]
}

struct DiffLine {
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

enum DiffLineType {
    case context
    case added
    case removed
    case header
}

### Diff View Settings
```swift
struct DiffViewSettings {
    var viewMode: DiffViewMode
    var contextLines: Int
    var showLineNumbers: Bool
    var wordDiff: Bool
    var highlightWhitespace: Bool
    var showConnectionLines: Bool
    var fontSize: Double
    var theme: DiffTheme
    var wrapLines: Bool
}

enum DiffViewMode: String, CaseIterable {
    case unified = "Unified"
    case sideBySide = "Side-by-Side"
}

struct DiffTheme {
    let name: String
    let backgroundColor: Color
    let contextBackgroundColor: Color
    let addedBackgroundColor: Color
    let removedBackgroundColor: Color
    let modifiedBackgroundColor: Color
    let addedTextColor: Color
    let removedTextColor: Color
    let connectionLineColor: Color
}
```

### Side-by-Side Diff Row
```swift
struct SideBySideDiffRow {
    let oldLine: DiffLine?
    let newLine: DiffLine?
    let alignment: LineAlignment
    let changeBlockIndex: Int?
}

enum LineAlignment {
    case matched           // Lines are the same
    case added              // Only new line exists
    case removed            // Only old line exists
    case modified           // Lines are different
    case contextGap         // Unchanged context (collapsed)
}
```

### Diff Change Block
```swift
struct DiffChangeBlock {
    let id: UUID
    let startIndex: Int
    let endIndex: Int
    let type: ChangeBlockType
    let oldLines: [DiffLine]
    let newLines: [DiffLine]
    let connections: [ConnectionLine]
}

enum ChangeBlockType {
    case addition
    case deletion
    case modification
    case mixed
}

struct ConnectionLine {
    let fromRow: Int
    let toRow: Int
    let bezierPath: Path
}
```

### Diff Highlighting
```swift
struct WordDiffSegment {
    let content: String
    let type: WordDiffType
}

enum WordDiffType {
    case unchanged
    case added
    case removed
}

extension DiffLine {
    func toWordDiffSegments() -> [WordDiffSegment] {
        // Parse line into word-level segments
        // Return array of segments with diff type
    }
}
```

### Remote
```swift
struct Remote {
    let name: String
    let fetchURL: String
    let pushURL: String
}
```

### Stash
```swift
struct Stash {
    let index: Int
    let message: String
    let branch: String?
    let commit: Commit
}
```

### Tag
```swift
struct Tag {
    let name: String
    let commitHash: String
    let message: String?
    let isAnnotated: Bool
    let date: Date?
}
```

### Conflict
```swift
struct Conflict {
    let filePath: String
    let currentVersion: String
    let incomingVersion: String
    let baseVersion: String?
    let markers: ConflictMarkers
}

struct ConflictMarkers {
    let currentStart: String
    let separator: String
    let incomingEnd: String
}
```

### Submodule
```swift
struct Submodule {
    let name: String
    let path: String
    let url: String
    let commitHash: String
    let branch: String?
    let isInitialized: Bool
}
```

### AutomationConfig
```swift
struct AutomationConfig {
    var commitPrefixEnabled: Bool
    var defaultPrefix: String?
    var availablePrefixes: [String]
    var scripts: [String: ScriptConfig]
    var protectedBranches: [String]
}

struct ScriptConfig {
    let path: String
    var enabled: Bool
    var blockOnError: Bool
}
```

### GitOperationResult
```swift
struct GitOperationResult {
    let success: Bool
    let output: String
    let error: String?
    let exitCode: Int32
}

struct GitPullResult: GitOperationResult {
    let filesChanged: Int
    let insertions: Int
    let deletions: Int
    let hasConflicts: Bool
}

struct GitPushResult: GitOperationResult {
    let pushedCommits: Int
    let pushedTags: Int
}
```

---

## Git Service API

### Core Repository Operations
```swift
protocol GitRepositoryService {
    func clone(from url: URL, to destination: URL) async throws -> GitOperationResult
    func initRepository(at path: URL) async throws -> GitOperationResult
    func openRepository(at path: URL) throws -> Repository
    func getRepositoryStatus() async throws -> [FileStatus]
}
```

### Branch Operations
```swift
protocol GitBranchService {
    func getAllBranches() async throws -> [Branch]
    func getLocalBranches() async throws -> [Branch]
    func getRemoteBranches() async throws -> [Branch]
    func getCurrentBranch() async throws -> Branch
    func createBranch(_ name: String, from commit: String?) async throws -> GitOperationResult
    func checkoutBranch(_ name: String) async throws -> GitOperationResult
    func deleteBranch(_ name: String, remote: Bool) async throws -> GitOperationResult
    func getMergedBranches(into branch: String) async throws -> [Branch]
    func getStaleBranches(olderThan days: Int) async throws -> [Branch]
    func mergeBranch(_ name: String, strategy: MergeStrategy) async throws -> GitOperationResult
    func rebase(onto branch: String) async throws -> GitOperationResult
    func interactiveRebase(from commit: String) async throws -> GitOperationResult
    func reset(to commit: String, mode: ResetMode) async throws -> GitOperationResult
}

enum MergeStrategy {
    case fastForward
    case noFastForward
    case squash
}

enum ResetMode {
    case soft
    case mixed
    case hard
}
```

### Commit Operations
```swift
protocol GitCommitService {
    func getCommitHistory(limit: Int?) async throws -> [Commit]
    func getCommit(hash: String) async throws -> Commit
    func commit(message: String, files: [String]) async throws -> GitOperationResult
    func amendCommit(message: String, files: [String]) async throws -> GitOperationResult
    func cherryPick(commit: String) async throws -> GitOperationResult
    func revert(commit: String) async throws -> GitOperationResult
}
```

### Fetch & Pull Operations
```swift
protocol GitFetchPullService {
    func fetch(remote: String?, refspec: String?) async throws -> GitOperationResult
    func fetchAll() async throws -> GitOperationResult
    func pull(remote: String?, strategy: PullStrategy) async throws -> GitPullResult
}

enum PullStrategy {
    case merge
    case rebase
}
```

### Push Operations
```swift
protocol GitPushService {
    func push(remote: String?, branch: String?, force: Bool) async throws -> GitPushResult
    func pushTags(remote: String?) async throws -> GitPushResult
    func setUpstream(remote: String, branch: String) async throws -> GitOperationResult
}
```

### Diff Operations
```swift
protocol GitDiffService {
    func getDiff() async throws -> [Diff]
    func getStagedDiff() async throws -> [Diff]
    func getDiff(file: String) async throws -> Diff
    func getDiff(commit1: String, commit2: String) async throws -> [Diff]
    func getBlame(file: String) async throws -> [BlameLine]
}

struct BlameLine {
    let commit: Commit
    let lineNumber: Int
    let content: String
}
```

### Stash Operations
```swift
protocol GitStashService {
    func listStashes() async throws -> [Stash]
    func createStash(message: String?, includeUntracked: Bool) async throws -> GitOperationResult
    func applyStash(index: Int) async throws -> GitOperationResult
    func dropStash(index: Int) async throws -> GitOperationResult
    func popStash() async throws -> GitOperationResult
    func showStash(index: Int) async throws -> [Diff]
}
```

### Tag Operations
```swift
protocol GitTagService {
    func listTags() async throws -> [Tag]
    func createTag(name: String, message: String?, commit: String?) async throws -> GitOperationResult
    func deleteTag(name: String, remote: Bool) async throws -> GitOperationResult
}
```

### Remote Operations
```swift
protocol GitRemoteService {
    func listRemotes() async throws -> [Remote]
    func addRemote(name: String, url: String) async throws -> GitOperationResult
    func removeRemote(name: String) async throws -> GitOperationResult
    func updateRemoteURL(name: String, url: String) async throws -> GitOperationResult
}
```

### Conflict Resolution
```swift
protocol GitConflictService {
    func getConflicts() async throws -> [Conflict]
    func resolveConflict(filePath: String, version: ConflictVersion) async throws -> GitOperationResult
    func abortMerge() async throws -> GitOperationResult
    func abortRebase() async throws -> GitOperationResult
    func continueMerge() async throws -> GitOperationResult
    func continueRebase() async throws -> GitOperationResult
}

enum ConflictVersion {
    case current
    case incoming
    case manual
}
```

### Submodule Operations
```swift
protocol GitSubmoduleService {
    func listSubmodules() async throws -> [Submodule]
    func addSubmodule(url: String, path: String, branch: String?) async throws -> GitOperationResult
    func updateSubmodules(recursive: Bool) async throws -> GitOperationResult
    func removeSubmodule(name: String) async throws -> GitOperationResult
}
```

### Ignore File Management
```swift
protocol GitIgnoreService {
    func getIgnorePatterns() async throws -> [String]
    func addIgnorePattern(_ pattern: String) async throws -> GitOperationResult
    func removeIgnorePattern(_ pattern: String) async throws -> GitOperationResult
}
```

### Automation Operations
```swift
protocol GitAutomationService {
    func runScript(at path: String, event: ScriptEvent) async throws -> GitOperationResult
}

enum ScriptEvent: String {
    case preCommit = "pre-commit"
    case postCommit = "post-commit"
    case prePush = "pre-push"
    case postPush = "post-push"
    case prePull = "pre-pull"
    case postPull = "post-pull"
    case preMerge = "pre-merge"
    case postMerge = "post-merge"
}
```

### Unified Git Service
```swift
protocol GitService: GitRepositoryService,
                     GitBranchService,
                     GitCommitService,
                     GitFetchPullService,
                     GitPushService,
                     GitDiffService,
                     GitStashService,
                     GitTagService,
                     GitRemoteService,
                     GitConflictService,
                     GitSubmoduleService,
                     GitIgnoreService,
                     GitAutomationService {
    var repositoryPath: URL { get }
    func setRepositoryPath(_ path: URL) throws
}
```

---

## UI Components

### Main Window Structure
```
┌────────────────────────────────────────────────────────────┐
│ [📁 MyRepo ▼]              [⚙️ Settings]          [⏱️]   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────┬──────────────────────────────────────────┐  │
│  │          │                                          │  │
│  │ Sidebar  │         Main Content Area               │  │
│  │          │                                          │  │
│  │ [📊]     │  ┌─────────────────────────────────┐   │  │
│  │ Overview │  │                                 │   │  │
│  │          │  │  Repository Status              │   │  │
│  │ [📝]     │  │  Branch: main (↑↑ 2 commits)   │   │  │
│  │ Changes  │  │  Modified: 3 files              │   │  │
│  │          │  │  Untracked: 2 files             │   │  │
│  │ [🌿]     │  └─────────────────────────────────┘   │  │
│  │ Branches │                                          │  │
│  │          │  ┌─────────────────────────────────┐   │  │
│  │ [📜]     │  │ [⬇️ Pull] [⬆️ Push] [🔄 Fetch]   │   │  │
│  │ History  │  └─────────────────────────────────┘   │  │
│  │          │                                          │  │
│  │ [🧹]     │  ┌─────────────────────────────────┐   │  │
│  │ Cleanup  │  │ Modified Files                  │   │  │
│  │          │  │ 🟡 src/main.swift               │   │  │
│  │ [🔧]     │  │ 🟡 src/helpers.swift            │   │  │
│  │ Automate │  │ 🔴 old_file.swift               │   │  │
│  │          │  │ 🔵 new_file.swift               │   │  │
│  │ [🔌]     │  │ 🟢 staged.swift                │   │  │
│  │ Remotes  │  └─────────────────────────────────┘   │  │
│  │          │                                          │  │
│  │ [🏷️]     │  ┌─────────────────────────────────┐   │  │
│  │ Tags     │  │ [Commit Changes]                │   │  │
│  │          │  │ Message: [_________________]    │   │  │
│  │ [📦]     │  │ Prefix: [FEAT ▼]                │   │  │
│  │ Stash    │  └─────────────────────────────────┘   │  │
│  │          │                                          │  │
│  │ [⚔️]     │                                          │  │
│  │ Conflicts│                                          │  │
│  └──────────┴──────────────────────────────────────────┘  │
│                                                            │
│ [Status Bar: Ready | Branch: main | ↑ 2 ↓ 0]           │
└────────────────────────────────────────────────────────────┘
```

### Tab Details

#### Overview Tab
- Repository summary (path, current branch, remotes)
- Quick actions: Pull, Push, Fetch
- Recent activity feed
- Status indicators (ahead/behind, conflicts, etc.)

#### Changes Tab
- File status list with color-coded indicators
- Stage/Unstage buttons per file or bulk
- Diff viewer (side-by-side or unified)
- Commit message editor with prefix selector
- Stash/create options

#### Branches Tab
- Local and remote branches in separate sections
- Current branch highlighted
- Create new branch dialog
- Checkout branch
- Merge/rebase options
- Delete branch (with safety checks)
- Compare branches

#### History Tab
- Commit graph (visual representation)
- Commit list with search/filter
- Commit details panel:
  - Full message
  - Author info
  - Files changed
  - Diff view
- Cherry-pick and revert actions
- Commit blame (per file)

#### Cleanup Tab
- Merged branches section (CGF-1.1)
- Stale branches section (CGF-1.2)
- Bulk selection checkboxes
- Delete actions with confirmations
- Protected branches configuration

#### Automate Tab (CGF-2)
- Commit prefix configuration
- Script hooks management:
  - pre-commit, post-commit
  - pre-push, post-push
  - pre-pull, post-pull
  - pre-merge, post-merge
- Script editor or path selector
- Enable/disable toggles
- Test script button
- Output viewer

#### Remotes Tab
- Remote list with URLs
- Add remote dialog
- Edit/remove remote options
- Fetch from specific remote
- Push/pull destination selector

#### Tags Tab
- Tag list with commit links
- Create tag dialog (annotated/lightweight)
- Push tags button
- Delete tag option

#### Stash Tab
- Stash list with messages
- Preview stashed changes
- Apply/Pop stash actions
- Drop stash option
- Create stash dialog

#### Conflicts Tab
- List of conflicted files
- Side-by-side diff view:
  - Current version
  - Incoming version
- Resolution buttons:
  - Accept current
  - Accept incoming
  - Manual merge editor
- Continue/Abort operation buttons
- Conflict markers explanation

### Dialogs & Sheets

#### Commit Dialog
```
┌──────────────────────────────────────┐
│ Commit Changes          [Cancel] [OK] │
├──────────────────────────────────────┤
│ Message:                              │
│ ┌──────────────────────────────────┐  │
│ │ [FEAT] Add new feature           │  │
│ │                                  │  │
│ └──────────────────────────────────┘  │
│                                       │
│ Prefix: [FEAT ▼]                      │
│                                       │
│ Staged: 3 files                       │
│ 🟢 file1.swift                        │
│ 🟢 file2.swift                        │
│ 🟢 file3.swift                        │
│                                       │
│ [Stage All] [Unstage All]            │
│                                       │
│ ☑ Amend previous commit              │
└──────────────────────────────────────┘
```

#### Branch Operations Dialog
```
┌──────────────────────────────────────┐
│ Create Branch          [Cancel] [OK] │
├──────────────────────────────────────┤
│ Branch name: [_____________]         │
│                                       │
│ Base branch: [main ▼]                │
│                                       │
│ ☑ Checkout after creation            │
└──────────────────────────────────────┘
```

#### Merge/Rebase Dialog
```
┌──────────────────────────────────────┐
│ Merge Branch            [Cancel] [OK] │
├──────────────────────────────────────┤
│ Merge [feature-branch ▼] into main  │
│                                       │
│ Strategy:                             │
│ ○ Fast-forward                       │
│ ● No fast-forward (create merge)      │
│ ○ Squash commits                     │
│                                       │
│ ☑ Pre-merge script enabled            │
└──────────────────────────────────────┘
```

#### Conflict Resolution Dialog
```
┌───────────────────────────────────────────────┐
│ Resolve Conflicts        [Abort] [Continue]  │
├───────────────────────────────────────────────┤
│ Conflicts: 2 files                            │
│                                               │
│ 📄 src/main.swift                             │
│ ┌─────────────────────────────────────────┐  │
│ │ 10  func main() {                      │  │
│ │ 11      print("Hello")                  │  │
│ │ 12+     print("Current version")        │  │
│ │ 13======                                │  │
│ │ 12-     print("Incoming version")       │  │
│ │ 13  }                                   │  │
│ └─────────────────────────────────────────┘  │
│                                               │
│ [Accept Current] [Accept Incoming] [Edit]    │
│                                               │
│ 📄 src/helpers.swift                          │
│ [Similar UI]                                  │
└───────────────────────────────────────────────┘
```

#### Diff Viewer Dialog (Side-by-Side)
```
┌─────────────────────────────────────────────────────────────────┐
│ src/main.swift              [Unified] [Side-by-Side▼] [✕]       │
├─────────────────────────────────────────────────────────────────┤
│ [⬆️ Prev] [⬇️ Next]  [+2, -1]  [⚙️] [📋 Copy] [💾 Export]    │
├─────────────────────────────┬───────────────────────────────────┤
│ ORIGIN/MAIN (HEAD)          │ WORKING DIRECTORY                  │
├─────────────────────────────┼───────────────────────────────────┤
│   1 │ func main() {       │   1 │ func main() {                │
│   2 │     let name = "Worl│   2 │     let name = "World"       │
│   3 │     print("Hello, \│   3 │     print("Hello, " + name)  │
│   4 │                      │   4 │                              │
│   5 │     print("Old")    │   5 │     print("Updated") 🟩     │
│   6 │                      │   6 │     print("New line") 🟩     │
│   7 │     var count = 5   │   7 │     var count = 10 🟡       │
│   8 │     for i in 0..<c │   8 │     for i in 0..<count {     │
│   9 │         print(i)    │   9 │         print(i)             │
│  10 │     }                │  10 │     }                        │
│  11 │                      │  11 │                              │
│  12 │     print("Removed")│  12 │     print("New line") 🟩    │
│  13 │     print("End")    │  13 │     print("End")              │
│  14 │ }                    │  14 │ }                            │
├─────────────────────────────┼───────────────────────────────────┤
│                     [━━━━━━━ Resizable Divider ━━━━━]          │
├─────────────────────────────┴───────────────────────────────────┤
│ Context: 3 lines [▼]  │  Syntax: Swift  │  Word Diff: [✓]      │
│                        │  Wrap Lines: [ ]  │  Ignore WS: [ ]   │
└─────────────────────────────────────────────────────────────────┘
```

#### Diff Viewer Dialog (Detailed Side-by-Side with Change Blocks)
```
┌──────────────────────────────────────────────────────────────────┐
│ README.md                      [Unified] [Side-by-Side▼] [✕]     │
├──────────────────────────────────────────────────────────────────┤
│ [⬆️ Prev Change] [⬇️ Next Change]  [+15, -7]  [⚙️ Settings]     │
├──────────────────────────────────────────────────────────────────┤
│ ┌──────────────────────────┐    ┌────────────────────────────┐   │
│ │ v1.2.3 (3 days ago)      │    │ Working Directory          │   │
│ ├──────────────────────────┤    ├────────────────────────────┤   │
│ │   1 │ # Cozy Git        │    │   1 │ # Cozy Git           │   │
│ │   2 │                    │    │   2 │                      │   │
│ │   3 │ A macOS Git client │    │   3 │ A macOS Git client   │   │
│ │   4 │                    │    │   4 │                      │   │
│ │   5 │ ## Features       │    │   5 │ ## Features          │   │
│ │   6 │                    │    │   6 │                      │   │
│ │ ┌─────────────────────┐ │    │ ┌─┬───────────────────────┤   │
│ │ │ 🟦 7 │ - Cleanup    │ │    │ │ ││                       │   │
│ │ │ 🟦 8 │ - Automate   │ │    │ │ ││                       │   │
│ │ └────────────────────┘ │    │ └─┴───────────────────────┤   │
│ │   9 │                    │    │   7 │                      │   │
│ │ ┌─┬────────────────────┐ │    │ ┌─┬───────────────────────┤   │
│ │ │🟥│ 10│ - Old feature │ │    │ │🟩││ 8│ - Cleanup          │ │   │
│ │ └─┴────────────────────┘ │    │ │🟩││ 9│ - Automate         │ │   │
│ │                          │    │ │🟩││ 10│ - View diffs       │ │   │
│ │                          │    │ │🟩││ 11│ - Side-by-side    │ │   │
│ │                          │    │ └─┴───────────────────────┤   │
│ │  11 │                    │    │  12 │                      │   │
│ └──────────────────────────┘    └────────────────────────────┘   │
│                                                                   │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│ 💡 Tip: Click connection lines to highlight changes             │
│                                                                   │
│ [📋 Copy Lines] [🔀 Revert Change] [✅ Stage Change]             │
└──────────────────────────────────────────────────────────────────┘
```

#### Diff Settings Panel
```
┌─────────────────────────────────────┐
│ Diff Settings              [Close] │
├─────────────────────────────────────┤
│ View Mode:                          │
│ ○ Unified                            │
│ ● Side-by-Side                       │
│                                     │
│ Context Lines:                      │
│ ○ 0 (No context)                    │
│ ○ 1                                 │
│ ● 3                                 │
│ ○ 5                                 │
│ ○ 10                                │
│                                     │
│ Options:                            │
│ ☑ Show line numbers                 │
│ ☑ Word-level diff                   │
│ ☑ Highlight whitespace changes     │
│ ☑ Show connection lines             │
│ ☐ Show all characters in whitespace │
│                                     │
│ Font Size:                          │
│ [━━━━●━━━━] 14pt                   │
│                                     │
│ Theme:                              │
│ [Default ▼]                         │
│                                     │
│ ☑ Remember per file type             │
└─────────────────────────────────────┘
```

### Component Library

#### File Status Row
- File icon
- File path/name
- Status badge (modified, added, deleted, etc.)
- Stage/Unstage toggle
- Diff preview button

#### Commit Item
- Commit hash (short)
- Author avatar (initials)
- Author name
- Date/time
- Commit message (first line)
- Files changed count
- Expand for details arrow

#### Branch Item
- Branch icon
- Branch name
- Last commit message
- Last commit date
- Action buttons (checkout, merge, delete)
- Status badges (current, protected, merged)

#### Diff Viewer

##### Unified Mode
```
┌────────────────────────────────────────────────────────┐
│ src/main.swift                       [Unified▼] [Copy]  │
├────────────────────────────────────────────────────────┤
│ 1   ┃ func main() {                                  │
│ 2   ┃     print("Hello, World!")                     │
│ 3 - ┃     print("Old version")   🟥                   │
│ 4 + ┃     print("New version")   🟩                   │
│ 5   ┃     print("Ending")                             │
│ 6   ┃ }                                              │
└────────────────────────────────────────────────────────┘
```

##### Side-by-Side Mode
```
┌───────────────────────────────────────────────────────────────┐
│ src/main.swift              [Side-by-Side▼] [Unified] [Copy]  │
├───────────────────────────────────────────────────────────────┤
│ OLD (origin/main)         │ NEW (working)                     │
├─────────────────────────────┼───────────────────────────────────┤
│  1 │ func main() {       │  1 │ func main() {                │
│  2 │     print("Hello,") │  2 │     print("Hello,")           │
│  3 │     print("World!")  │  3 │     print("World!")          │
│  4 │                      │  4 │     print("Line added") 🟩  │
│  5 │     print("Keep")   │  5 │     print("Keep")            │
│  6 │     print("Old")    │  6 │     print("New")  🟡         │
│  7 │                      │  7 │     print("Extra") 🟩        │
│  8 │     print("End")    │  8 │     print("End")             │
│  9 │ }                    │  9 │ }                            │
├─────────────────────────────┼───────────────────────────────────┤
│ [+2 lines, -1 lines]       │ [⬆️ Prev] [⬇️ Next] [⚙️ Settings]│
└───────────────────────────────────────────────────────────────┘
```

##### Features
- **View Modes**: Toggle between Unified and Side-by-Side
- **Syntax Highlighting**: Language-aware code highlighting
- **Line Numbers**: Synchronized line numbers in both panels
- **Change Indicators**:
  - 🟩 Green for added lines
  - 🟥 Red for removed lines
  - 🟡 Amber for modified lines
  - Connection lines between changes
- **Navigation**:
  - Jump to next/previous change
  - Scroll synchronization
  - Go to specific line number
- **Actions**:
  - Copy selected diff
  - Copy entire diff
  - Export diff as patch file
  - Stage/unstage specific changes
  - Revert specific change (context menu)
- **Context Control**:
  - Adjustable context lines (0, 1, 3, 5, 10)
  - Collapse unchanged sections
  - Expand all sections
- **Performance**:
  - Virtual scrolling for large files
  - Lazy loading for large diffs
  - Optimized rendering
- **Responsive**:
  - Resizable panel divider
  - Adapts to window size
  - Remember user preferences

##### Side-by-Side Specific Features
- **Synchronized Scrolling**: Both panels scroll together
- **Line Alignment**: Matched lines horizontally aligned
- **Visual Connections**: Curved lines showing changes between panels
- **Word-Level Diff**: Character-level highlighting within changed lines
- **Binary/Hex View**: For binary files
- **Image Diff**: Side-by-side comparison for image files

#### Progress Indicator
- Operation status (fetching, pushing, etc.)
- Progress bar
- Current item being processed
- Cancel button

### Design Guidelines Implementation
- **Colors**: Warm palette (orange #FF9500, amber #FFCC00, warm grays)
- **Corners**: 12px-16px radius for containers, 8px for buttons
- **Shadows**: Soft, diffuse shadows (opacity 0.1-0.2, blur 20px)
- **Fonts**: SF Pro (system default)
- **Icons**: SF Symbols (branch, commit, push, pull, etc.)
- **Spacing**: Generous padding (16-24px), consistent 8px grid
- **Buttons**: Rounded with hover states, primary action highlighted
- **Lists**: Alternating row colors on hover
- **Status Indicators**:
  - Green for success/safe
  - Orange for warnings
  - Red for danger/conflicts
  - Blue for information

---

## Development Workflow

### Phase Overview

| Phase | Name | Duration | Status | Dependencies |
|-------|------|----------|--------|--------------|
| 1 | Project Foundation & Infrastructure | Week 1 | ✅ | None |
| 2 | Repository Management | Week 2 | ✅ | Phase 1 |
| 3 | Basic Commit Workflow | Week 3 | ✅ | Phase 2 |
| 4 | Branch Management (CGF-1) | Week 4-5 | ✅ | Phase 3 |
| 5 | Fetch & Pull Operations | Week 6 | ✅ | Phase 4 |
| 6 | Push Operations | Week 7 | ✅ | Phase 5 |
| 7 | Merge & Rebase Operations | Week 8 | ✅ | Phase 6 |
| 8 | Unified Diff Viewer | Week 9 | ✅ | Phase 7 |
| 9 | Side-by-Side Diff Viewer | Week 10-11 | ✅ | Phase 8 |
| 10 | Commit Graph Visualization | Week 12 | ✅ | Phase 9 |
| 11 | Stash Operations | Week 13 | ✅ | Phase 10 |
| 12 | Tag Operations | Week 14 | ⬜ | Phase 11 |
| 13 | Remote Management | Week 15 | ⬜ | Phase 12 |
| 14 | Advanced Git Operations | Week 16 | ⬜ | Phase 13 |
| 15 | Submodule Support | Week 17 | ⬜ | Phase 14 |
| 16 | Ignore File Management | Week 18 | ⬜ | Phase 15 |
| 17 | Automation System (CGF-2) | Week 19-20 | ⬜ | Phase 16 |
| 18 | Polish & UX Enhancement | Week 21 | ⬜ | Phase 17 |
| 19 | Performance Optimization | Week 22 | ⬜ | Phase 18 |
| 20 | Accessibility & Localization | Week 23 | ⬜ | Phase 19 |
| 21 | Testing | Week 24-25 | ⬜ | Phase 20 |
| 22 | Documentation | Week 26 | ⬜ | Phase 21 |
| 23 | App Store Preparation | Week 27 | ⬜ | Phase 22 |
| 24 | Post-Launch Support | Ongoing | ⬜ | Phase 23 |

**Legend**: ⬜ Not Started | 🔄 In Progress | ✅ Complete | ⏸️ Blocked

---

### Phase 1: Project Foundation & Infrastructure (Week 1) ✅ DONE
**Dependencies**: None
**Deliverables**: Working app skeleton with basic architecture

#### Step 1.1: Project Setup ✅ DONE
- Create macOS SwiftUI project in Xcode ✅
- Configure build settings and deployment target (macOS 14.0+) ✅
- Set up code signing and entitlements ✅
- Create basic app info and icons ✅

#### Step 1.2: Architecture Setup ✅ DONE
- Create folder structure following MVVM pattern ✅
- Set up dependency injection container ✅
- Create service protocols for all git operations ✅
- Implement base error handling framework ✅
- Set up logging infrastructure ✅

#### Step 1.3: Core Data Models ✅ DONE
- Create `Repository` model ✅
- Create `Branch` model ✅
- Create `Commit` model ✅
- Create `FileStatus` model ✅
- Create `GitOperationResult` model ✅
- Implement Codable conformance for all models ✅

#### Step 1.4: GitService Foundation ✅ DONE
- Create `GitService` protocol with all method signatures ✅
- Implement `ShellExecutor` for running git commands ✅
- Set up process management with timeout handling ✅
- Implement stdout/stderr capturing ✅
- Create test repository for verification ✅

#### Step 1.5: Basic UI Shell ✅ DONE
- Create main window with sidebar layout ✅
- Implement navigation between tabs (placeholder views) ✅
- Add repository selector dropdown (placeholder) ✅
- Add settings menu item (placeholder) ✅
- Implement window size persistence ✅

**Completion Criteria**:
- [x] App builds and launches without errors ✅
- [x] Can open/close app ✅
- [x] Navigation between tabs works ✅
- [x] All service protocols defined ✅
- [x] Git command execution tested with simple command ✅

---

### Phase 2: Repository Management (Week 2) ✅ DONE
**Dependencies**: Phase 1
**Deliverables**: Can open, clone, and init repositories with status display

#### Step 2.1: Repository Operations ✅ DONE
- Implement `openRepository()` method ✅
- Implement `cloneRepository()` with progress tracking ✅
- Implement `initRepository()` method ✅
- Implement `getRepositoryStatus()` parsing `git status --porcelain` ✅
- Add repository path validation ✅

#### Step 2.2: File Status Parsing ✅ DONE
- Parse file status from git output ✅
- Create `FileChangeType` enum ✅
- Map git status codes to model types ✅
- Handle renamed and copied files ✅
- Implement untracked file detection ✅

#### Step 2.3: Repository State Management ✅ DONE
- Create `RepositoryViewModel` ✅
- Implement Combine publishers for repository changes ✅
- Handle repository switching ✅
- Manage repository state (loading, error, ready) ✅
- Implement recent repositories tracking ✅

#### Step 2.4: Overview Tab UI ✅ DONE
- Build repository summary display ✅
- Show current branch name ✅
- Show remote status (ahead/behind counts) ✅
- Display last commit info ✅
- Add quick action buttons (Pull, Push, Fetch) ✅
- Implement empty state design ✅

#### Step 2.5: Changes Tab - File List ✅ DONE
- Build file list UI with status indicators ✅
- Implement stage/unstage buttons per file ✅
- Add color-coded status badges ✅
- Implement file filtering (modified, added, deleted, untracked) ✅
- Add file search functionality ✅
- Handle empty repository state ✅

#### Step 2.6: Repository Selector ✅ DONE
- Build repository picker dropdown ✅
- Implement "Open Repository" file dialog ✅
- Implement "New Repository" option ✅
- Display recent repositories ✅
- Add repository path display ✅
- Handle invalid repository errors ✅

**Completion Criteria**:
- [x] Can open any valid git repository ✅
- [x] Can clone a repository from URL ✅
- [x] Can initialize new repository ✅
- [x] File status displays correctly ✅
- [x] Can stage/unstage files ✅
- [x] Overview shows repository information ✅
- [x] Repository selector works smoothly ✅

---

### Phase 3: Basic Commit Workflow (Week 3) ✅ DONE
**Dependencies**: Phase 2
**Deliverables**: Can create commits with message editor

#### Step 3.1: Stage Operations ✅ DONE
- Implement `stageFiles()` method ✅
- Implement `unstageFiles()` method ✅
- Implement `stageAll()` and `unstageAll()` ✅
- Handle staging deleted files ✅
- Test with various file types ✅

#### Step 3.2: Commit Operations ✅ DONE
- Implement `createCommit()` method ✅
- Add support for staged files only ✅
- Handle empty message validation ✅
- Implement commit error handling ✅
- Add pre-commit hook support placeholder ✅

#### Step 3.3: Commit Dialog UI ✅ DONE
- Design commit message editor ✅
- Add character/line count ✅
- Implement commit button ✅
- Add cancel button ✅
- Show staged files summary ✅
- Add "Amend" checkbox (disabled for now) ✅

#### Step 3.4: Integration with Changes Tab ✅ DONE
- Connect commit dialog to Changes tab ✅
- Pass staged files to commit ✅
- Display commit success/error feedback ✅
- Update file status after commit ✅
- Clear message on success ✅

#### Step 3.5: Commit History - Basic ✅ DONE
- Implement `getCommitHistory()` method ✅
- Parse git log output ✅
- Create basic commit list display ✅
- Show commit hash, message, author, date ✅
- Implement pagination (load more on scroll) ✅

#### Step 3.6: History Tab UI ✅ DONE
- Build commit list with `List` view ✅
- Add search/filter functionality ✅
- Implement commit detail view (sheet) ✅
- Show commit full message ✅
- Display affected files list ✅

**Completion Criteria**:
- [x] Can stage/unstage files ✅
- [x] Can create commits with messages ✅
- [x] Commit history displays correctly ✅
- [x] Can view commit details ✅
- [x] Errors handled gracefully ✅
- [x] UI updates after operations ✅

---

### Phase 4: Branch Management (Week 4-5) ✅ DONE
**Dependencies**: Phase 3
**Deliverables**: Full branch operations including CGF-1 features

#### Step 4.1: Branch Listing ✅ DONE
- Implement `getLocalBranches()` method ✅
- Implement `getRemoteBranches()` method ✅
- Parse git branch output ✅
- Identify current branch ✅
- Track branch commit hashes ✅

#### Step 4.2: Branch Operations ✅ DONE
- Implement `createBranch()` method ✅
- Implement `checkoutBranch()` method ✅
- Handle uncommitted changes warning ✅
- Implement branch deletion (local) ✅
- Implement branch deletion (remote) ✅
- Add branch rename functionality ✅

#### Step 4.3: Branches Tab UI ✅ DONE
- Build branch list with sections (local/remote) ✅
- Show current branch indicator ✅
- Add branch icons (SF Symbols) ✅
- Display branch metadata (last commit, date) ✅
- Implement branch selection ✅

#### Step 4.4: Branch Actions UI ✅ DONE
- Add "New Branch" button ✅
- Create branch creation dialog ✅
- Add "Checkout" action per branch ✅
- Add "Delete" action with confirmation ✅
- Implement branch comparison view (basic info in detail panel) ✅

#### Step 4.5: Merged Branch Detection (CGF-1.1) ✅ DONE
- Implement `getMergedBranches()` method ✅
- Parse `git branch --merged` output ✅
- Filter protected branches ✅
- Display merged branches in separate section ✅
- Add bulk selection checkboxes ✅

#### Step 4.6: Stale Branch Detection (CGF-1.2) ✅ DONE
- Implement `getStaleBranches()` method ✅
- Parse `git for-each-ref` for dates ✅
- Filter by age threshold (default 90 days) ✅
- Display branch age in UI ✅
- Make threshold configurable in settings ✅

#### Step 4.7: Branch Cleanup UI ✅ DONE
- Create Cleanup tab ✅
- Add merged branches section with checkboxes ✅
- Add stale branches section with checkboxes ✅
- Implement "Delete Selected" button ✅
- Add protection warning for protected branches ✅
- Show confirmation dialog before deletion ✅

#### Step 4.8: Protected Branches Configuration ✅ DONE
- Add settings for protected branches (via Branch.isProtected property) ✅
- Implement add/remove protected branches (via model) ✅
- Store in user preferences (model-based) ✅
- Apply protection logic throughout app ✅
- Warn before deleting protected branch ✅

**Completion Criteria**:
- [x] All branch operations work ✅
- [x] Can create, checkout, rename, delete branches ✅
- [x] Merged branches detection works ✅
- [x] Stale branches detection works ✅
- [x] Can delete merged/stale branches in bulk ✅
- [x] Protected branches properly protected ✅
- [x] Branch UI is intuitive and polished ✅

---

### Phase 5: Fetch & Pull Operations (Week 6) ✅ DONE
**Dependencies**: Phase 4
**Deliverables**: Can fetch and pull from remote repositories

#### Step 5.1: Fetch Operations ✅ DONE
- Implement `fetch()` method (all remotes) ✅
- Implement `fetch(remote:)` method (specific remote) ✅
- Parse fetch output for new commits ✅
- Update remote tracking branches ✅
- Handle network errors and timeouts ✅

#### Step 5.2: Pull Operations - Merge ✅ DONE
- Implement `pull(merge:)` method ✅
- Handle automatic merge ✅
- Detect and report merge conflicts ✅
- Parse pull output for statistics ✅
- Handle remote tracking setup ✅

#### Step 5.3: Pull Operations - Rebase ✅ DONE
- Implement `pull(rebase:)` method ✅
- Handle rebase conflicts ✅
- Detect rebase in progress ✅
- Provide rebase progress feedback ✅
- Compare to merge strategy ✅

#### Step 5.4: Network Progress Tracking ✅ DONE
- Implement progress publisher for network ops ✅
- Show progress bar during fetch/pull ✅
- Display bytes transferred (if available) ✅
- Allow cancellation of operations (basic) ✅
- Show estimated time remaining (basic) ✅

#### Step 5.5: Pull Dialog UI ✅ DONE
- Create pull dialog with strategy selection ✅
- Add "Fast-forward" vs "Rebase" radio buttons ✅
- Show "Set upstream" checkbox ✅
- Display fetch/pull options ✅
- Add "Show details" for operation log ✅

#### Step 5.6: Integration ✅ DONE
- Add Pull button to Overview tab ✅
- Add Pull button to Branches tab ✅
- Show ahead/behind counts after pull ✅
- Update commit history automatically ✅
- Handle pull errors gracefully ✅

#### Step 5.7: Auto-Fetch ✅ DONE
- Implement periodic auto-fetch (configurable) ✅
- Add user setting for auto-fetch interval ✅
- Show notification on new remote commits (basic) ✅
- Allow manual refresh button ✅
- Cache remote status to avoid excessive fetches ✅

**Completion Criteria**:
- [x] Fetch from remote works ✅
- [x] Pull with merge works ✅
- [x] Pull with rebase works ✅
- [x] Progress tracking displays correctly ✅
- [x] Can cancel operations (basic) ✅
- [x] Errors handled with user-friendly messages ✅
- [x] Auto-fetch works when enabled ✅

---

### Phase 6: Push Operations (Week 7) ✅ DONE
**Dependencies**: Phase 5
**Deliverables**: Can push commits and tags to remote

#### Step 6.1: Push Operations ✅ DONE
- Implement `push()` method (current branch) ✅
- Implement `push(branch:)` method (specific branch) ✅
- Handle force push with safety warning ✅
- Implement `setUpstream()` method ✅
- Parse push output for statistics ✅

#### Step 6.2: Tag Push Operations ✅ DONE
- Implement `pushTags()` method ✅
- Support selective tag pushing ✅
- Handle tag conflicts ✅
- Display pushed tags count ✅

#### Step 6.3: Push Progress Tracking ✅ DONE
- Implement progress publisher for push ✅
- Show progress bar during push ✅
- Display bytes transferred ✅
- Allow cancellation of operations ✅
- Show pushed commits count ✅

#### Step 6.4: Push Dialog UI ✅ DONE
- Create push dialog with options ✅
- Add "Force Push" checkbox with warning ✅
- Add "Push Tags" checkbox ✅
- Display remote branch selection ✅
- Show "Set upstream" option ✅

#### Step 6.5: Push Integration ✅ DONE
- Add Push button to Overview tab ✅
- Add Push button to Branches tab ✅
- Show ahead/behind counts update ✅
- Add push to tag details view ✅
- Handle push errors (auth, conflicts) ✅

#### Step 6.6: Force Push Safety ✅ DONE
- Add warning dialog for force push ✅
- Display commits that will be overwritten ✅
- Require double confirmation ✅
- Log force push events ✅
- Add setting to disable force push ✅

**Completion Criteria**:
- [x] Can push commits to remote
- [x] Can push tags to remote
- [x] Force push works with proper warnings
- [x] Progress tracking displays correctly
- [x] Can set upstream branch
- [x] All push errors handled gracefully

**Status**: COMPLETED

**Files Created**:
- `CozyGit/Models/PushResult.swift` - Push result model with PushOptions
- `CozyGit/Views/Dialogs/PushOptionsDialog.swift` - Push dialog with force push warning

**Files Modified**:
- `CozyGit/Services/GitService.swift` - Added pushWithOptions(), pushTags(), parsePushOutput(), countPushedTags()
- `CozyGit/Services/Protocols/GitServiceProtocol.swift` - Added push method signatures
- `CozyGit/ViewModels/RepositoryViewModel.swift` - Added pushWithOptions(), pushTags() methods
- `CozyGit/Views/Tabs/OverviewTab.swift` - Integrated PushOptionsDialog sheet

---

### Phase 7: Merge & Rebase Operations (Week 8) ✅ DONE
**Dependencies**: Phase 6
**Deliverables**: Can merge and rebase branches with conflict handling

#### Step 7.1: Merge Operations ✅ DONE
- Implement `mergeBranch()` method ✅
- Support fast-forward merge ✅
- Support no-fast-forward (create merge commit) ✅
- Support squash merge ✅
- Detect merge conflicts ✅
- Handle merge conflicts ✅

#### Step 7.2: Rebase Operations ✅ DONE
- Implement `rebase(onto:)` method ✅
- Detect rebase conflicts ✅
- Handle rebase in progress state ✅
- Support rebase continue/abort ✅
- Parse rebase progress output ✅

#### Step 7.3: Interactive Rebase (Basic) ✅ DONE
- Implement `interactiveRebase(from:)` method ✅
- Parse rebase TODO list ✅
- Show rebase plan to user ✅
- Allow commit reordering (UI placeholder) ✅
- Allow commit squashing (UI placeholder) ✅

#### Step 7.4: Merge/Rebase Dialogs UI ✅ DONE
- Create merge dialog with branch selector ✅
- Add merge strategy radio buttons ✅
- Create rebase dialog with target branch ✅
- Add pre-merge/rebase script checkbox ✅
- Show operation progress ✅

#### Step 7.5: Conflict Detection ✅ DONE
- Implement `detectConflicts()` method ✅
- Parse git status for conflict markers ✅
- List conflicted files ✅
- Track merge vs rebase conflicts ✅
- Show conflict count to user ✅

#### Step 7.6: Conflict Actions ✅ DONE
- Implement `acceptCurrent()` method ✅
- Implement `acceptIncoming()` method ✅
- Implement `continueMerge()` method ✅
- Implement `continueRebase()` method ✅
- Implement `abortMerge()` method ✅
- Implement `abortRebase()` method ✅

#### Step 7.7: Conflicts Tab UI ✅ DONE
- Build Conflicts tab ✅
- List conflicted files with status ✅
- Show conflict count indicator ✅
- Add "Accept Current" and "Accept Incoming" buttons ✅
- Add "Continue" and "Abort" operation buttons ✅
- Link to manual conflict editor ✅

**Completion Criteria**:
- [x] Can merge branches (all strategies)
- [x] Can rebase branches
- [x] Conflicts detected correctly
- [x] Can resolve conflicts
- [x] Can abort merge/rebase
- [x] Conflicts tab provides clear guidance

**Status**: COMPLETED

**Files Created**:
- `CozyGit/Models/MergeResult.swift` - Merge result model with MergeStrategy enum and MergeOptions
- `CozyGit/Models/RebaseResult.swift` - Rebase result model with OperationState enum and ConflictedFile struct
- `CozyGit/Views/Dialogs/MergeDialog.swift` - Merge dialog with branch selection and strategy options
- `CozyGit/Views/Dialogs/RebaseDialog.swift` - Rebase dialog with continue/skip/abort actions

**Files Modified**:
- `CozyGit/Services/Protocols/GitServiceProtocol.swift` - Added GitMergeRebaseServiceProtocol with all merge/rebase methods
- `CozyGit/Services/GitService.swift` - Implemented merge, rebase, conflict detection and resolution methods
- `CozyGit/ViewModels/RepositoryViewModel.swift` - Added merge, rebase, and conflict resolution methods
- `CozyGit/Views/Tabs/BranchesTab.swift` - Integrated merge/rebase dialogs with operation state indicator

---

### Phase 8: Unified Diff Viewer (Week 9) ✅ DONE
**Dependencies**: Phase 7
**Deliverables**: Can view unified diffs with syntax highlighting

#### Step 8.1: Diff Parsing ✅ DONE
- Implement `getDiff()` method ✅
- Parse git diff output ✅
- Create `Diff`, `DiffHunk`, `DiffLine` models ✅
- Handle multiple file diffs ✅
- Parse line numbers and markers ✅

#### Step 8.2: Diff Data Structures ✅ DONE
- Enhance `Diff` model with metadata ✅
- Implement diff hunk parsing ✅
- Create diff line type mapping ✅
- Handle binary file diffs ✅
- Support context line parsing ✅

#### Step 8.3: Unified Diff UI - Basic ✅ DONE
- Create unified diff view component ✅
- Display diff with colored lines ✅
- Add line numbers ✅
- Implement basic syntax highlighting ✅
- Show file headers ✅
- Handle empty diffs ✅

#### Step 8.4: Syntax Highlighting ✅ DONE
- Implement basic lexer for common languages ✅
- Add syntax coloring for diff lines ✅
- Highlight keywords, strings, comments ✅
- Support multiple file types ✅
- Optimize highlighting performance ✅

#### Step 8.5: Diff Navigation ✅ DONE
- Add "Next Change" button ✅
- Add "Previous Change" button ✅
- Implement change line detection ✅
- Jump to specific line number ✅
- Scroll to change on load ✅
- Highlight current change ✅

#### Step 8.6: Diff Actions ✅ DONE
- Add "Copy Diff" button ✅
- Add "Copy Selection" feature ✅
- Implement "Export as Patch" feature ✅
- Add "Stage Change" action ✅
- Add "Revert Change" action (context menu) ✅

#### Step 8.7: Diff Settings - Basic ✅ DONE
- Create diff settings panel ✅
- Add context lines selector (0, 1, 3, 5, 10) ✅
- Add line numbers toggle ✅
- Add syntax highlight toggle ✅
- Persist diff settings ✅

#### Step 8.8: Integration ✅ DONE
- Show diff when clicking file in Changes tab ✅
- Show diff when clicking commit in History tab ✅
- Add diff view to commit details ✅
- Implement diff sheet navigation ✅
- Handle large file diffs ✅

**Completion Criteria**:
- [x] Unified diff displays correctly
- [x] Syntax highlighting works
- [x] Can navigate changes
- [x] Can copy/export diff
- [x] Settings persist correctly
- [x] Large files handled efficiently

**Status**: COMPLETED

**Files Created**:
- `CozyGit/Models/Diff.swift` - Diff, FileDiff, DiffHunk, DiffLine models with DiffOptions
- `CozyGit/Views/Components/UnifiedDiffView.swift` - Unified diff view with line numbers, colored changes, MultiFileDiffView
- `CozyGit/Utilities/SyntaxHighlighter.swift` - Basic syntax highlighting for Swift, JS, Python, Go

**Files Modified**:
- `CozyGit/Services/Protocols/GitServiceProtocol.swift` - Added GitDiffServiceProtocol with diff methods
- `CozyGit/Services/GitService.swift` - Implemented getDiff(), getDiffForFile(), getDiffForCommit(), diff parsing
- `CozyGit/ViewModels/RepositoryViewModel.swift` - Added diff methods
- `CozyGit/Views/Tabs/ChangesTab.swift` - Integrated UnifiedDiffView with file selection

---

### Phase 9: Side-by-Side Diff Viewer (Week 10-11) ✅ DONE
**Dependencies**: Phase 8
**Deliverables**: Full side-by-side diff with all advanced features

#### Step 9.1: Side-by-Side Layout
- Create dual-panel view structure
- Implement horizontal scrollbars for both panels
- Add resizable divider between panels
- Set up panel width constraints
- Implement minimum/maximum widths

#### Step 9.2: Line Alignment Algorithm
- Implement line matching algorithm
- Map old lines to new lines
- Handle added lines (only new)
- Handle removed lines (only old)
- Handle modified lines (both present)
- Optimize for performance

#### Step 9.3: Synchronized Scrolling
- Implement scroll offset tracking
- Sync both panels when scrolling
- Handle scroll events bidirectionally
- Debounce scroll events for performance
- Maintain scroll position on resize

#### Step 9.4: Connection Lines
- Implement bezier curve drawing
- Calculate connection paths
- Draw lines between matched changes
- Color code connections (add/remove/modify)
- Handle panel resize updates
- Optimize rendering (use Shape)

#### Step 9.5: Color Coding & Visuals
- Apply color scheme to both panels
- Highlight added lines (green)
- Highlight removed lines (red)
- Highlight modified lines (amber)
- Mark change blocks with background
- Add gutter markers (+/-)

#### Step 9.6: Side-by-Side UI Components
- Build panel with line numbers
- Add gutter for change indicators
- Implement line-by-line comparison
- Show file headers in both panels
- Handle empty file cases

#### Step 9.7: Word-Level Diff
- Implement word diff algorithm
- Split lines into words
- Match words between versions
- Highlight changed words
- Support word-level toggle

#### Step 9.8: Change Block Visualization
- Detect change blocks (continuous changes)
- Apply lighter background to blocks
- Add block indicators in gutter
- Highlight entire block on hover
- Support block collapse/expand

#### Step 9.9: Diff View Toggle
- Add "Unified" vs "Side-by-Side" toggle
- Maintain settings per view mode
- Remember last used mode
- Switch views seamlessly
- Preserve scroll position on toggle

#### Step 9.10: Side-by-Side Settings
- Extend settings panel
- Add word diff toggle
- Add connection lines toggle
- Add whitespace highlighting toggle
- Add "Show only changed" mode

#### Step 9.11: Performance Optimization
- Implement virtual scrolling for panels
- Render only visible lines
- Cache rendered hunks
- Lazy load syntax highlighting
- Optimize bezier path calculations
- Profile and optimize for large files

#### Step 9.12: Integration & Polish
- Integrate with file/commit views
- Add keyboard shortcuts
- Implement context menus
- Add tooltips
- Test with various file types
- Ensure smooth animations

**Completion Criteria**:
- [x] Side-by-side view displays correctly
- [x] Lines aligned properly
- [x] Scrolling synchronized smoothly
- [ ] Connection lines drawn accurately (optional - not implemented)
- [x] Word-level diff works
- [x] Performance acceptable for large files
- [x] All features toggleable
- [x] User experience is polished

**Files Created/Modified**:
- `CozyGit/Views/Components/SideBySideDiffView.swift` - Side-by-side diff viewer with word-level diff, line alignment, synchronized scrolling
- `CozyGit/Views/Tabs/ChangesTab.swift` - Added diff view mode toggle (Unified/Side-by-Side)
- `CozyGit/Views/Tabs/HistoryTab.swift` - Added diff viewer in CommitDetailSheet

---

### Phase 10: Commit Graph Visualization (Week 12) ✅ DONE
**Dependencies**: Phase 9
**Deliverables**: Visual branch/commit graph with parallel vertical lines like Fork/GitKraken

#### Step 10.1: Graph Data Model
- Create `CommitGraphNode` model with position (row, column)
- Create `GraphConnection` model for lines between nodes
- Track parent/child relationships for each commit
- Identify branch lanes (columns) for parallel branches
- Handle merge commits with multiple parents
- Sort commits topologically

#### Step 10.2: Lane Assignment Algorithm
- Implement lane assignment for branches
- Assign columns to parallel branches
- Minimize lane crossings
- Handle branch starts and ends
- Handle merge and branch points
- Reuse lanes when branches end

#### Step 10.3: Graph Renderer
- Create `CommitGraphView` SwiftUI view
- Draw vertical lane lines (parallel colored lines)
- Draw commit nodes as circles on lanes
- Draw connection lines between commits
- Use bezier curves for merges crossing lanes
- Color-code lanes by branch

#### Step 10.4: Graph Line Types
- Straight vertical lines for linear history
- Curved lines for merges (bezier paths)
- Dotted lines for branch start points
- Multiple incoming lines for merge commits
- Color transitions at merge points

#### Step 10.5: Commit Node Rendering
- Draw commit circles on graph lanes
- Highlight HEAD commit
- Mark merge commits (multiple parents)
- Mark branch/tag commits with indicators
- Show tooltips on hover with commit info
- Handle selection state

#### Step 10.6: Integration with History Tab
- Replace simple commit list with graph view
- Keep commit details panel on right side
- Synchronize graph selection with details
- Maintain search/filter functionality
- Filter graph to show matching commits

#### Step 10.7: Branch Colors
- Assign consistent colors to branches
- Use distinct colors for main, develop, feature branches
- Color lane lines by branch
- Color commit nodes by branch
- Add legend or branch labels

#### Step 10.8: Graph Navigation
- Scroll graph smoothly
- Implement virtual scrolling for large histories
- Jump to specific commit by hash
- Navigate to HEAD/branch tips
- Keyboard navigation (up/down arrows)

#### Step 10.9: Graph Interactions
- Click commit to select and show details
- Double-click to open full commit view
- Right-click context menu (checkout, cherry-pick, etc.)
- Hover to highlight related commits
- Drag to scroll

#### Step 10.10: Performance Optimization
- Render only visible graph portion
- Cache lane calculations
- Lazy render commit nodes
- Optimize for 10,000+ commit histories
- Use Metal/Core Animation for smooth rendering

#### Step 10.11: Graph Settings
- Toggle compact/expanded view
- Show/hide remote branches
- Show/hide tags on graph
- Adjust lane spacing
- Toggle branch labels

**Completion Criteria**:
- [x] Graph displays parallel branch lanes correctly
- [x] Commit nodes positioned on correct lanes
- [x] Merge lines curve smoothly between lanes
- [x] Branch colors are consistent and distinct
- [x] Selection syncs with commit details
- [x] Performance acceptable for large repos
- [x] Navigation is smooth and intuitive

**Additional Features Implemented**:
- [x] Branch/tag badges displayed inline with commit messages
- [x] Current branch highlighted with bold border
- [x] Double-click on branch badge to checkout
- [x] Remote branch checkout creates local tracking branch
- [x] `--all` flag added to show commits from all branches
- [x] Lane assignment prefers parent's lane for visual continuity
- [x] History tab layout: VSplitView with graph on top, HSplitView (files | details) on bottom
- [x] Changed files list shows file status icons and +/- counts

**Files Created/Modified**:
- `CozyGit/Views/Components/CommitGraphView.swift` - Complete commit graph with lane algorithm, branch badges, checkout support
- `CozyGit/Views/Tabs/HistoryTab.swift` - Integrated graph view with VSplitView layout, checkout handling, error alerts
- `CozyGit/Services/GitService.swift` - Added `--all` flag, improved checkout to get actual branch name after remote checkout

---

### Phase 11: Stash Operations (Week 13) ✅ DONE
**Dependencies**: Phase 10
**Deliverables**: Can create, view, and apply stashes

#### Step 11.1: Stash Operations
- Implement `createStash(message:)` method
- Implement `listStashes()` method
- Implement `applyStash(index:)` method
- Implement `popStash()` method
- Implement `dropStash(index:)` method
- Parse stash list output

#### Step 11.2: Stash Models
- Create `Stash` model
- Store stash message, branch, date
- Include commit reference
- Handle stash index tracking

#### Step 11.3: Stash Tab UI
- Build Stash tab view
- Create stash list with metadata
- Show stash message preview
- Display stash date and branch
- Add stash icons

#### Step 11.4: Stash Actions
- Add "Create Stash" button with message input
- Add "Apply" button per stash
- Add "Pop" button (apply + drop)
- Add "Drop" button with confirmation
- Add "Show Diff" action

#### Step 11.5: Stash Diff Preview
- Implement stash diff viewing
- Show stashed changes in unified view
- Show stashed changes in side-by-side view
- Use existing diff viewer

#### Step 11.6: Stash Options
- Add "Include untracked" checkbox
- Add "Keep index" option
- Add stash message editor
- Implement stash validation

#### Step 11.7: Integration
- Add "Stash Changes" button to Changes tab
- Show stash count indicator
- Auto-show conflicts on stash apply
- Handle stash apply errors

**Completion Criteria**:
- [x] Can create stashes with messages
- [x] Can list all stashes
- [x] Can apply/pop/drop stashes
- [x] Can view stash diffs
- [x] Stash options work correctly (include untracked)
- [x] UI is intuitive and clear

**Files Created/Modified**:
- `CozyGit/Views/Tabs/StashTab.swift` - New stash management tab with list, details, and diff views
- `CozyGit/ViewModels/MainViewModel.swift` - Added `stash` case to Tab enum
- `CozyGit/Views/MainView.swift` - Added StashTab to navigation
- `CozyGit/Services/Protocols/GitServiceProtocol.swift` - Added `getStashDiff(index:)` method
- `CozyGit/Services/GitService.swift` - Implemented `getStashDiff(index:)` method
- `CozyGit/Views/Tabs/ChangesTab.swift` - Added "Stash Changes" button and StashChangesSheet

---

### Phase 12: Tag Operations (Week 14)
**Dependencies**: Phase 11
**Deliverables**: Can create and manage tags

#### Step 11.1: Tag Operations
- Implement `listTags()` method
- Implement `createTag(name:message:commit:)` method
- Implement lightweight tags
- Implement annotated tags
- Implement `deleteTag(name:)` method
- Implement `pushTags()` method
- Parse tag list output

#### Step 11.2: Tag Models
- Create `Tag` model
- Store tag name, commit hash, message
- Track annotated vs lightweight
- Include tag date for annotated tags

#### Step 11.3: Tags Tab UI
- Build Tags tab view
- Create tag list with metadata
- Show tag commit reference
- Display tag message preview
- Add tag icons

#### Step 11.4: Tag Actions
- Add "New Tag" button with dialog
- Add name and message inputs
- Add commit selector
- Add "Delete" button with confirmation
- Add "Push" button per tag
- Add "Push All Tags" button

#### Step 11.5: Tag Details
- Show tag details in sheet
- Display full tag message
- Show commit information
- Link to commit in History tab
- Show diff from parent commit

#### Step 11.6: Integration
- Show tags in commit graph
- Add tag context menu on commits
- Display tags in branch list
- Show tag selector for operations

**Completion Criteria**:
- [ ] Can create lightweight tags
- [ ] Can create annotated tags
- [ ] Can delete tags
- [ ] Can push tags
- [ ] Tag details display correctly
- [ ] Tags shown in appropriate places

---

### Phase 13: Remote Management (Week 15)
**Dependencies**: Phase 12
**Deliverables**: Can manage repository remotes

#### Step 12.1: Remote Operations
- Implement `listRemotes()` method
- Implement `addRemote(name:url:)` method
- Implement `removeRemote(name:)` method
- Implement `updateRemoteURL(name:url:)` method
- Parse remote list output
- Validate remote URLs

#### Step 12.2: Remote Models
- Create `Remote` model
- Store remote name, fetch URL, push URL
- Handle separate fetch/push URLs

#### Step 12.3: Remotes Tab UI
- Build Remotes tab view
- Create remote list with URLs
- Show remote name and URLs
- Add remote icons

#### Step 12.4: Remote Actions
- Add "Add Remote" button with dialog
- Add name and URL inputs
- Add "Edit" button for URL
- Add "Delete" button with confirmation
- Add "Fetch from Remote" action

#### Step 12.5: Remote Details
- Show remote details in sheet
- Display fetch and push URLs
- Show fetch settings
- Add URL validation
- Test remote connectivity

#### Step 12.6: Integration
- Add remote selector to fetch/pull/push
- Show remote status in Overview
- Display remote in branch list
- Update operations to use selected remote

**Completion Criteria**:
- [ ] Can add/remove remotes
- [ ] Can update remote URLs
- [ ] Can fetch from specific remote
- [ ] Remote details display correctly
- [ ] URLs validated properly

---

### Phase 14: Advanced Git Operations (Week 16)
**Dependencies**: Phase 13
**Deliverables**: Reset, cherry-pick, revert, blame operations

#### Step 13.1: Reset Operations
- Implement `reset(commit:mode:)` method
- Support soft, mixed, hard resets
- Validate reset target
- Warn before destructive resets
- Handle uncommitted changes

#### Step 13.2: Cherry-Pick Operations
- Implement `cherryPick(commit:)` method
- Handle cherry-pick conflicts
- Support multiple commits
- Show cherry-pick progress
- Handle failed cherry-pick

#### Step 13.3: Revert Operations
- Implement `revert(commit:)` method
- Create revert commit
- Handle revert conflicts
- Show revert summary
- Allow revert of multiple commits

#### Step 13.4: Git Blame
- Implement `getBlame(file:)` method
- Parse blame output per line
- Map lines to commits
- Store commit info per line
- Handle renamed files

#### Step 13.5: Reset Dialog UI
- Create reset dialog
- Add commit selector
- Add mode radio buttons (soft/mixed/hard)
- Show commit preview
- Add destructive warning
- Require confirmation

#### Step 13.6: Cherry-Pick/Revert UI
- Add "Cherry-Pick" to commit context menu
- Add "Revert" to commit context menu
- Show confirmation dialog
- Display operation progress
- Show success/error feedback

#### Step 13.7: Blame View UI
- Create blame annotation view
- Show original code with annotations
- Display commit info per line (hover)
- Show author and date per line
- Add color coding by age
- Link to commit in history

#### Step 13.8: Integration
- Add reset button to History tab
- Integrate blame into file viewer
- Add cherry-pick to commit actions
- Add revert to commit actions
- Update History tab after operations

**Completion Criteria**:
- [ ] Reset works in all modes
- [ ] Cherry-pick works correctly
- [ ] Revert creates proper commits
- [ ] Blame displays accurately
- [ ] All destructive actions have warnings
- [ ] UI is clear about operations

---

### Phase 15: Submodule Support (Week 17)
**Dependencies**: Phase 14
**Deliverables**: Can manage git submodules

#### Step 14.1: Submodule Operations
- Implement `listSubmodules()` method
- Implement `addSubmodule(url:path:branch:)` method
- Implement `updateSubmodules(recursive:)` method
- Implement `removeSubmodule(name:)` method
- Parse submodule status output
- Handle submodule initialization

#### Step 14.2: Submodule Models
- Create `Submodule` model
- Store submodule name, path, URL
- Track commit hash and branch
- Track initialization status

#### Step 14.3: Submodule UI - Basic
- Add submodule section to Overview tab
- Display submodule list with status
- Show submodule paths and URLs
- Add submodule icons

#### Step 14.4: Submodule Actions
- Add "Add Submodule" button with dialog
- Add URL and path inputs
- Add "Update" button per submodule
- Add "Update All" button
- Add "Remove" button with confirmation

#### Step 14.5: Submodule Details
- Show submodule details in sheet
- Display submodule commit info
- Show branch and URL
- Link to submodule repository
- Show submodule diff status

#### Step 14.6: Integration
- Detect submodules on repository open
- Show submodule status indicators
- Add submodule to file list
- Handle submodule conflicts

**Completion Criteria**:
- [ ] Can add submodules
- [ ] Can update submodules
- [ ] Can remove submodules
- [ ] Submodule status displays correctly
- [ ] Can work with nested submodules

---

### Phase 16: Ignore File Management (Week 18)
**Dependencies**: Phase 15
**Deliverables**: Can manage .gitignore files

#### Step 15.1: Ignore Operations
- Implement `getIgnorePatterns()` method
- Implement `addIgnorePattern()` method
- Implement `removeIgnorePattern()` method
- Parse .gitignore file
- Handle missing .gitignore

#### Step 15.2: Ignore Models
- Create ignore pattern list structure
- Track pattern validity
- Store pattern source (global/local)

#### Step 15.3: Ignore UI - Basic
- Add .gitignore editor to Changes tab
- Display current ignore patterns
- Allow inline editing
- Add syntax highlighting for patterns

#### Step 15.4: Ignore Actions
- Add "Add Pattern" button with dialog
- Add "Quick Add" from file list (right-click)
- Add pattern validation
- Show pattern hints

#### Step 15.5: Integration
- Update file status when .gitignore changes
- Show ignored files in Changes tab (optional)
- Add "Show Ignored" toggle
- Filter out ignored files by default

**Completion Criteria**:
- [ ] Can add ignore patterns
- [ ] Can remove ignore patterns
- [ ] Can edit .gitignore directly
- [ ] Quick add from file list works
- [ ] File status updates correctly

---

### Phase 17: Automation System (CGF-2) (Week 19-20)
**Dependencies**: Phase 16
**Deliverables**: Commit prefixes and script hooks

#### Step 16.1: Commit Prefix System
- Implement prefix configuration storage
- Parse prefix settings from config
- Apply prefix to commit messages
- Validate prefix format
- Support prefix templates

#### Step 16.2: Commit Prefix UI
- Add prefix selector to commit dialog
- Create prefix configuration panel
- Allow custom prefix definitions
- Show prefix preview
- Add prefix history/recent

#### Step 16.3: Script Execution Engine
- Implement `runScript(at:event:)` method
- Handle script path validation
- Execute scripts with proper environment
- Capture stdout/stderr
- Handle script timeouts
- Parse exit codes

#### Step 16.4: Script Configuration
- Create `ScriptConfig` model
- Define all hook events
- Store script paths and settings
- Implement enable/disable per script
- Add "block on error" flag

#### Step 16.5: Automation Tab UI
- Build Automation tab view
- Show commit prefix section
- Show script hooks list
- Add enable/disable toggles
- Add configure buttons

#### Step 16.6: Script Configuration Dialogs
- Create script path selector
- Add browse button for file selection
- Add test script button
- Show script output preview
- Add script documentation

#### Step 16.7: Hook Integration
- Integrate pre-commit hook in commit flow
- Integrate post-commit hook
- Integrate pre-push/post-push hooks
- Integrate pre-pull/post-pull hooks
- Integrate pre-merge/post-merge hooks
- Handle hook failures

#### Step 16.8: Script Testing
- Add "Test Script" button
- Run script with test data
- Display script output
- Show execution time
- Highlight errors

#### Step 16.9: Configuration Persistence
- Save automation config to disk
- Load config on app launch
- Support per-repo and global config
- Validate config on load
- Add config import/export

#### Step 16.10: Integration
- Apply prefix when committing
- Run hooks at appropriate times
- Show hook execution progress
- Display hook errors to user
- Add hook indicators in status bar

**Completion Criteria**:
- [ ] Commit prefixes work correctly
- [ ] Script execution works for all hooks
- [ ] Scripts can be configured per hook
- [ ] Hooks run at appropriate times
- [ ] Hook failures handled properly
- [ ] Configuration persists correctly

---

### Phase 18: Polish & UX Enhancement (Week 21)
**Dependencies**: Phase 17
**Deliverables**: Polished, production-ready UI

#### Step 17.1: Design Guidelines Consistency
- Audit all UI against design guidelines
- Apply warm color palette consistently
- Ensure corner radius consistency
- Apply proper shadows throughout
- Use SF Symbols correctly
- Verify spacing and padding

#### Step 17.2: Animations & Transitions
- Add smooth view transitions
- Implement button hover effects
- Add loading spinners
- Add progress animations
- Implement sheet/present animations
- Add success/failure feedback

#### Step 17.3: Keyboard Shortcuts
- Implement all documented shortcuts
- Add shortcuts help panel (Cmd+?)
- Make shortcuts discoverable
- Test shortcuts throughout app
- Add conflict resolution for custom shortcuts

#### Step 17.4: Context Menus
- Add context menu to file list
- Add context menu to branch list
- Add context menu to commit list
- Add context menu to tag list
- Add context menu to stash list
- Add relevant actions per menu

#### Step 17.5: Tooltips & Help
- Add tooltips to buttons and icons
- Add help text to dialogs
- Create in-app help documentation
- Add "What's this?" buttons
- Link to help from error messages

#### Step 17.6: Loading States
- Add loading skeletons for lists
- Show loading spinners for operations
- Implement empty state views
- Add error state displays
- Make loading smooth and informative

#### Step 17.7: Drag & Drop
- Implement file drag to stage area
- Support drag files to commit dialog
- Add drag repository to app
- Handle drag errors gracefully

#### Step 17.8: Notifications
- Add toast notifications for operations
- Show success/error feedback
- Add notification center integration
- Make notifications dismissible
- Add notification history

**Completion Criteria**:
- [ ] Design guidelines applied throughout
- [ ] Animations are smooth
- [ ] All keyboard shortcuts work
- [ ] Context menus available where appropriate
- [ ] Tooltips provide helpful info
- [ ] Loading states are clear
- [ ] Notifications are helpful

---

### Phase 19: Performance Optimization (Week 22)
**Dependencies**: Phase 18
**Deliverables**: Optimized performance for large repositories

#### Step 18.1: Profiling
- Profile app with large repository (1000+ commits)
- Profile with large files (10,000+ lines)
- Identify performance bottlenecks
- Create performance benchmarks

#### Step 18.2: Diff Optimization
- Implement virtual scrolling for diff viewer
- Optimize diff parsing performance
- Cache diff hunks
- Lazy load syntax highlighting
- Optimize line alignment algorithm
- Profile and optimize connection lines

#### Step 18.3: List Optimization
- Implement virtual scrolling for all long lists
- Lazy load commit history
- Lazy load branch lists
- Implement incremental rendering
- Optimize filtering performance

#### Step 18.4: Cache Optimization
- Implement branch info cache
- Cache commit details
- Cache file status
- Cache remote status
- Implement cache invalidation strategy
- Add cache statistics

#### Step 18.5: Memory Management
- Optimize memory usage for large diffs
- Release unused resources
- Implement weak references where appropriate
- Profile memory allocations
- Fix memory leaks
- Optimize image handling

#### Step 18.6: Background Operations
- Move expensive operations to background queue
- Implement operation queuing
- Avoid blocking main thread
- Optimize Combine publishers
- Reduce UI update frequency

#### Step 18.7: Network Optimization
- Optimize git command execution
- Reduce unnecessary network calls
- Implement request throttling
- Optimize push/pull performance
- Better handle network timeouts

**Completion Criteria**:
- [ ] Large repository loads in <3 seconds
- [ ] Diff viewer handles 10,000+ lines smoothly
- [ ] Memory usage is reasonable
- [ ] No blocking UI operations
- [ ] Network operations are efficient

---

### Phase 20: Accessibility & Localization (Week 23)
**Dependencies**: Phase 19
**Deliverables**: Accessible and localizable app

#### Step 19.1: Accessibility Labels
- Add VoiceOver labels to all UI elements
- Provide descriptive labels for icons
- Add hints for complex controls
- Ensure all interactive elements are accessible

#### Step 19.2: Keyboard Navigation
- Ensure all UI is keyboard accessible
- Add tab order throughout app
- Implement full keyboard support
- Test navigation with keyboard only

#### Step 19.3: Screen Reader Support
- Test with VoiceOver
- Announce important state changes
- Provide audio feedback
- Test diff viewer accessibility
- Test conflict resolution accessibility

#### Step 19.4: High Contrast & Dynamic Type
- Test with high contrast mode
- Support increased text sizes
- Ensure contrast ratios are sufficient
- Test with all text sizes
- Adjust layouts for large text

#### Step 19.5: Localization Preparation
- Externalize all UI strings
- Prepare string catalogs
- Support RTL languages (prepare structure)
- Test with different locales
- Document localization process

#### Step 19.6: Diff Accessibility
- Announce line changes
- Provide keyboard diff navigation
- Announce diff view mode changes
- Make connection lines accessible
- Add audio feedback

**Completion Criteria**:
- [ ] VoiceOver works throughout app
- [ ] Fully keyboard accessible
- [ ] High contrast mode works
- [ ] Dynamic type supported
- [ ] Localization infrastructure ready

---

### Phase 21: Testing (Week 24-25)
**Dependencies**: Phase 20
**Deliverables**: Comprehensive test coverage

#### Step 20.1: Unit Tests Setup
- Set up XCTest framework
- Create test targets
- Set up test data fixtures
- Configure test environment

#### Step 20.2: GitService Tests
- Write tests for all git operations
- Test command parsing
- Test error handling
- Test with various repository states
- Mock git commands for testing

#### Step 20.3: Model Tests
- Test all data models
- Test JSON parsing/encoding
- Test model validation
- Test model comparisons

#### Step 20.4: Integration Tests
- Test full workflows (commit, push, pull)
- Test branch operations
- Test merge/rebase workflows
- Test conflict resolution
- Test stash operations

#### Step 20.5: UI Tests
- Test repository opening
- Test commit creation flow
- Test branch switching
- Test diff viewer navigation
- Test settings changes
- Test keyboard shortcuts

#### Step 20.6: Edge Case Tests
- Test empty repository
- Test no branches
- Test no commits
- Test binary files
- Test large files
- Test network failures
- Test concurrent operations
- Test corrupted .git directory
- Test permission issues

#### Step 20.7: Performance Tests
- Measure load times
- Measure diff rendering performance
- Test with 1000+ commits
- Test with 100+ files
- Verify memory usage
- Check for memory leaks

**Completion Criteria**:
- [ ] >80% code coverage
- [ ] All critical paths tested
- [ ] Edge cases handled
- [ ] Performance targets met
- [ ] All tests passing

---

### Phase 22: Documentation (Week 26)
**Dependencies**: Phase 21
**Deliverables**: Complete documentation

#### Step 21.1: User Documentation
- Write getting started guide
- Create feature tutorials
- Write keyboard shortcuts reference
- Document all UI elements
- Create troubleshooting guide

#### Step 21.2: In-App Help
- Add help menu items
- Create help modal views
- Add tooltips to all controls
- Add "What's new" for updates
- Link to online documentation

#### Step 21.3: Developer Documentation
- Document architecture decisions
- Document service protocols
- Document data models
- Create API documentation
- Document configuration format

#### Step 21.4: Release Notes
- Document new features
- Document bug fixes
- Document breaking changes
- Create version history
- Prepare changelog

#### Step 21.5: Screenshots & Marketing
- Capture app screenshots
- Create feature showcase
- Record demo videos
- Prepare App Store assets
- Create promotional materials

**Completion Criteria**:
- [ ] User documentation complete
- [ ] In-app help functional
- [ ] Developer docs written
- [ ] App Store assets ready
- [ ] All help content reviewed

---

### Phase 23: App Store Preparation (Week 27)
**Dependencies**: Phase 22
**Deliverables**: Ready for App Store submission

#### Step 22.1: App Store Connect Setup
- Create app record
- Configure pricing
- Set up categories
- Add screenshots
- Prepare description
- Set up keywords

#### Step 22.2: Code Signing & Build
- Configure code signing
- Create distribution certificate
- Prepare build archive
- Validate app structure
- Test archive install

#### Step 22.3: Compliance & Review
- Review App Store guidelines
- Check for prohibited content
- Verify privacy practices
- Prepare privacy policy
- Check accessibility requirements

#### Step 22.4: Beta Testing
- Create TestFlight build
- Invite beta testers
- Collect feedback
- Fix critical bugs
- Prepare release notes

#### Step 22.5: Final Polish
- Fix all known bugs
- Optimize app size
- Review performance
- Test on multiple macOS versions
- Final UI review

#### Step 22.6: Submission
- Prepare final build
- Upload to App Store Connect
- Submit for review
- Prepare marketing
- Plan launch

**Completion Criteria**:
- [ ] App passes all validation checks
- [ ] App Store listing complete
- [ ] Code signing configured
- [ ] Beta tested and feedback addressed
- [ ] All known issues resolved
- [ ] Ready for App Store review

---

### Phase 24: Post-Launch Support (Ongoing)
**Dependencies**: Phase 23
**Deliverables**: Ongoing maintenance and updates

#### Step 23.1: Monitoring
- Set up crash reporting
- Monitor app analytics
- Track user feedback
- Monitor App Store reviews
- Collect bug reports

#### Step 23.2: Bug Fixes
- Address reported bugs
- Fix crashes
- Resolve compatibility issues
- Release hotfixes
- Update documentation

#### Step 23.3: Feature Requests
- Collect feature requests
- Prioritize based on demand
- Plan future releases
- Implement high-priority features
- Engage with community

#### Step 23.4: Updates
- Maintain compatibility with macOS updates
- Update dependencies
- Add new Git features as they emerge
- Improve performance
- Enhance user experience

#### Step 23.5: Community
- Respond to user feedback
- Engage on GitHub/Social media
- Share tips and tricks
- Gather improvement suggestions
- Build user community

**Completion Criteria**:
- [ ] Monitoring systems in place
- [ ] Bug tracking system active
- [ ] Regular updates released
- [ ] Community engagement ongoing
- [ ] App store ratings maintained

---

## Phase Summary & Timeline

| Phase | Duration | Key Deliverables | Dependencies | Status |
|-------|----------|------------------|--------------|--------|
| 1 | Week 1 | App skeleton, architecture | None | ✅ DONE |
| 2 | Week 2 | Repo management, status display | Phase 1 | ✅ DONE |
| 3 | Week 3 | Commit workflow | Phase 2 | ✅ DONE |
| 4 | Week 4-5 | Branch management, CGF-1 | Phase 3 | ⬜ |
| 5 | Week 6 | Fetch & Pull | Phase 4 | ⬜ |
| 6 | Week 7 | Push operations | Phase 5 | ⬜ |
| 7 | Week 8 | Merge & Rebase | Phase 6 | ⬜ |
| 8 | Week 9 | Unified diff viewer | Phase 7 | ⬜ |
| 9 | Week 10-11 | Side-by-side diff | Phase 9 | ✅ |
| 10 | Week 12 | Commit graph visualization | Phase 10 | ✅ |
| 11 | Week 13 | Stash operations | Phase 10 | ⬜ |
| 12 | Week 14 | Tag operations | Phase 11 | ⬜ |
| 13 | Week 15 | Remote management | Phase 12 | ⬜ |
| 14 | Week 16 | Advanced Git ops | Phase 13 | ⬜ |
| 15 | Week 17 | Submodule support | Phase 14 | ⬜ |
| 16 | Week 18 | .gitignore management | Phase 15 | ⬜ |
| 17 | Week 19-20 | Automation, CGF-2 | Phase 16 | ⬜ |
| 18 | Week 21 | Polish & UX | Phase 17 | ⬜ |
| 19 | Week 22 | Performance | Phase 18 | ⬜ |
| 20 | Week 23 | Accessibility & i18n | Phase 19 | ⬜ |
| 21 | Week 24-25 | Testing | Phase 20 | ⬜ |
| 22 | Week 26 | Documentation | Phase 21 | ⬜ |
| 23 | Week 27 | App Store prep | Phase 22 | ⬜ |
| 24 | Ongoing | Support & updates | Phase 23 | ⬜ |

**Total Development Time**: ~7 months for full feature set (27 weeks), plus ongoing support

---

## Technical Considerations

### Git Command Execution
- Use `Process` API for running git commands
- Set working directory to repository path
- Capture stdout, stderr, and exit code
- Implement timeout for long-running operations
- Support environment variables for git configuration
- Handle process cancellation gracefully
- Stream output for long-running operations (clone, fetch, push)

### Error Handling
- Git not installed or not in PATH
- Repository not a valid git repository
- Network errors for remote operations
- Script execution failures
- Permission issues for branch deletion
- Merge conflicts detection and handling
- Invalid branch/commit references
- Authentication failures for remotes
- Disk space issues
- Lock file conflicts (.git/index.lock)

### Performance
- Cache branch, commit, and file information
- Debounce repository scanning (refresh on focus)
- Parallelize independent git operations
- Lazy load long lists (commits, branches, files)
- Pagination for commit history (load more on scroll)
- Diff rendering optimization (virtualization):
  - Implement virtual scrolling for both panels
  - Render only visible lines (plus buffer)
  - Cache rendered hunks to avoid re-computation
  - Use LazyVStack for efficient view updates
- Side-by-side diff specific optimizations:
  - Pre-calculate line alignment once per diff
  - Cache connection line paths
  - Defer word-level diff calculation until needed
  - Lazy syntax highlighting (only for visible lines)
  - Debounce scroll synchronization events
  - Use efficient data structures for line lookup
  - Optimize bezier path drawing for connection lines
- Background refresh for remote status
- Incremental updates for large diffs
- Throttle UI updates during operations
- Memory management:
  - Release diff data when view closes
  - Clear syntax highlighting cache periodically
  - Use weak references for large cached objects
- File loading:
  - Stream large files instead of loading entirely
  - Show progress for file reading
  - Cancel file loading on navigation away

### Security
- Validate script paths to prevent injection
- Restrict script execution to configured paths
- Warn before destructive operations (force push, reset, delete)
- Never store credentials in config
- Use macOS keychain for credentials
- Validate URLs before clone/add remote
- Sanitize user input for branch names, tags, etc.
- Prevent path traversal attacks
- Secure handling of sensitive data in logs

### Configuration Storage
- Use UserDefaults for app-wide settings
- Use file system for per-repo automation config
- Add .cozygit/ to .gitignore automatically
- Support config import/export
- Migrate old config versions
- Validate config on load
- Backup config before modifications

### User Preferences Storage

#### App-Wide Settings (UserDefaults)
```swift
struct AppPreferences {
    // Diff Viewer Settings
    var defaultDiffViewMode: DiffViewMode
    var defaultContextLines: Int
    var showLineNumbers: Bool
    var wordDiff: Bool
    var highlightWhitespace: Bool
    var showConnectionLines: Bool
    var diffFontSize: Double
    var diffTheme: String
    
    // UI Preferences
    var windowSize: CGSize
    var sidebarWidth: Double
    var showHiddenFiles: Bool
    
    // Behavior
    var autoFetch: Bool
    var autoFetchInterval: TimeInterval
    var confirmDestructiveActions: Bool
    var showStagedFilesFirst: Bool
    
    // Keyboard Shortcuts
    var customShortcuts: [String: String]
    
    // Recent Repositories
    var recentRepositories: [URL]
    var maxRecentRepositories: Int
}

// Per-Repository Settings
struct RepositoryPreferences {
    // Diff Viewer Overrides
    var diffViewMode: DiffViewMode?
    var contextLines: Int?
    var perFileDiffSettings: [String: DiffViewSettings]
    
    // Branch Preferences
    var defaultBranchName: String
    var protectedBranches: [String]
    
    // Commit Preferences
    var commitPrefixEnabled: Bool
    var defaultCommitPrefix: String
    
    // Automation
    var automationEnabled: Bool
    var scripts: [ScriptEvent: ScriptConfig]
}
```

### State Management
- Combine framework for reactive updates
- Centralized repository state
- Observable view models for UI
- Proper cleanup on repository switch
- Handle concurrent operations gracefully
- State restoration for app relaunch
- Persist UI preferences per repository

### Memory Management
- Efficient diff storage (don't keep all diffs in memory)
- Lazy loading of large file contents
- Clean up old command outputs
- Release resources on repository close
- Monitor memory usage for large repos

### Network Operations
- Progress tracking for fetch/push/pull
- Cancellation support
- Timeout configuration
- Retry logic for transient failures
- Offline mode detection
- Bandwidth estimation (optional)

### File System Monitoring
- Use FSEvents for watching repository changes
- Detect external git operations
- Auto-refresh UI on file changes
- Ignore .git directory from monitoring
- Debounce rapid file changes

### Accessibility
- VoiceOver support for all UI elements
- Keyboard navigation throughout app
- High contrast mode support
- Dynamic type sizing
- Clear focus indicators
- Screen reader-friendly labels
- Side-by-side diff viewer accessibility:
  - Announce line changes (added/removed/modified)
  - Provide audio feedback for navigation
  - Support keyboard-only navigation through changes
  - Announce connection line interactions
  - Provide descriptive labels for change blocks
  - Support VoiceOver rotor for diff sections
  - Announce when entering/leaving changed regions
  - Provide context for line numbers and file paths
  - Ensure sufficient contrast for color coding
  - Support text-to-speech for diff content
  - Provide alternative indicators beyond color
  - Support increased line spacing option
  - Announce diff view mode changes

### Localization
- English as primary language
- Prepare for future translations
- Use localized strings for UI
- Support date/time formatting
- Number formatting for counts

### User Experience
- Smooth animations and transitions
- Loading skeletons for async operations
- Toast notifications for operations
- Undo/redo for destructive operations (where possible)
- Keyboard shortcuts for power users
- Context menus for quick actions
- Tooltips for icons and buttons
- Onboarding guide for first-time users
- Diff viewer specific UX:
  - Smooth scroll synchronization between panels
  - Animated connection lines on hover
  - Fade in/out for collapsed sections
  - Quick hover preview for connection lines
  - Context menu on diff lines with actions
  - Drag-to-select across both panels
  - Pin the diff dialog for multi-file comparison
  - Quick toggle for word diff
  - Inline tooltips for line numbers
  - Visual feedback for staged/unstaged changes

### Keyboard Shortcuts

#### Global Shortcuts
- `Cmd+N` - New repository
- `Cmd+O` - Open repository
- `Cmd+W` - Close repository
- `Cmd+,` - Preferences
- `Cmd+K` - Quick actions palette

#### Changes Tab
- `Cmd+Enter` - Commit changes
- `Cmd+Shift+Enter` - Commit with message editor
- `Cmd+A` - Stage all
- `Cmd+Shift+A` - Unstage all
- `Cmd+D` - Show diff for selected file

#### Diff Viewer
- `Cmd+Shift+D` - Toggle diff view mode (Unified/Side-by-Side)
- `Cmd+Opt+↓` - Jump to next change
- `Cmd+Opt+↑` - Jump to previous change
- `Cmd+L` - Go to line number
- `Cmd+F` - Search in diff
- `Cmd+G` - Find next
- `Cmd+Shift+G` - Find previous
- `Cmd+Plus` - Increase font size
- `Cmd+Minus` - Decrease font size
- `Cmd+0` - Reset font size
- `Cmd+1` - Set 0 context lines
- `Cmd+2` - Set 1 context line
- `Cmd+3` - Set 3 context lines
- `Cmd+4` - Set 5 context lines
- `Cmd+5` - Set 10 context lines
- `Cmd+R` - Refresh diff
- `Cmd+E` - Toggle word diff
- `Cmd+W` - Toggle line wrapping
- `Cmd+C` - Copy selection
- `Cmd+Shift+C` - Copy entire diff
- `Cmd+S` - Export diff as patch
- `Cmd+T` - Toggle diff settings
- `Escape` - Close diff viewer
- `Left Arrow` - Scroll left (in side-by-side mode)
- `Right Arrow` - Scroll right (in side-by-side mode)
- `Opt+Left Arrow` - Scroll left by page
- `Opt+Right Arrow` - Scroll right by page
- `Ctrl+Cmd+Left` - Move divider left
- `Ctrl+Cmd+Right` - Move divider right
- `Ctrl+Cmd+1` - Show only old panel (side-by-side)
- `Ctrl+Cmd+2` - Show only new panel (side-by-side)
- `Ctrl+Cmd+0` - Show both panels (side-by-side)

#### Branches Tab
- `Cmd+B` - Create new branch
- `Cmd+Shift+B` - Checkout branch
- `Cmd+K` - Search branches
- `Cmd+Delete` - Delete selected branch

#### History Tab
- `Cmd+H` - Show commit history
- `Cmd+Shift+H` - Search commits
- `Cmd+Y` - Cherry-pick selected commit
- `Cmd+R` - Revert selected commit

#### General
- `Cmd+P` - Pull from remote
- `Cmd+Shift+P` - Push to remote
- `Cmd+Shift+F` - Fetch from remote
- `Cmd+R` - Refresh repository status
- `Cmd+/` - Show keyboard shortcuts help
- `F1` - Show help documentation

---

## Testing Strategy

### Unit Tests
- GitService command execution for all operations
- Branch model parsing logic
- Commit model parsing
- File status parsing
- Diff parsing and rendering
- Side-by-side diff line alignment algorithm
- Diff connection line calculation
- Word-level diff parsing
- Diff change block detection
- Diff virtual scrolling performance
- Diff settings serialization and persistence
- Automation config serialization
- Script path validation
- Conflict marker detection
- Stash entry parsing
- Tag model parsing
- Remote model parsing

### Integration Tests
- Repository clone/init/open workflow
- Full commit cycle (stage, commit, push, pull)
- Branch operations (create, checkout, merge, rebase, delete)
- Conflict detection and resolution
- Stash operations cycle
- Tag operations
- Remote management
- Submodule operations
- Commit prefix application
- Script execution on git events (all hooks)
- Configuration persistence
- Large repository handling (1000+ commits, 100+ files)

### UI Tests
- Repository selection and opening
- Navigation between all tabs
- File staging/unstaging
- Commit creation with message and prefix
- Branch operations dialogs
- Merge/rebase dialogs
- Conflict resolution interface
- Diff viewer interactions:
  - Toggle between unified and side-by-side modes
  - Navigate to next/previous change
  - Adjust context lines
  - Resize divider in side-by-side view
  - Click connection lines to highlight changes
  - Copy selected diff lines
  - Copy entire diff
  - Export diff as patch file
  - Open diff settings panel
  - Change diff theme
  - Test keyboard shortcuts (Cmd+Opt+↓, Cmd+Opt+↑)
  - Test synchronized scrolling in side-by-side mode
  - Test word-level diff highlighting
  - Test with various file types (code, text, markdown, images)
  - Test with large files (1000+ lines)
  - Test collapse/expand unchanged sections
- History viewing and filtering
- Stash operations
- Settings form interaction
- Error dialog display
- Progress indicators
- Context menu actions
- Keyboard shortcuts

### Performance Tests
- Large repository loading time
- Diff rendering for large files
- Commit history rendering (1000+ commits)
- Branch list rendering
- Pull/push operation timing
- Conflict resolution performance
- Stash list loading

### Edge Cases
- Empty repository
- Repository with no branches
- Repository with no commits
- Binary file handling
- Large file handling (>100MB)
- Network failures during push/pull
- Concurrent operations
- Invalid repository state
- Corrupted .git directory
- Permission issues
- Disk full scenarios
- Merge conflicts with many files
- Rebase with conflicts
- Force push protection
- Diff viewer edge cases:
  - Files with 10,000+ lines
  - Files with very long lines (>1000 characters)
  - Files with mixed line endings (CRLF vs LF)
  - Files with special characters and Unicode
  - Files with tabs vs spaces indentation
  - Binary files misidentified as text
  - Empty files diff
  - Files with only whitespace changes
  - Renamed files with content changes
  - Files moved between directories
  - Diff with no changes (identical commits)
  - Symlink handling in diffs
  - Git submodules in diff view
  - Image files diff comparison
  - Corrupted or unreadable files in diff
  - Memory pressure during large diff rendering

### User Acceptance Tests
- Real-world workflows from contributors
- Multiple repository types (monorepo, polyrepo, etc.)
- Different Git configurations
- Various remote providers (GitHub, GitLab, Bitbucket, etc.)
- Different collaboration scenarios
- Team usage patterns

---

## Dependencies

### Swift Package Manager
- No external dependencies initially (use system git)
- Consider later: SwiftGit2 for libgit2 bindings (if performance needed)

### System Requirements
- macOS 14.0+
- Git 2.30+ (for all features)
- Xcode 15+

---

## Feature Prioritization

### Priority 1: Core Functionality (MVP)
**Must Have**
- Repository open/close
- Git status (working directory changes)
- Stage/unstage files
- Create commits
- View commit history
- Pull from remote
- Push to remote
- Branch listing
- Checkout branches
- View diff (unified)

### Priority 2: Essential Git Operations
**Should Have**
- Fetch from remote
- Create new branches
- Merge branches
- Delete branches
- Stash operations
- Tag operations
- Remote management
- Conflicts detection and resolution
- Side-by-side diff view

### Priority 3: Cleanup & Automation (CGF-1, CGF-2)
**Should Have**
- Merged branch deletion
- Stale branch deletion
- Protected branches configuration
- Commit prefixes
- Script hooks (pre/post commit, push, pull)
- Automation configuration UI

### Priority 4: Advanced Features
**Nice to Have**
- Rebase operations
- Interactive rebase
- Cherry-pick commits
- Revert commits
- Git blame
- Submodule support
- Commit amend
- Reset operations

### Priority 5: Polish & UX
**Nice to Have**
- Keyboard shortcuts
- Context menus
- Advanced filtering
- Search functionality
- Drag-and-drop
- Animations
- Tooltips
- Help documentation

---

## Git Command Reference

### Repository Commands
| Operation | Git Command | Notes |
|-----------|-------------|-------|
| Clone | `git clone <url> <path>` | Progress tracking needed |
| Init | `git init` | For new repositories |
| Status | `git status --porcelain` | Parseable output |
| Remote -v | `git remote -v` | List all remotes |

### Branch Commands
| Operation | Git Command | Notes |
|-----------|-------------|-------|
| List local | `git branch` | Include formatting |
| List remote | `git branch -r` | Parseable |
| List all | `git branch -a` | Local + remote |
| Create | `git branch <name>` | Checkout separately |
| Checkout | `git checkout <name>` | Or `git switch` |
| Create & checkout | `git checkout -b <name>` | Convenience |
| Delete local | `git branch -d <name>` | Safety check |
| Delete remote | `git push origin --delete <name>` | Remote operation |
| Merge | `git merge <name>` | Various strategies |
| Rebase | `git rebase <name>` | Can be interactive |
| Reset | `git reset <mode> <commit>` | Destructive |

### Commit Commands
| Operation | Git Command | Notes |
|-----------|-------------|-------|
| Commit | `git commit -m "<msg>"` | With hooks |
| Amend | `git commit --amend -m "<msg>"` | Modify last |
| Log | `git log --oneline --graph` | With formatting |
| Show | `git show <commit>` | Full details |
| Cherry-pick | `git cherry-pick <commit>` | Apply commit |
| Revert | `git revert <commit>` | Reverse changes |

### File Operations
| Operation | Git Command | Notes |
|-----------|-------------|-------|
| Stage | `git add <file>` | Multiple files |
| Unstage | `git reset HEAD <file>` | Remove from index |
| Diff | `git diff` | Working dir vs staged |
| Diff staged | `git diff --cached` | Staged vs HEAD |
| Diff file | `git diff <file>` | Specific file |
| Blame | `git blame <file>` | Line-by-line |

### Remote Operations
| Operation | Git Command | Notes |
|-----------|-------------|-------|
| Fetch | `git fetch <remote>` | Update remote refs |
| Pull | `git pull` | Fetch + merge |
| Pull rebase | `git pull --rebase` | Fetch + rebase |
| Push | `git push` | Upload commits |
| Force push | `git push --force` | Dangerous |
| Push tags | `git push --tags` | All tags |
| Add remote | `git remote add <name> <url>` | New remote |

### Stash Commands
| Operation | Git Command | Notes |
|-----------|-------------|-------|
| Stash | `git stash push -m "<msg>"` | Save changes |
| Stash list | `git stash list` | Show all |
| Apply | `git stash apply` | Keep stash |
| Pop | `git stash pop` | Apply + drop |
| Drop | `git stash drop` | Remove |
| Show | `git stash show -p` | View changes |

### Tag Commands
| Operation | Git Command | Notes |
|-----------|-------------|-------|
| List | `git tag` | All tags |
| Create light | `git tag <name>` | Simple tag |
| Create annotated | `git tag -a <name> -m "<msg>"` | Full tag |
| Delete local | `git tag -d <name>` | Local only |
| Delete remote | `git push origin --delete <name>` | Remote |

### Submodule Commands
| Operation | Git Command | Notes |
|-----------|-------------|-------|
| Add | `git submodule add <url> <path>` | New submodule |
| Update | `git submodule update --init` | Clone/init |
| List | `git submodule status` | Show all |

### Ignore File
| Operation | Git Command | Notes |
|-----------|-------------|-------|
| View | `cat .gitignore` | Read file |
| Add | `echo "pattern" >> .gitignore` | Append |

---

## Future Enhancements

### Priority 1: Core Functionality (MVP)
**Must Have**
- Repository open/close
- Git status (working directory changes)
- Stage/unstage files
- Create commits
- View commit history
- Pull from remote
- Push to remote
- Branch listing
- Checkout branches
- View diff (unified)

### Priority 2: Essential Git Operations
**Should Have**
- Fetch from remote
- Create new branches
- Merge branches
- Delete branches
- Stash operations
- Tag operations
- Remote management
- Conflicts detection and resolution
- Side-by-side diff view

### Priority 3: Cleanup & Automation (CGF-1, CGF-2)
**Should Have**
- Merged branch deletion
- Stale branch deletion
- Protected branches configuration
- Commit prefixes
- Script hooks (pre/post commit, push, pull)
- Automation configuration UI

### Priority 4: Advanced Features
**Nice to Have**
- Rebase operations
- Interactive rebase
- Cherry-pick commits
- Revert commits
- Git blame
- Submodule support
- Commit amend
- Reset operations

### Priority 5: Polish & UX
**Nice to Have**
- Keyboard shortcuts
- Context menus
- Advanced filtering
- Search functionality
- Drag-and-drop
- Animations
- Tooltips
- Help documentation

---

## Future Enhancements

### Advanced Visualizations
- Commit graph with 3D rendering option (enhancement to Phase 10)
- Repository heatmap (activity visualization)
- Contributor statistics dashboard
- File change frequency visualization

### Collaboration Features
- Pull request integration (GitHub, GitLab, etc.)
- Issue tracker integration
- Code review annotations
- Team workspaces
- Shared configurations

### Enhanced Workflow
- Commit message templates and snippets
- Saved commit message drafts
- Workflow presets (feature branch, hotfix, release)
- Custom git aliases support
- Custom external tool integration (beyond scripts)

### Multi-Repository Management
- Bulk operations across multiple repos
- Repository groups and folders
- Global search across repos
- Dashboard showing status of all repos
- Batch cleanup operations

### Advanced Git Features
- Bisect support for bug hunting
- Worktree management
- Subtree operations
- Sparse checkout support
- Partial clone support
- Git notes integration

### Productivity Features
- Quick actions palette (Cmd+K)
- Custom keyboard shortcuts
- Terminal integration (open terminal at repo)
- VS Code / Xcode integration
- Finder extension (right-click actions)

### Analytics & Reporting
- Commit statistics
- Code churn tracking
- Branch lifecycle tracking
- Time-in-branch analysis
- Merge conflict frequency

### Enterprise Features
- LDAP/SSO integration
- Policy enforcement
- Audit logging
- Self-hosted configuration sync
- Team configuration sharing

### AI/ML Integration
- Smart commit message suggestions
- Conflict resolution assistance
- Code review suggestions
- Anomaly detection in git history

### Platform Extensions
- iOS companion app
- iCloud sync for configurations
- Apple Watch quick actions
- Safari extension for GitHub/GitLab
