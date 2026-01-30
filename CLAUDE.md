# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the project
xcodebuild -project CozyGit.xcodeproj -scheme CozyGit -configuration Debug build

# Run the app (after building)
open ~/Library/Developer/Xcode/DerivedData/CozyGit-*/Build/Products/Debug/CozyGit.app
```

## Architecture

Cozy Git is a macOS SwiftUI application using MVVM architecture. It wraps system git commands to provide a GUI for repository management with focus on cleanup (merged/stale branches) and automation (commit prefixes, script hooks).

### Layer Overview

```
Views → ViewModels → Services → ShellExecutor → git CLI
```

### Key Components

**DependencyContainer** (`Utilities/DependencyContainer.swift`)
- Singleton service locator providing lazy-initialized dependencies
- Access via `DependencyContainer.shared`
- Services: `shellExecutor`, `gitService`, `logger`
- ViewModels: `mainViewModel`

**GitService** (`Services/GitService.swift`)
- Implements `GitServiceProtocol` (combines 6 sub-protocols)
- All operations are `async` using Swift concurrency
- Maintains `currentRepository` state
- Parses git command output into model objects

**ShellExecutor** (`Services/ShellExecutor.swift`)
- Actor-based async shell command execution
- 30-second default timeout with cancellation support
- Returns `GitOperationResult` with success/output/error/exitCode

**ViewModels** use `@Observable` (Swift 5.9+) and are `@MainActor`

### Navigation Structure

Main app uses `NavigationSplitView` with 6 tabs:
- Overview, Changes, Branches, History, Cleanup, Automate

Each tab has a corresponding view in `Views/Tabs/`.

### Git Protocol Hierarchy

`GitServiceProtocol` combines:
- `GitRepositoryServiceProtocol` - open/init/clone/status
- `GitBranchServiceProtocol` - list/create/checkout/delete branches
- `GitCommitServiceProtocol` - history/commit/stage/unstage
- `GitRemoteServiceProtocol` - remotes/fetch/pull/push
- `GitStashServiceProtocol` - stash operations
- `GitTagServiceProtocol` - tag operations

## UI Guidelines

- Clean, warm, and cozy design with rounded corners and soft shadows
- Use SF Symbols for icons
- Use native macOS controls and system fonts
- Avoid sharp corners, harsh shadows, and cold colors

## Project Settings

- **Minimum macOS**: 14.0
- **App Sandbox**: Disabled (required for shell execution)
- **Swift Concurrency**: All git operations are async
