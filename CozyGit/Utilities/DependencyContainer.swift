//
//  DependencyContainer.swift
//  CozyGit
//

import Foundation

@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    private init() {}

    // MARK: - Services

    private var _shellExecutor: ShellExecutor?
    var shellExecutor: ShellExecutor {
        if _shellExecutor == nil {
            _shellExecutor = ShellExecutor()
        }
        return _shellExecutor!
    }

    private var _gitService: GitService?
    var gitService: GitService {
        if _gitService == nil {
            _gitService = GitService(shellExecutor: shellExecutor)
        }
        return _gitService!
    }

    private var _logger: Logger?
    var logger: Logger {
        if _logger == nil {
            _logger = Logger.shared
        }
        return _logger!
    }

    // MARK: - ViewModels

    private var _mainViewModel: MainViewModel?
    var mainViewModel: MainViewModel {
        if _mainViewModel == nil {
            _mainViewModel = MainViewModel(gitService: gitService)
        }
        return _mainViewModel!
    }

    private var _repositoryViewModel: RepositoryViewModel?
    var repositoryViewModel: RepositoryViewModel {
        if _repositoryViewModel == nil {
            _repositoryViewModel = RepositoryViewModel(gitService: gitService)
        }
        return _repositoryViewModel!
    }

    // MARK: - Reset (for testing)

    func reset() {
        _shellExecutor = nil
        _gitService = nil
        _logger = nil
        _mainViewModel = nil
        _repositoryViewModel = nil
    }
}
