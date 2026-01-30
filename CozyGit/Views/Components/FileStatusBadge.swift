//
//  FileStatusBadge.swift
//  CozyGit
//

import SwiftUI

struct FileStatusBadge: View {
    let status: FileChangeType

    var body: some View {
        Text(status.shortName)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
            .frame(width: 18, height: 18)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var backgroundColor: Color {
        switch status {
        case .added:
            return .green
        case .deleted:
            return .red
        case .modified:
            return .orange
        case .renamed:
            return .blue
        case .copied:
            return .blue
        case .untracked:
            return .gray
        case .ignored:
            return .secondary
        }
    }
}

private extension FileChangeType {
    var shortName: String {
        switch self {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .copied: return "C"
        case .untracked: return "?"
        case .ignored: return "!"
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        FileStatusBadge(status: .added)
        FileStatusBadge(status: .modified)
        FileStatusBadge(status: .deleted)
        FileStatusBadge(status: .renamed)
        FileStatusBadge(status: .untracked)
    }
    .padding()
}
