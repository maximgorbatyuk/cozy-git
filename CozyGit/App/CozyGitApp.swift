//
//  CozyGitApp.swift
//  CozyGit
//

import SwiftUI

@main
struct CozyGitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Repository...") {
                    DependencyContainer.shared.mainViewModel.showOpenDialog()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("Repository") {
                Button("Refresh") {
                    Task {
                        await DependencyContainer.shared.mainViewModel.refreshRepository()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Close Repository") {
                    DependencyContainer.shared.mainViewModel.closeRepository()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }

            CommandMenu("Git") {
                Button("Fetch") {
                    // TODO: Implement fetch
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Pull") {
                    // TODO: Implement pull
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Push") {
                    // TODO: Implement push
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Divider()

                Button("Commit...") {
                    // TODO: Implement commit dialog
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Stash Changes") {
                    // TODO: Implement stash
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize dependency container
        _ = DependencyContainer.shared
        Logger.shared.info("Application launched", category: .app)
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.info("Application terminating", category: .app)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            GitSettingsView()
                .tabItem {
                    Label("Git", systemImage: "arrow.triangle.branch")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("General settings will be added here.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct GitSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("Git settings will be added here.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview("Settings") {
    SettingsView()
}
