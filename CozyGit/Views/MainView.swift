//
//  MainView.swift
//  CozyGit
//

import SwiftUI

struct MainView: View {
    @State private var viewModel = DependencyContainer.shared.mainViewModel
    @State private var repositoryViewModel = DependencyContainer.shared.repositoryViewModel
    @State private var showShortcutsHelp = false
    @State private var showCommitDialog = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $viewModel.selectedTab)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            toolbarContent
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $viewModel.showCloneSheet) {
            CloneRepositorySheet { url, destination in
                await viewModel.cloneRepository(from: url, to: destination)
                if viewModel.currentRepository != nil {
                    repositoryViewModel.repository = viewModel.currentRepository
                    await repositoryViewModel.loadAllData()
                }
            }
        }
        .sheet(isPresented: $viewModel.showInitSheet) {
            InitRepositorySheet { path, bare in
                await viewModel.initRepository(at: path, bare: bare)
                if viewModel.currentRepository != nil {
                    repositoryViewModel.repository = viewModel.currentRepository
                    await repositoryViewModel.loadAllData()
                }
            }
        }
        .sheet(isPresented: $showShortcutsHelp) {
            ShortcutsHelpView()
        }
        .sheet(isPresented: $showCommitDialog) {
            CommitDialog(viewModel: repositoryViewModel)
        }
        .onChange(of: viewModel.currentRepository) { _, newRepo in
            repositoryViewModel.repository = newRepo
            if newRepo != nil {
                Task {
                    await repositoryViewModel.loadAllData()
                }
            }
        }
        // Hidden buttons for keyboard shortcuts
        .background {
            keyboardShortcutButtons
        }
    }

    // MARK: - Keyboard Shortcut Buttons

    @ViewBuilder
    private var keyboardShortcutButtons: some View {
        Group {
            // Navigation shortcuts
            Button("Overview") { viewModel.selectedTab = .overview }
                .keyboardShortcut("1", modifiers: .command)
            Button("Changes") { viewModel.selectedTab = .changes }
                .keyboardShortcut("2", modifiers: .command)
            Button("Branches") { viewModel.selectedTab = .branches }
                .keyboardShortcut("3", modifiers: .command)
            Button("History") { viewModel.selectedTab = .history }
                .keyboardShortcut("4", modifiers: .command)
            Button("Stash") { viewModel.selectedTab = .stash }
                .keyboardShortcut("5", modifiers: .command)
            Button("Tags") { viewModel.selectedTab = .tags }
                .keyboardShortcut("6", modifiers: .command)
            Button("Remotes") { viewModel.selectedTab = .remotes }
                .keyboardShortcut("7", modifiers: .command)
            Button("Submodules") { viewModel.selectedTab = .submodules }
                .keyboardShortcut("8", modifiers: .command)
            Button("Gitignore") { viewModel.selectedTab = .gitignore }
                .keyboardShortcut("9", modifiers: .command)
            Button("Automation") { viewModel.selectedTab = .automate }
                .keyboardShortcut("0", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)

        Group {
            // Git operations
            Button("Commit") {
                if viewModel.currentRepository != nil {
                    showCommitDialog = true
                }
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Refresh") {
                if viewModel.currentRepository != nil {
                    Task {
                        await viewModel.refreshRepository()
                        await repositoryViewModel.loadAllData()
                    }
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            // Help
            Button("Shortcuts") { showShortcutsHelp = true }
                .keyboardShortcut("/", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch viewModel.selectedTab {
        case .overview:
            OverviewTab(viewModel: repositoryViewModel)
        case .changes:
            ChangesTab(viewModel: repositoryViewModel)
        case .branches:
            BranchesTab(viewModel: repositoryViewModel)
        case .history:
            HistoryTab(viewModel: repositoryViewModel)
        case .stash:
            StashTab(viewModel: repositoryViewModel)
        case .tags:
            TagsTab(viewModel: repositoryViewModel)
        case .remotes:
            RemotesTab(viewModel: repositoryViewModel)
        case .submodules:
            SubmodulesTab(viewModel: repositoryViewModel)
        case .gitignore:
            GitignoreTab(viewModel: repositoryViewModel)
        case .cleanup:
            CleanupTab(viewModel: repositoryViewModel)
        case .automate:
            AutomateTab(repository: viewModel.currentRepository)
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        if let repo = viewModel.currentRepository {
            return "\(repo.name) - \(viewModel.selectedTab.rawValue)"
        }
        return "Cozy Git"
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                viewModel.showOpenDialog()
            } label: {
                Image(systemName: "folder")
            }
            .help("Open Repository")
        }

        ToolbarItem(placement: .primaryAction) {
            if viewModel.currentRepository != nil {
                Button {
                    Task {
                        await viewModel.refreshRepository()
                        repositoryViewModel.repository = viewModel.currentRepository
                        await repositoryViewModel.loadAllData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                if !viewModel.recentRepositories.isEmpty {
                    Section("Recent Repositories") {
                        ForEach(viewModel.recentRepositories) { repo in
                            Button(repo.name) {
                                Task {
                                    await viewModel.openRepository(at: repo.path)
                                }
                            }
                        }
                    }

                    Divider()
                }

                Button("Open Repository...") {
                    viewModel.showOpenDialog()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Clone Repository...") {
                    viewModel.showCloneSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Initialize Repository...") {
                    viewModel.showInitSheet = true
                }

                if viewModel.currentRepository != nil {
                    Divider()

                    Button("Close Repository") {
                        viewModel.closeRepository()
                        repositoryViewModel.repository = nil
                    }
                }
            } label: {
                Label("Repository", systemImage: "book.closed")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .frame(width: 900, height: 600)
}
