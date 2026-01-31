//
//  CommitGraphView.swift
//  CozyGit
//
//  Phase 10: Commit Graph Visualization

import SwiftUI

// MARK: - Graph Data Models

/// Represents a node in the commit graph with its visual position
struct CommitGraphNode: Identifiable {
    let id: String
    let commit: Commit
    let row: Int
    let lane: Int
    let parentLanes: [(parentHash: String, fromLane: Int, toLane: Int)]
    let isMergeCommit: Bool
    let isBranchStart: Bool
    let color: Color
    /// All active lanes at this row (lane index -> color)
    let activeLanes: [Int: Color]
    /// Lanes that continue from the previous row (for drawing top lines)
    let continuingLanes: [Int: Color]

    init(commit: Commit, row: Int, lane: Int, parentLanes: [(String, Int, Int)] = [], color: Color = .blue, activeLanes: [Int: Color] = [:], continuingLanes: [Int: Color] = [:]) {
        self.id = commit.hash
        self.commit = commit
        self.row = row
        self.lane = lane
        self.parentLanes = parentLanes
        self.isMergeCommit = commit.parents.count > 1
        self.isBranchStart = commit.parents.isEmpty
        self.color = color
        self.activeLanes = activeLanes
        self.continuingLanes = continuingLanes
    }
}

/// Represents an active lane in the graph
struct GraphLane {
    var commitHash: String
    var color: Color
    var isActive: Bool
}

// MARK: - Branch Colors

/// Provides consistent colors for branches
struct BranchColors {
    static let colors: [Color] = [
        .blue,
        .green,
        .orange,
        .purple,
        .pink,
        .cyan,
        .yellow,
        .red,
        .mint,
        .indigo
    ]

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }

    static func color(for branchName: String) -> Color {
        if branchName.contains("main") || branchName.contains("master") {
            return .blue
        } else if branchName.contains("develop") {
            return .green
        } else if branchName.contains("feature") {
            return .purple
        } else if branchName.contains("hotfix") || branchName.contains("fix") {
            return .red
        } else if branchName.contains("release") {
            return .orange
        }
        // Hash the branch name to get consistent color
        let hash = branchName.hashValue
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Graph Layout Calculator

/// Calculates the layout of commits in the graph
class GraphLayoutCalculator {

    /// Calculate graph nodes from a list of commits
    static func calculateLayout(commits: [Commit]) -> [CommitGraphNode] {
        guard !commits.isEmpty else { return [] }

        var nodes: [CommitGraphNode] = []
        // Active lanes that draw continuous vertical lines
        var activeLanes: [GraphLane] = []
        // Lanes reserved for merge parents (only draw merge curve, not continuous line)
        var reservedLanes: [String: Int] = [:]  // commitHash -> lane
        var laneColors: [Int: Color] = [:]
        var colorIndex = 0

        // Build a set of all commit hashes for quick lookup
        let commitSet = Set(commits.map { $0.hash })

        for (row, commit) in commits.enumerated() {
            // Capture lanes that were active before processing this commit (for drawing lines from top)
            let continuingLanes = getCurrentActiveLanes(activeLanes, laneColors: laneColors)

            // Find or create lane for this commit
            var lane: Int
            var nodeColor: Color

            // Check if this commit has a reserved lane (from a previous merge)
            if let reservedLane = reservedLanes[commit.hash] {
                lane = reservedLane
                nodeColor = laneColors[lane] ?? BranchColors.color(for: colorIndex)
                reservedLanes.removeValue(forKey: commit.hash)
                // This lane is now active (the commit is here, and it may have parents)
            }
            // Check if this commit is expected in any active lane
            else if let existingLane = findLaneForCommit(commit.hash, in: activeLanes) {
                lane = existingLane
                nodeColor = laneColors[lane] ?? BranchColors.color(for: colorIndex)
            } else {
                // New branch - find first available lane or create new one
                lane = findAvailableLane(in: activeLanes, reservedLanes: reservedLanes)
                nodeColor = BranchColors.color(for: colorIndex)
                colorIndex += 1
                laneColors[lane] = nodeColor
            }

            // Ensure lanes array is big enough
            while activeLanes.count <= lane {
                activeLanes.append(GraphLane(commitHash: "", color: .gray, isActive: false))
            }

            // Calculate parent lanes for drawing connections
            var parentLanes: [(String, Int, Int)] = []

            for (parentIndex, parentHash) in commit.parents.enumerated() {
                // Only process parents that are in our commit list
                guard commitSet.contains(parentHash) else { continue }

                if parentIndex == 0 {
                    // First parent continues on same lane - this draws a continuous line
                    parentLanes.append((parentHash, lane, lane))
                    activeLanes[lane] = GraphLane(commitHash: parentHash, color: nodeColor, isActive: true)
                    laneColors[lane] = nodeColor
                } else {
                    // Secondary parent (merge) - reserve a lane for it but DON'T make it active
                    // This means no continuous line, only the merge curve
                    let parentLane: Int

                    if let existingReserved = reservedLanes[parentHash] {
                        // Already reserved
                        parentLane = existingReserved
                    } else if let existingActive = findLaneForCommit(parentHash, in: activeLanes) {
                        // Already on an active lane
                        parentLane = existingActive
                    } else {
                        // Need to reserve a new lane
                        parentLane = findAvailableLane(in: activeLanes, reservedLanes: reservedLanes, excluding: lane)

                        while activeLanes.count <= parentLane {
                            activeLanes.append(GraphLane(commitHash: "", color: .gray, isActive: false))
                        }

                        let parentColor = BranchColors.color(for: colorIndex)
                        colorIndex += 1
                        laneColors[parentLane] = parentColor

                        // Reserve this lane for the parent commit (don't mark as active)
                        reservedLanes[parentHash] = parentLane
                    }
                    parentLanes.append((parentHash, lane, parentLane))
                }
            }

            // If no parents in our list, close the lane
            let hasParentsInList = commit.parents.contains { commitSet.contains($0) }
            if !hasParentsInList {
                activeLanes[lane] = GraphLane(commitHash: "", color: nodeColor, isActive: false)
            }

            // Get active lanes AFTER processing this commit (for drawing lines to bottom)
            // Don't include reserved lanes - they only get merge curves
            let currentActiveLanes = getCurrentActiveLanes(activeLanes, laneColors: laneColors)

            let node = CommitGraphNode(
                commit: commit,
                row: row,
                lane: lane,
                parentLanes: parentLanes,
                color: nodeColor,
                activeLanes: currentActiveLanes,
                continuingLanes: continuingLanes
            )
            nodes.append(node)
        }

        return nodes
    }

    private static func getCurrentActiveLanes(_ lanes: [GraphLane], laneColors: [Int: Color]) -> [Int: Color] {
        var result: [Int: Color] = [:]
        for (index, lane) in lanes.enumerated() {
            if lane.isActive {
                result[index] = laneColors[index] ?? lane.color
            }
        }
        return result
    }

    private static func findLaneForCommit(_ hash: String, in lanes: [GraphLane]) -> Int? {
        for (index, lane) in lanes.enumerated() {
            if lane.isActive && lane.commitHash == hash {
                return index
            }
        }
        return nil
    }

    private static func findAvailableLane(in lanes: [GraphLane], reservedLanes: [String: Int] = [:], excluding: Int? = nil) -> Int {
        let reservedIndices = Set(reservedLanes.values)
        for (index, lane) in lanes.enumerated() {
            if !lane.isActive && index != excluding && !reservedIndices.contains(index) {
                return index
            }
        }
        // Find first index not reserved and not excluding
        var newIndex = lanes.count
        while reservedIndices.contains(newIndex) || newIndex == excluding {
            newIndex += 1
        }
        return newIndex
    }
}

// MARK: - Graph Constants

private enum GraphConstants {
    static let nodeRadius: CGFloat = 5
    static let laneWidth: CGFloat = 20
    static let rowHeight: CGFloat = 32
    static let lineWidth: CGFloat = 2
    static let graphWidth: CGFloat = 120
}

// MARK: - Commit Graph View

/// A view that displays the commit graph with branch lanes
struct CommitGraphView: View {
    let nodes: [CommitGraphNode]
    let selectedCommitHash: String?
    let onSelectCommit: (Commit) -> Void

    @State private var hoveredNodeId: String?

    var body: some View {
        Canvas { context, size in
            // Draw connections first (behind nodes)
            for node in nodes {
                drawConnections(context: context, node: node)
            }

            // Draw nodes on top
            for node in nodes {
                drawNode(context: context, node: node)
            }
        }
        .frame(width: GraphConstants.graphWidth)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func drawNode(context: GraphicsContext, node: CommitGraphNode) {
        let center = nodeCenter(for: node)
        let radius = GraphConstants.nodeRadius

        let isSelected = node.commit.hash == selectedCommitHash
        let isHovered = node.commit.hash == hoveredNodeId

        // Draw node circle
        let path = Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        // Fill
        context.fill(path, with: .color(node.color))

        // Stroke for selected/hovered
        if isSelected || isHovered {
            context.stroke(
                path,
                with: .color(.white),
                lineWidth: 2
            )
        }

        // Special indicator for merge commits
        if node.isMergeCommit {
            let innerPath = Path(ellipseIn: CGRect(
                x: center.x - radius * 0.4,
                y: center.y - radius * 0.4,
                width: radius * 0.8,
                height: radius * 0.8
            ))
            context.fill(innerPath, with: .color(.white))
        }
    }

    private func drawConnections(context: GraphicsContext, node: CommitGraphNode) {
        let nodeCenter = self.nodeCenter(for: node)

        for (_, fromLane, toLane) in node.parentLanes {
            let startPoint = nodeCenter
            let endY = CGFloat(node.row + 1) * GraphConstants.rowHeight + GraphConstants.rowHeight / 2
            let endX = CGFloat(toLane) * GraphConstants.laneWidth + GraphConstants.laneWidth / 2 + 10
            let endPoint = CGPoint(x: endX, y: endY)

            var path = Path()
            path.move(to: startPoint)

            if fromLane == toLane {
                // Straight line
                path.addLine(to: endPoint)
            } else {
                // Curved line for lane changes (merges)
                let midY = (startPoint.y + endPoint.y) / 2
                path.addCurve(
                    to: endPoint,
                    control1: CGPoint(x: startPoint.x, y: midY),
                    control2: CGPoint(x: endPoint.x, y: midY)
                )
            }

            context.stroke(
                path,
                with: .color(node.color.opacity(0.7)),
                lineWidth: GraphConstants.lineWidth
            )
        }
    }

    private func nodeCenter(for node: CommitGraphNode) -> CGPoint {
        let x = CGFloat(node.lane) * GraphConstants.laneWidth + GraphConstants.laneWidth / 2 + 10
        let y = CGFloat(node.row) * GraphConstants.rowHeight + GraphConstants.rowHeight / 2
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Commit Graph Row

/// A single row in the commit graph list
struct CommitGraphRow: View {
    let node: CommitGraphNode
    let isSelected: Bool
    let maxLanes: Int

    var body: some View {
        HStack(spacing: 0) {
            // Graph portion
            graphPortion
                .frame(width: CGFloat(max(maxLanes, 3)) * GraphConstants.laneWidth + 20)

            // Commit info
            commitInfo
        }
        .frame(height: GraphConstants.rowHeight)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }

    private var graphPortion: some View {
        Canvas { context, size in
            let nodeCenter = CGPoint(
                x: CGFloat(node.lane) * GraphConstants.laneWidth + GraphConstants.laneWidth / 2 + 10,
                y: size.height / 2
            )

            // 1. Draw vertical lines for ALL continuing lanes (from top to center)
            for (laneIndex, laneColor) in node.continuingLanes {
                let x = CGFloat(laneIndex) * GraphConstants.laneWidth + GraphConstants.laneWidth / 2 + 10
                var linePath = Path()
                linePath.move(to: CGPoint(x: x, y: 0))

                if laneIndex == node.lane {
                    // This lane has the node - draw to center
                    linePath.addLine(to: CGPoint(x: x, y: size.height / 2))
                } else {
                    // This lane passes through - draw full height
                    linePath.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(linePath, with: .color(laneColor.opacity(0.7)), lineWidth: GraphConstants.lineWidth)
            }

            // 2. Draw vertical lines for ALL active lanes (from center/top to bottom)
            for (laneIndex, laneColor) in node.activeLanes {
                let x = CGFloat(laneIndex) * GraphConstants.laneWidth + GraphConstants.laneWidth / 2 + 10

                // Skip if this was already drawn as continuing lane and passes through
                if node.continuingLanes[laneIndex] != nil && laneIndex != node.lane {
                    continue
                }

                var linePath = Path()
                if laneIndex == node.lane {
                    // This lane has the node - draw from center to bottom
                    linePath.move(to: CGPoint(x: x, y: size.height / 2))
                } else {
                    // This lane starts fresh here - draw from top to bottom
                    linePath.move(to: CGPoint(x: x, y: 0))
                }
                linePath.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(linePath, with: .color(laneColor.opacity(0.7)), lineWidth: GraphConstants.lineWidth)
            }

            // 3. Draw merge curves (from node to other lanes)
            for (_, fromLane, toLane) in node.parentLanes where toLane != fromLane {
                let startX = CGFloat(fromLane) * GraphConstants.laneWidth + GraphConstants.laneWidth / 2 + 10
                let endX = CGFloat(toLane) * GraphConstants.laneWidth + GraphConstants.laneWidth / 2 + 10
                let startPoint = CGPoint(x: startX, y: size.height / 2)
                let endPoint = CGPoint(x: endX, y: size.height)

                var mergePath = Path()
                mergePath.move(to: startPoint)
                mergePath.addCurve(
                    to: endPoint,
                    control1: CGPoint(x: startX, y: size.height * 0.75),
                    control2: CGPoint(x: endX, y: size.height * 0.75)
                )

                let mergeColor = node.activeLanes[toLane] ?? node.color
                context.stroke(mergePath, with: .color(mergeColor.opacity(0.7)), lineWidth: GraphConstants.lineWidth)
            }

            // 4. Draw the commit node circle (on top of lines)
            let nodePath = Path(ellipseIn: CGRect(
                x: nodeCenter.x - GraphConstants.nodeRadius,
                y: nodeCenter.y - GraphConstants.nodeRadius,
                width: GraphConstants.nodeRadius * 2,
                height: GraphConstants.nodeRadius * 2
            ))
            context.fill(nodePath, with: .color(node.color))

            if isSelected {
                context.stroke(nodePath, with: .color(.white), lineWidth: 2)
            }

            // 5. Merge commit indicator (white inner circle)
            if node.isMergeCommit {
                let innerPath = Path(ellipseIn: CGRect(
                    x: nodeCenter.x - GraphConstants.nodeRadius * 0.4,
                    y: nodeCenter.y - GraphConstants.nodeRadius * 0.4,
                    width: GraphConstants.nodeRadius * 0.8,
                    height: GraphConstants.nodeRadius * 0.8
                ))
                context.fill(innerPath, with: .color(.white))
            }
        }
    }

    private var commitInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Message
            Text(node.commit.message.components(separatedBy: .newlines).first ?? node.commit.message)
                .lineLimit(1)
                .font(.system(.body))

            // Metadata
            HStack(spacing: 8) {
                Text(node.commit.shortHash)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(node.commit.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(node.commit.date.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Commit Graph List View

/// Complete commit graph list with scrolling
struct CommitGraphListView: View {
    let commits: [Commit]
    @Binding var selectedCommit: Commit?
    let onDoubleClick: (Commit) -> Void

    @State private var nodes: [CommitGraphNode] = []
    @State private var maxLanes: Int = 1

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(nodes) { node in
                    CommitGraphRow(
                        node: node,
                        isSelected: selectedCommit?.hash == node.commit.hash,
                        maxLanes: maxLanes
                    )
                    .onTapGesture {
                        selectedCommit = node.commit
                    }
                    .onTapGesture(count: 2) {
                        selectedCommit = node.commit
                        onDoubleClick(node.commit)
                    }

                    if node.id != nodes.last?.id {
                        Divider()
                            .padding(.leading, CGFloat(maxLanes) * GraphConstants.laneWidth + 28)
                    }
                }
            }
        }
        .onAppear {
            calculateGraph()
        }
        .onChange(of: commits) { _, _ in
            calculateGraph()
        }
    }

    private func calculateGraph() {
        nodes = GraphLayoutCalculator.calculateLayout(commits: commits)
        maxLanes = (nodes.map { $0.lane }.max() ?? 0) + 1
    }
}

// MARK: - Ref Badge

/// A badge showing a branch or tag reference
struct RefBadge: View {
    let ref: String

    var body: some View {
        Text(displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .clipShape(Capsule())
    }

    private var displayName: String {
        if ref.hasPrefix("HEAD -> ") {
            return String(ref.dropFirst(8))
        } else if ref.hasPrefix("origin/") {
            return ref
        } else if ref.hasPrefix("tag: ") {
            return String(ref.dropFirst(5))
        }
        return ref
    }

    private var backgroundColor: Color {
        if ref.contains("HEAD") {
            return .purple
        } else if ref.hasPrefix("tag:") {
            return .orange
        } else if ref.contains("origin/") {
            return .blue
        } else {
            return .green
        }
    }
}

// MARK: - Preview

#Preview("Commit Graph") {
    let commits = [
        Commit(
            hash: "abc123def456789012345678901234567890abcd",
            message: "Merge branch 'feature/auth' into main",
            author: "John Doe",
            authorEmail: "john@example.com",
            date: Date(),
            parents: ["def456abc789", "789012def456"],
            refs: ["HEAD -> main", "origin/main"]
        ),
        Commit(
            hash: "def456abc789012345678901234567890abcdef",
            message: "Add authentication service",
            author: "Jane Smith",
            authorEmail: "jane@example.com",
            date: Date().addingTimeInterval(-3600),
            parents: ["ghi789abc012"]
        ),
        Commit(
            hash: "789012def456abc345678901234567890abcdef",
            message: "Implement login UI",
            author: "Jane Smith",
            authorEmail: "jane@example.com",
            date: Date().addingTimeInterval(-7200),
            parents: ["ghi789abc012"]
        ),
        Commit(
            hash: "ghi789abc012345678901234567890abcdefghi",
            message: "Initial commit",
            author: "John Doe",
            authorEmail: "john@example.com",
            date: Date().addingTimeInterval(-86400),
            parents: []
        ),
    ]

    return CommitGraphListView(
        commits: commits,
        selectedCommit: .constant(nil),
        onDoubleClick: { _ in }
    )
    .frame(width: 600, height: 400)
}
