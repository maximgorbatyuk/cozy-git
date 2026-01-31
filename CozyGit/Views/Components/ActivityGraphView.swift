//
//  ActivityGraphView.swift
//  CozyGit
//
//  GitHub-style activity contribution graph

import SwiftUI

struct ActivityGraphView: View {
    let dailyActivity: [DailyActivity]

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let weeksToShow: Int = 26 // ~6 months

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text("Activity")
                        .font(.headline)
                    Spacer()
                    // Legend
                    HStack(spacing: 4) {
                        Text("Less")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ForEach(ActivityLevel.allCases, id: \.rawValue) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForLevel(level))
                                .frame(width: 10, height: 10)
                        }
                        Text("More")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if dailyActivity.isEmpty {
                    HStack {
                        Spacer()
                        Text("No activity data")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    // Month labels
                    monthLabels

                    // Activity grid
                    HStack(alignment: .top, spacing: 0) {
                        // Day labels
                        dayLabels

                        // Grid
                        ScrollView(.horizontal, showsIndicators: false) {
                            activityGrid
                        }
                    }
                }
            }
        }
    }

    // MARK: - Month Labels

    private var monthLabels: some View {
        let months = getMonthLabels()
        return HStack(spacing: 0) {
            // Offset for day labels
            Spacer()
                .frame(width: 30)

            ForEach(months, id: \.offset) { month in
                Text(month.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: CGFloat(month.weeks) * (cellSize + cellSpacing), alignment: .leading)
            }
            Spacer()
        }
    }

    // MARK: - Day Labels

    private var dayLabels: some View {
        VStack(alignment: .trailing, spacing: cellSpacing) {
            Text("")
                .font(.caption2)
                .frame(height: cellSize)
            Text("Mon")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(height: cellSize)
            Text("")
                .font(.caption2)
                .frame(height: cellSize)
            Text("Wed")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(height: cellSize)
            Text("")
                .font(.caption2)
                .frame(height: cellSize)
            Text("Fri")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(height: cellSize)
            Text("")
                .font(.caption2)
                .frame(height: cellSize)
        }
        .frame(width: 30)
    }

    // MARK: - Activity Grid

    private var activityGrid: some View {
        let weeks = groupByWeeks()

        return HStack(alignment: .top, spacing: cellSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        if dayIndex < week.count {
                            let activity = week[dayIndex]
                            ActivityCell(
                                activity: activity,
                                size: cellSize,
                                color: colorForLevel(activity.activityLevel)
                            )
                        } else {
                            // Empty cell for incomplete weeks
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.clear)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func groupByWeeks() -> [[DailyActivity]] {
        let calendar = Calendar.current
        var weeks: [[DailyActivity]] = []
        var currentWeek: [DailyActivity] = []

        // Sort activities by date
        let sorted = dailyActivity.sorted { $0.date < $1.date }

        for activity in sorted {
            let weekday = calendar.component(.weekday, from: activity.date)
            // Sunday = 1, so we adjust to make Monday = 0
            let adjustedWeekday = (weekday + 5) % 7

            // If it's Monday and we have items, start new week
            if adjustedWeekday == 0 && !currentWeek.isEmpty {
                weeks.append(currentWeek)
                currentWeek = []
            }

            // Fill in missing days at start of week
            while currentWeek.count < adjustedWeekday {
                currentWeek.append(DailyActivity(date: activity.date, commitCount: 0))
            }

            currentWeek.append(activity)
        }

        // Add the last week
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }

        return weeks
    }

    private func getMonthLabels() -> [(name: String, weeks: Int, offset: Int)] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"

        var months: [(name: String, weeks: Int, offset: Int)] = []
        var currentMonth = -1
        var weekCount = 0
        var offset = 0

        let sorted = dailyActivity.sorted { $0.date < $1.date }

        for (index, activity) in sorted.enumerated() {
            let month = calendar.component(.month, from: activity.date)
            let weekday = calendar.component(.weekday, from: activity.date)

            // Check if it's start of a new week (Monday)
            if weekday == 2 || index == 0 {
                if month != currentMonth {
                    if currentMonth != -1 && weekCount > 0 {
                        months.append((name: dateFormatter.string(from: sorted[offset].date), weeks: weekCount, offset: offset))
                    }
                    currentMonth = month
                    weekCount = 1
                    offset = index
                } else {
                    weekCount += 1
                }
            }
        }

        // Add last month
        if weekCount > 0 && offset < sorted.count {
            months.append((name: dateFormatter.string(from: sorted[offset].date), weeks: weekCount, offset: offset))
        }

        return months
    }

    private func colorForLevel(_ level: ActivityLevel) -> Color {
        switch level {
        case .none:
            return Color.secondary.opacity(0.15)
        case .low:
            return Color.green.opacity(0.3)
        case .medium:
            return Color.green.opacity(0.5)
        case .high:
            return Color.green.opacity(0.7)
        case .veryHigh:
            return Color.green
        }
    }
}

// MARK: - Activity Cell

private struct ActivityCell: View {
    let activity: DailyActivity
    let size: CGFloat
    let color: Color

    @State private var showPopover = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: size, height: size)
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(activity.commitCount) commit\(activity.commitCount == 1 ? "" : "s")")
                        .fontWeight(.semibold)
                    Text(activity.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()

    // Generate sample data
    var activities: [DailyActivity] = []
    for i in 0..<180 {
        if let date = calendar.date(byAdding: .day, value: -i, to: today) {
            let count = Int.random(in: 0...8)
            activities.append(DailyActivity(date: date, commitCount: count))
        }
    }

    return ActivityGraphView(dailyActivity: activities)
        .padding()
        .frame(width: 700)
}

#Preview("Empty") {
    ActivityGraphView(dailyActivity: [])
        .padding()
        .frame(width: 500)
}
