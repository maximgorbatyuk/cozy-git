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
        // Maps commit hash to assigned lane
        var commitToLane: [String: Int] = [:]
        // Active lanes: lane index -> (expected commit hash, color)
        var activeLanes: [Int: (commitHash: String, color: Color)] = [:]
        var laneColors: [Int: Color] = [:]
        var colorIndex = 0

        // Build a set of all commit hashes for quick lookup
        let commitSet = Set(commits.map { $0.hash })

        for (row, commit) in commits.enumerated() {
            // Capture which lanes are active before processing this commit
            let continuingLanes = activeLanes.mapValues { $0.color }

            // Find or create lane for this commit
            var lane: Int
            var nodeColor: Color

            // Check if this commit was already assigned a lane (from a previous merge)
            if let assignedLane = commitToLane[commit.hash] {
                lane = assignedLane
                nodeColor = laneColors[lane] ?? BranchColors.color(for: colorIndex)
                // Remove from active since we're now processing it
                activeLanes.removeValue(forKey: lane)
            }
            // Check if any active lane is expecting this commit
            else if let (existingLane, _) = activeLanes.first(where: { $0.value.commitHash == commit.hash }) {
                lane = existingLane
                nodeColor = activeLanes[lane]?.color ?? laneColors[lane] ?? BranchColors.color(for: colorIndex)
                activeLanes.removeValue(forKey: lane)
            } else {
                // New commit not expected - try to use first parent's lane
                var preferredLane: Int?
                if let firstParent = commit.parents.first, commitSet.contains(firstParent) {
                    // Use first parent's lane for visual continuity
                    preferredLane = commitToLane[firstParent]
                }

                // Find best lane, preferring the parent's lane if available
                if let preferred = preferredLane, !activeLanes.keys.contains(preferred) {
                    // Parent's lane is available, use it
                    lane = preferred
                    nodeColor = laneColors[preferred] ?? BranchColors.color(for: colorIndex)
                } else {
                    // Parent's lane is occupied or no parent - find available lane
                    lane = findBestLane(activeLanes: activeLanes, commitToLane: commitToLane, excluding: preferredLane)
                    nodeColor = BranchColors.color(for: colorIndex)
                    colorIndex += 1
                }
            }

            laneColors[lane] = nodeColor
            commitToLane[commit.hash] = lane

            // Calculate parent lanes for drawing connections
            var parentLanes: [(String, Int, Int)] = []

            for (parentIndex, parentHash) in commit.parents.enumerated() {
                // Only process parents that are in our commit list
                guard commitSet.contains(parentHash) else { continue }

                if parentIndex == 0 {
                    // First parent continues on same lane
                    parentLanes.append((parentHash, lane, lane))
                    activeLanes[lane] = (commitHash: parentHash, color: nodeColor)
                    commitToLane[parentHash] = lane
                } else {
                    // Secondary parent (merge source)
                    let parentLane: Int

                    if let existingLane = commitToLane[parentHash] {
                        // Already assigned a lane
                        parentLane = existingLane
                    } else {
                        // Need to assign a lane for this parent
                        // Check if there are any OTHER active lanes (parallel branches)
                        let otherActiveLanes = activeLanes.filter { $0.key != lane }

                        if otherActiveLanes.isEmpty {
                            // No parallel branches - can potentially reuse a lane
                            // But we need a different lane than current for the merge curve
                            parentLane = findBestLane(activeLanes: activeLanes, commitToLane: commitToLane, excluding: lane)
                        } else {
                            // There are parallel branches - find available lane
                            parentLane = findBestLane(activeLanes: activeLanes, commitToLane: commitToLane, excluding: lane)
                        }

                        let parentColor = BranchColors.color(for: colorIndex)
                        colorIndex += 1
                        laneColors[parentLane] = parentColor

                        // Mark this lane as expecting the parent commit
                        activeLanes[parentLane] = (commitHash: parentHash, color: parentColor)
                        commitToLane[parentHash] = parentLane
                    }
                    parentLanes.append((parentHash, lane, parentLane))
                }
            }

            // If no parents in our list, this lane ends
            let hasParentsInList = commit.parents.contains { commitSet.contains($0) }
            if !hasParentsInList {
                activeLanes.removeValue(forKey: lane)
            }

            // Get active lanes AFTER processing this commit
            let currentActiveLanes = activeLanes.mapValues { $0.color }

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

    /// Find the best lane for a new commit
    /// Prefers lane 0 when possible, otherwise finds first available lane
    private static func findBestLane(activeLanes: [Int: (commitHash: String, color: Color)],
                                      commitToLane: [String: Int],
                                      excluding: Int? = nil) -> Int {
        let usedLanes = Set(activeLanes.keys)

        // Try lane 0 first if not excluded and not in use
        if excluding != 0 && !usedLanes.contains(0) {
            return 0
        }

        // Find first available lane
        var lane = 0
        while usedLanes.contains(lane) || lane == excluding {
            lane += 1
        }
        return lane
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
    var currentBranch: String?
    var onBranchClick: ((String, String?) -> Void)?
    var onCommitClick: (() -> Void)?
    var onCommitDoubleClick: (() -> Void)?

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
        .onTapGesture(count: 2) {
            onCommitDoubleClick?()
        }
        .onTapGesture(count: 1) {
            onCommitClick?()
        }
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
            // Message with branch/tag badges
            HStack(spacing: 6) {
                // Branch and tag badges
                ForEach(node.commit.refs, id: \.self) { ref in
                    refBadge(for: ref)
                }

                Text(node.commit.message.components(separatedBy: .newlines).first ?? node.commit.message)
                    .lineLimit(1)
                    .font(.system(.body))
            }

            // Metadata
            HStack(spacing: 8) {
                Text(node.commit.shortHash)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(node.commit.date.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(node.commit.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
    }

    private func refBadge(for ref: String) -> some View {
        let (displayName, icon, color, branchName, isRemoteBranch) = parseRef(ref)
        let isClickable = branchName != nil
        let isCurrentBranch = branchName != nil && branchName == currentBranch

        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(displayName)
                .font(.caption2)
                .fontWeight(isCurrentBranch ? .bold : .medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(isCurrentBranch ? 0.25 : 0.15))
        .foregroundColor(color)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(color, lineWidth: isCurrentBranch ? 2 : 0)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if isClickable && hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                if let branch = branchName {
                    onBranchClick?(branch, isRemoteBranch ? ref : nil)
                }
            }
        )
        .help(isCurrentBranch ? "Current branch" : (isClickable ? "Double-click to checkout '\(branchName ?? "")'" : ""))
    }

    /// Parse ref and return (displayName, icon, color, branchName for checkout, fullRemoteRef)
    /// branchName is nil for tags and HEAD-only refs
    /// fullRemoteRef is set for remote branches (e.g., "origin/feature-x")
    private func parseRef(_ ref: String) -> (name: String, icon: String, color: Color, branchName: String?, isRemote: Bool) {
        if ref.hasPrefix("HEAD -> ") {
            let branchName = String(ref.dropFirst(8))
            return (branchName, "arrowtriangle.right.fill", .purple, branchName, false)
        } else if ref.hasPrefix("tag: ") {
            let tagName = String(ref.dropFirst(5))
            return (tagName, "tag.fill", .orange, nil, false)
        } else if ref.hasPrefix("origin/") {
            // Remote branch - can checkout to create local tracking branch
            let branchName = String(ref.dropFirst(7)) // Remove "origin/"
            return (ref, "cloud.fill", .blue, branchName, true)
        } else if ref == "HEAD" {
            return (ref, "arrowtriangle.right.fill", .purple, nil, false)
        } else {
            // Local branch
            return (ref, "arrow.triangle.branch", .green, ref, false)
        }
    }
}

// MARK: - Commit Graph List View

/// Complete commit graph list with scrolling
struct CommitGraphListView: View {
    let commits: [Commit]
    @Binding var selectedCommit: Commit?
    let onDoubleClick: (Commit) -> Void
    var currentBranch: String?
    var onBranchClick: ((String, String?) -> Void)?

    @State private var nodes: [CommitGraphNode] = []
    @State private var maxLanes: Int = 1

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(nodes) { node in
                    CommitGraphRow(
                        node: node,
                        isSelected: selectedCommit?.hash == node.commit.hash,
                        maxLanes: maxLanes,
                        currentBranch: currentBranch,
                        onBranchClick: onBranchClick,
                        onCommitClick: {
                            selectedCommit = node.commit
                        },
                        onCommitDoubleClick: {
                            selectedCommit = node.commit
                            onDoubleClick(node.commit)
                        }
                    )

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
