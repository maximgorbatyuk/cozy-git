//
//  MainView.swift
//  CozyGit
//

import SwiftUI

struct MainView: View {
    @State private var viewModel = DependencyContainer.shared.mainViewModel

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
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch viewModel.selectedTab {
        case .overview:
            OverviewTab(repository: viewModel.currentRepository)
        case .changes:
            ChangesTab(repository: viewModel.currentRepository)
        case .branches:
            BranchesTab(repository: viewModel.currentRepository)
        case .history:
            HistoryTab(repository: viewModel.currentRepository)
        case .cleanup:
            CleanupTab(repository: viewModel.currentRepository)
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

                if viewModel.currentRepository != nil {
                    Button("Close Repository") {
                        viewModel.closeRepository()
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
