//
//  MainView.swift
//  CozyGit
//

import SwiftUI

struct MainView: View {
    @State private var viewModel = DependencyContainer.shared.mainViewModel
    @State private var repositoryViewModel = DependencyContainer.shared.repositoryViewModel

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
        .onChange(of: viewModel.currentRepository) { _, newRepo in
            repositoryViewModel.repository = newRepo
            if newRepo != nil {
                Task {
                    await repositoryViewModel.loadAllData()
                }
            }
        }
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
