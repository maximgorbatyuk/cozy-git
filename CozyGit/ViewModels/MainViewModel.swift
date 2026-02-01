//
//  MainViewModel.swift
//  CozyGit
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class MainViewModel {
    // MARK: - Navigation

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case history = "History"
        case changes = "Changes"
        case branches = "Branches"
        case stash = "Stash"
        case tags = "Tags"
        case remotes = "Remotes"
        case submodules = "Submodules"
        case gitignore = "Gitignore"
        case cleanup = "Cleanup"
        case automate = "Automate"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .overview: return "house"
            case .changes: return "doc.badge.plus"
            case .branches: return "arrow.triangle.branch"
            case .history: return "clock"
            case .stash: return "tray.and.arrow.down"
            case .tags: return "tag"
            case .remotes: return "network"
            case .submodules: return "shippingbox"
            case .gitignore: return "eye.slash"
            case .cleanup: return "trash"
            case .automate: return "gearshape.2"
            }
        }
    }

    // MARK: - Published State

    var selectedTab: Tab = .overview
    var currentRepository: Repository?
    var recentRepositories: [Repository] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showError: Bool = false

    // MARK: - Dialog State

    var showCloneSheet: Bool = false
    var showInitSheet: Bool = false

    // MARK: - Services

    private let gitService: GitService
    private let logger = Logger.shared

    // MARK: - UserDefaults Keys

    private static let recentRepositoriesKey = "recentRepositories"

    // MARK: - Initialization

    init(gitService: GitService) {
        self.gitService = gitService
        self.recentRepositories = Self.loadRecentRepositories()
        logger.info("MainViewModel initialized", category: .app)
    }

    // MARK: - Persistence

    private static func loadRecentRepositories() -> [Repository] {
        guard let data = UserDefaults.standard.data(forKey: recentRepositoriesKey) else {
            return []
        }
        do {
            let repositories = try JSONDecoder().decode([Repository].self, from: data)
            // Filter out repositories that no longer exist
            return repositories.filter { FileManager.default.fileExists(atPath: $0.path.path) }
        } catch {
            return []
        }
    }

    private func saveRecentRepositories() {
        do {
            let data = try JSONEncoder().encode(recentRepositories)
            UserDefaults.standard.set(data, forKey: Self.recentRepositoriesKey)
        } catch {
            logger.error("Failed to save recent repositories: \(error)", category: .app)
        }
    }

    // MARK: - Repository Management

    func openRepository(at url: URL) async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = try await gitService.openRepository(at: url)
            currentRepository = repository
            addToRecent(repository)
            logger.info("Opened repository: \(repository.name)", category: .git)
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func closeRepository() {
        currentRepository = nil
        logger.info("Closed repository", category: .git)
    }

    func refreshRepository() async {
        guard let repo = currentRepository else { return }
        await openRepository(at: repo.path)
    }

    func cloneRepository(from url: URL, to destination: URL) async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = try await gitService.cloneRepository(from: url, to: destination)
            currentRepository = repository
            addToRecent(repository)
            logger.info("Cloned repository: \(repository.name)", category: .git)
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func initRepository(at path: URL, bare: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = try await gitService.initRepository(at: path, bare: bare)
            currentRepository = repository
            addToRecent(repository)
            logger.info("Initialized repository: \(repository.name)", category: .git)
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    private func addToRecent(_ repository: Repository) {
        // Remove existing entry if present (to move it to the top)
        recentRepositories.removeAll { $0.path == repository.path }
        // Insert at the beginning
        recentRepositories.insert(repository, at: 0)
        // Keep only the last 10
        if recentRepositories.count > 10 {
            recentRepositories.removeLast()
        }
        // Persist to UserDefaults
        saveRecentRepositories()
    }

    func removeFromRecent(_ repository: Repository) {
        recentRepositories.removeAll { $0.path == repository.path }
        saveRecentRepositories()
    }

    func clearRecentRepositories() {
        recentRepositories.removeAll()
        saveRecentRepositories()
    }

    // MARK: - File Dialog

    func showOpenDialog() {
        let panel = NSOpenPanel()
        panel.title = "Open Git Repository"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await openRepository(at: url)
            }
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let gitError = error as? GitError {
            errorMessage = gitError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
        logger.error("Error: \(errorMessage ?? "Unknown")", category: .app)
    }

    func dismissError() {
        showError = false
        errorMessage = nil
    }
}
