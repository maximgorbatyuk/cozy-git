//
//  RepositoryStatistics.swift
//  CozyGit
//
//  Statistics for repository overview

import Foundation

/// Statistics for repository over a time period
struct RepositoryStatistics {
    let periodStart: Date
    let periodEnd: Date
    let totalCommits: Int
    let totalBranches: Int
    let authorStats: [AuthorStats]
    let dailyActivity: [DailyActivity]

    /// Period description (e.g., "Last 6 months")
    var periodDescription: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.month]
        formatter.unitsStyle = .full
        let interval = periodEnd.timeIntervalSince(periodStart)
        if let formatted = formatter.string(from: interval) {
            return "Last \(formatted)"
        }
        return "Last 6 months"
    }
}

/// Author contribution statistics
struct AuthorStats: Identifiable {
    let id = UUID()
    let name: String
    let email: String
    let commitCount: Int
    let percentage: Double

    /// Display name (name or email if name is empty)
    var displayName: String {
        name.isEmpty ? email : name
    }
}

/// Daily activity record
struct DailyActivity: Identifiable {
    let id = UUID()
    let date: Date
    let commitCount: Int

    /// Activity level for visualization
    var activityLevel: ActivityLevel {
        switch commitCount {
        case 0: return .none
        case 1...2: return .low
        case 3...5: return .medium
        case 6...10: return .high
        default: return .veryHigh
        }
    }
}

/// Activity level for the contribution graph
enum ActivityLevel: Int, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case veryHigh = 4

    var color: String {
        switch self {
        case .none: return "activityNone"
        case .low: return "activityLow"
        case .medium: return "activityMedium"
        case .high: return "activityHigh"
        case .veryHigh: return "activityVeryHigh"
        }
    }
}
