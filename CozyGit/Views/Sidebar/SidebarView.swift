//
//  SidebarView.swift
//  CozyGit
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: MainViewModel.Tab

    var body: some View {
        List(MainViewModel.Tab.allCases, selection: $selectedTab) { tab in
            NavigationLink(value: tab) {
                Label(tab.rawValue, systemImage: tab.iconName)
            }
            .accessibilityIdentifier(accessibilityID(for: tab))
            .accessibilityLabel(tab.rawValue)
            .accessibilityHint(String(localized: "Navigate to \(tab.rawValue) view", comment: "Navigation hint"))
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        .accessibilityIdentifier(AccessibilityID.sidebar)
    }

    private func accessibilityID(for tab: MainViewModel.Tab) -> String {
        switch tab {
        case .overview: return AccessibilityID.overviewTab
        case .changes: return AccessibilityID.changesTab
        case .branches: return AccessibilityID.branchesTab
        case .history: return AccessibilityID.historyTab
        case .stash: return AccessibilityID.stashTab
        case .tags: return AccessibilityID.tagsTab
        case .remotes: return AccessibilityID.remotesTab
        case .submodules: return AccessibilityID.submodulesTab
        case .gitignore: return AccessibilityID.gitignoreTab
        case .automate: return AccessibilityID.automateTab
        case .cleanup: return AccessibilityID.cleanupTab
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selectedTab: MainViewModel.Tab = .overview

    SidebarView(selectedTab: $selectedTab)
        .frame(width: 200, height: 400)
}
