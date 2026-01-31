//
//  AuthorStatsView.swift
//  CozyGit
//
//  Author contribution statistics view

import SwiftUI

struct AuthorStatsView: View {
    let authors: [AuthorStats]
    var maxDisplayed: Int = 5

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text("Top Contributors")
                        .font(.headline)
                    Spacer()
                    if authors.count > maxDisplayed {
                        Text("\(authors.count) total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if authors.isEmpty {
                    HStack {
                        Spacer()
                        Text("No commits in this period")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    // Author List
                    VStack(spacing: 10) {
                        ForEach(authors.prefix(maxDisplayed)) { author in
                            AuthorRow(author: author)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Author Row

private struct AuthorRow: View {
    let author: AuthorStats

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Avatar placeholder
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(author.displayName)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if !author.email.isEmpty && author.name != author.email {
                        Text(author.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Commit count and percentage
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(author.commitCount)")
                        .fontWeight(.semibold)

                    Text(String(format: "%.0f%%", author.percentage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * CGFloat(author.percentage / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var progressColor: Color {
        if author.percentage >= 50 {
            return .blue
        } else if author.percentage >= 25 {
            return .green
        } else if author.percentage >= 10 {
            return .orange
        } else {
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    AuthorStatsView(
        authors: [
            AuthorStats(name: "John Doe", email: "john@example.com", commitCount: 78, percentage: 52),
            AuthorStats(name: "Jane Smith", email: "jane@example.com", commitCount: 45, percentage: 30),
            AuthorStats(name: "Bob Wilson", email: "bob@example.com", commitCount: 27, percentage: 18)
        ]
    )
    .padding()
    .frame(width: 400)
}

#Preview("Empty") {
    AuthorStatsView(authors: [])
        .padding()
        .frame(width: 400)
}
