//
//  AutoFetchService.swift
//  CozyGit
//

import Foundation
import Combine

/// Service that handles automatic background fetching
@MainActor
final class AutoFetchService: ObservableObject {
    // MARK: - Published Properties

    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startAutoFetch()
            } else {
                stopAutoFetch()
            }
        }
    }

    @Published var intervalMinutes: Int = 5 {
        didSet {
            if isEnabled {
                restartAutoFetch()
            }
        }
    }

    @Published var lastFetchTime: Date?
    @Published var isFetching: Bool = false

    // MARK: - Private Properties

    private var fetchTask: Task<Void, Never>?
    private weak var repositoryViewModel: RepositoryViewModel?
    private let logger = Logger.shared

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    // MARK: - Configuration

    func configure(with viewModel: RepositoryViewModel) {
        self.repositoryViewModel = viewModel
        if isEnabled {
            startAutoFetch()
        }
    }

    // MARK: - Auto-Fetch Control

    func startAutoFetch() {
        stopAutoFetch()

        guard isEnabled, intervalMinutes > 0 else { return }

        fetchTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                // Wait for the interval
                try? await Task.sleep(for: .seconds(intervalMinutes * 60))

                guard !Task.isCancelled else { break }

                // Perform fetch if we have a repository
                if self.repositoryViewModel?.repository != nil {
                    await self.performAutoFetch()
                }
            }
        }

        logger.info("Auto-fetch started with interval: \(intervalMinutes) minutes", category: .git)
    }

    func stopAutoFetch() {
        fetchTask?.cancel()
        fetchTask = nil
        logger.info("Auto-fetch stopped", category: .git)
    }

    private func restartAutoFetch() {
        if isEnabled {
            startAutoFetch()
        }
    }

    // MARK: - Fetch Operation

    private func performAutoFetch() async {
        guard let viewModel = repositoryViewModel, !isFetching else { return }

        isFetching = true

        do {
            try await DependencyContainer.shared.gitService.fetch(prune: true)
            await viewModel.loadRemoteStatus()
            lastFetchTime = Date()
            logger.info("Auto-fetch completed successfully", category: .git)
        } catch {
            logger.error("Auto-fetch failed: \(error.localizedDescription)", category: .git)
        }

        isFetching = false
    }

    /// Perform an immediate fetch (can be called manually)
    func fetchNow() async {
        await performAutoFetch()
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "autoFetchEnabled")
        let savedInterval = UserDefaults.standard.integer(forKey: "autoFetchInterval")
        intervalMinutes = savedInterval > 0 ? savedInterval : 5
    }

    func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "autoFetchEnabled")
        UserDefaults.standard.set(intervalMinutes, forKey: "autoFetchInterval")
    }
}

