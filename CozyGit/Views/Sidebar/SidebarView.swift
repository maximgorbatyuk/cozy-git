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
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selectedTab: MainViewModel.Tab = .overview

    SidebarView(selectedTab: $selectedTab)
        .frame(width: 200, height: 400)
}
