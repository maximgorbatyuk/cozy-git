//
//  EmptyStateView.swift
//  CozyGit
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true) // Icon is decorative

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(String(localized: "Activate to \(actionTitle.lowercased())", comment: "Empty state action hint"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        // Combine into single accessible element for VoiceOver
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

#Preview("With Action") {
    EmptyStateView(
        icon: "folder.badge.questionmark",
        title: "No Repository Open",
        message: "Open a Git repository to get started",
        actionTitle: "Open Repository"
    ) {
        print("Action tapped")
    }
    .frame(width: 400, height: 300)
}

#Preview("Without Action") {
    EmptyStateView(
        icon: "doc.text",
        title: "No Changes",
        message: "Your working directory is clean"
    )
    .frame(width: 400, height: 300)
}
