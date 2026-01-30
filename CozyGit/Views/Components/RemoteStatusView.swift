//
//  RemoteStatusView.swift
//  CozyGit
//

import SwiftUI

struct RemoteStatusView: View {
    let status: RemoteTrackingStatus?

    var body: some View {
        if let status = status {
            HStack(spacing: 12) {
                if status.ahead > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                        Text("\(status.ahead)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundColor(.blue)
                    .help("\(status.ahead) commit(s) ahead of remote")
                }

                if status.behind > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                        Text("\(status.behind)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundColor(.orange)
                    .help("\(status.behind) commit(s) behind remote")
                }

                if !status.hasChanges {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Up to date")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "network.slash")
                    .font(.caption)
                Text("No upstream")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
    }
}

#Preview("Ahead and Behind") {
    RemoteStatusView(status: RemoteTrackingStatus(ahead: 3, behind: 2))
        .padding()
}

#Preview("Only Ahead") {
    RemoteStatusView(status: RemoteTrackingStatus(ahead: 5, behind: 0))
        .padding()
}

#Preview("Only Behind") {
    RemoteStatusView(status: RemoteTrackingStatus(ahead: 0, behind: 3))
        .padding()
}

#Preview("Up to Date") {
    RemoteStatusView(status: RemoteTrackingStatus(ahead: 0, behind: 0))
        .padding()
}

#Preview("No Upstream") {
    RemoteStatusView(status: nil)
        .padding()
}
