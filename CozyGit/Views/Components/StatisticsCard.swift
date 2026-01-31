//
//  StatisticsCard.swift
//  CozyGit
//
//  Statistics summary card for Overview

import SwiftUI

struct StatisticsCard: View {
    let statistics: RepositoryStatistics

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Statistics")
                        .font(.headline)
                    Spacer()
                    Text("Last 6 months")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Stats Grid
                HStack(spacing: 24) {
                    StatBox(
                        value: statistics.totalCommits,
                        label: "Commits",
                        icon: "arrow.triangle.merge",
                        color: .blue
                    )

                    StatBox(
                        value: statistics.totalBranches,
                        label: "Branches",
                        icon: "arrow.triangle.branch",
                        color: .green
                    )

                    StatBox(
                        value: statistics.authorStats.count,
                        label: "Contributors",
                        icon: "person.2",
                        color: .purple
                    )

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Stat Box

private struct StatBox: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text("\(value)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    StatisticsCard(
        statistics: RepositoryStatistics(
            periodStart: Date().addingTimeInterval(-180 * 24 * 3600),
            periodEnd: Date(),
            totalCommits: 156,
            totalBranches: 12,
            authorStats: [
                AuthorStats(name: "John Doe", email: "john@example.com", commitCount: 78, percentage: 50),
                AuthorStats(name: "Jane Smith", email: "jane@example.com", commitCount: 45, percentage: 29),
                AuthorStats(name: "Bob Wilson", email: "bob@example.com", commitCount: 33, percentage: 21)
            ],
            dailyActivity: []
        )
    )
    .padding()
    .frame(width: 500)
}
