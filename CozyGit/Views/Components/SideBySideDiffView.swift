//
//  SideBySideDiffView.swift
//  CozyGit
//
//  Phase 9: Side-by-Side Diff Viewer

import SwiftUI

// MARK: - Aligned Line Model

/// Represents a pair of aligned lines for side-by-side comparison
struct AlignedDiffLine: Identifiable {
    let id = UUID()

    /// Left side (old) line content
    let oldLine: DiffLine?

    /// Right side (new) line content
    let newLine: DiffLine?

    /// Type of change for this aligned pair
    var changeType: AlignedChangeType {
        switch (oldLine, newLine) {
        case (nil, .some):
            return .addition
        case (.some, nil):
            return .deletion
        case let (.some(old), .some(new)):
            if old.type == .context && new.type == .context {
                return .context
            } else {
                return .modification
            }
        case (nil, nil):
            return .context
        }
    }
}

/// Type of change for an aligned line pair
enum AlignedChangeType {
    case context
    case addition
    case deletion
    case modification

    var leftBackground: Color {
        switch self {
        case .deletion, .modification:
            return Color.red.opacity(0.15)
        default:
            return .clear
        }
    }

    var rightBackground: Color {
        switch self {
        case .addition, .modification:
            return Color.green.opacity(0.15)
        default:
            return .clear
        }
    }
}

// MARK: - Word Diff

/// Represents a word segment with its change status
struct WordSegment: Identifiable {
    let id = UUID()
    let text: String
    let isChanged: Bool
}

/// Word-level diff calculator
struct WordDiff {
    /// Compare two strings and return word segments highlighting differences
    static func compare(old: String, new: String) -> (oldSegments: [WordSegment], newSegments: [WordSegment]) {
        let oldWords = tokenize(old)
        let newWords = tokenize(new)

        // Use LCS (Longest Common Subsequence) to find matching words
        let lcs = longestCommonSubsequence(oldWords, newWords)

        var oldSegments: [WordSegment] = []
        var newSegments: [WordSegment] = []

        var lcsIndex = 0
        var oldIndex = 0
        var newIndex = 0

        while oldIndex < oldWords.count || newIndex < newWords.count {
            if lcsIndex < lcs.count {
                // Collect changed words before the next LCS word
                while oldIndex < oldWords.count && oldWords[oldIndex] != lcs[lcsIndex] {
                    oldSegments.append(WordSegment(text: oldWords[oldIndex], isChanged: true))
                    oldIndex += 1
                }
                while newIndex < newWords.count && newWords[newIndex] != lcs[lcsIndex] {
                    newSegments.append(WordSegment(text: newWords[newIndex], isChanged: true))
                    newIndex += 1
                }

                // Add the matching LCS word
                if oldIndex < oldWords.count && newIndex < newWords.count {
                    oldSegments.append(WordSegment(text: oldWords[oldIndex], isChanged: false))
                    newSegments.append(WordSegment(text: newWords[newIndex], isChanged: false))
                    oldIndex += 1
                    newIndex += 1
                    lcsIndex += 1
                }
            } else {
                // Remaining words after LCS
                while oldIndex < oldWords.count {
                    oldSegments.append(WordSegment(text: oldWords[oldIndex], isChanged: true))
                    oldIndex += 1
                }
                while newIndex < newWords.count {
                    newSegments.append(WordSegment(text: newWords[newIndex], isChanged: true))
                    newIndex += 1
                }
            }
        }

        return (oldSegments, newSegments)
    }

    /// Tokenize a string into words (preserving whitespace as separate tokens)
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var inWhitespace = false

        for char in text {
            let isWhitespace = char.isWhitespace
            if isWhitespace != inWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                }
                currentToken = String(char)
                inWhitespace = isWhitespace
            } else {
                currentToken.append(char)
            }
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    /// Find the longest common subsequence of two arrays
    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count

        if m == 0 || n == 0 {
            return []
        }

        // Build LCS table
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack to find LCS
        var lcs: [String] = []
        var i = m
        var j = n

        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                lcs.insert(a[i - 1], at: 0)
                i -= 1
                j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        return lcs
    }
}

// MARK: - Diff View Settings

/// Settings for diff view display
@Observable
class DiffViewSettings {
    /// Show line numbers
    var showLineNumbers: Bool = true

    /// Enable word-level diff highlighting
    var wordLevelDiff: Bool = true

    /// Show whitespace changes
    var showWhitespace: Bool = false

    /// Show only changed lines (hide context)
    var showOnlyChanged: Bool = false

    /// Current view mode
    var viewMode: DiffViewMode = .sideBySide
}

/// Diff view display mode
enum DiffViewMode: String, CaseIterable {
    case unified = "Unified"
    case sideBySide = "Side by Side"

    var icon: String {
        switch self {
        case .unified:
            return "text.alignleft"
        case .sideBySide:
            return "rectangle.split.2x1"
        }
    }
}

// MARK: - Line Alignment

/// Aligns lines from a FileDiff for side-by-side display
struct LineAligner {
    /// Align lines from hunks for side-by-side comparison
    static func alignLines(from fileDiff: FileDiff) -> [AlignedDiffLine] {
        var alignedLines: [AlignedDiffLine] = []

        for hunk in fileDiff.hunks {
            alignedLines.append(contentsOf: alignHunkLines(hunk.lines))
        }

        return alignedLines
    }

    /// Align lines within a single hunk
    private static func alignHunkLines(_ lines: [DiffLine]) -> [AlignedDiffLine] {
        var aligned: [AlignedDiffLine] = []
        var pendingDeletions: [DiffLine] = []
        var pendingAdditions: [DiffLine] = []

        for line in lines {
            switch line.type {
            case .context:
                // Flush pending changes before context
                aligned.append(contentsOf: matchPendingChanges(&pendingDeletions, &pendingAdditions))
                aligned.append(AlignedDiffLine(oldLine: line, newLine: line))

            case .deletion:
                pendingDeletions.append(line)

            case .addition:
                pendingAdditions.append(line)

            case .hunkHeader, .noNewline:
                // Skip header lines in alignment
                break
            }
        }

        // Flush any remaining pending changes
        aligned.append(contentsOf: matchPendingChanges(&pendingDeletions, &pendingAdditions))

        return aligned
    }

    /// Match pending deletions and additions into aligned pairs
    private static func matchPendingChanges(_ deletions: inout [DiffLine], _ additions: inout [DiffLine]) -> [AlignedDiffLine] {
        var aligned: [AlignedDiffLine] = []

        // Match deletions with additions where possible
        let matchCount = min(deletions.count, additions.count)

        for i in 0..<matchCount {
            aligned.append(AlignedDiffLine(oldLine: deletions[i], newLine: additions[i]))
        }

        // Add remaining deletions (no matching addition)
        for i in matchCount..<deletions.count {
            aligned.append(AlignedDiffLine(oldLine: deletions[i], newLine: nil))
        }

        // Add remaining additions (no matching deletion)
        for i in matchCount..<additions.count {
            aligned.append(AlignedDiffLine(oldLine: nil, newLine: additions[i]))
        }

        deletions.removeAll()
        additions.removeAll()

        return aligned
    }
}

// MARK: - Synchronized Scroll State

/// Manages synchronized scrolling between two panels
@Observable
class SyncScrollState {
    var scrollOffset: CGPoint = .zero
    var isScrolling: Bool = false

    private var debounceTask: Task<Void, Never>?

    func updateOffset(_ newOffset: CGPoint) {
        scrollOffset = newOffset
        isScrolling = true

        // Debounce the scroll end detection
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if !Task.isCancelled {
                self.isScrolling = false
            }
        }
    }
}

// MARK: - Side by Side Diff View

/// A side-by-side diff view component that displays file changes in two columns
struct SideBySideDiffView: View {
    let fileDiff: FileDiff
    @State private var settings = DiffViewSettings()
    @State private var scrollState = SyncScrollState()
    @State private var dividerPosition: CGFloat = 0.5
    @State private var currentChangeIndex: Int = 0
    @State private var cachedAlignedLines: [AlignedDiffLine]?

    private var alignedLines: [AlignedDiffLine] {
        if let cached = cachedAlignedLines {
            return cached
        }
        // Use optimized line aligner with caching
        return OptimizedLineAligner.alignLines(from: fileDiff)
    }

    /// Indices of lines that have changes (not context)
    private var changeIndices: [Int] {
        alignedLines.enumerated().compactMap { index, line in
            line.changeType != .context ? index : nil
        }
    }

    /// Total number of change blocks
    private var changeCount: Int {
        changeIndices.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with file info and settings
            fileHeader

            Divider()

            // Content
            if fileDiff.isBinary {
                binaryFileView
            } else if fileDiff.hunks.isEmpty {
                emptyDiffView
            } else {
                diffContent
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Navigation

    private func navigateToNextChange() {
        guard !changeIndices.isEmpty else { return }
        currentChangeIndex = min(currentChangeIndex + 1, changeIndices.count - 1)
    }

    private func navigateToPreviousChange() {
        guard !changeIndices.isEmpty else { return }
        currentChangeIndex = max(currentChangeIndex - 1, 0)
    }

    // MARK: - File Header

    private var fileHeader: some View {
        HStack {
            // File icon and path
            HStack(spacing: 8) {
                fileStatusIcon

                Text(fileDiff.displayName)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Stats
            HStack(spacing: 12) {
                if fileDiff.additions > 0 {
                    Text("+\(fileDiff.additions)")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                if fileDiff.deletions > 0 {
                    Text("-\(fileDiff.deletions)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
            }

            // Settings buttons
            settingsButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var settingsButtons: some View {
        HStack(spacing: 8) {
            // Change navigation
            if changeCount > 0 {
                HStack(spacing: 4) {
                    Button {
                        navigateToPreviousChange()
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(currentChangeIndex <= 0)
                    .help("Previous change (Cmd+Up)")

                    Text("\(currentChangeIndex + 1)/\(changeCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40)

                    Button {
                        navigateToNextChange()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(currentChangeIndex >= changeCount - 1)
                    .help("Next change (Cmd+Down)")
                }

                Divider()
                    .frame(height: 16)
            }

            // Line numbers toggle
            Button {
                settings.showLineNumbers.toggle()
            } label: {
                Image(systemName: settings.showLineNumbers ? "number.square.fill" : "number.square")
            }
            .buttonStyle(.borderless)
            .help(settings.showLineNumbers ? "Hide line numbers" : "Show line numbers")

            // Word diff toggle
            Button {
                settings.wordLevelDiff.toggle()
            } label: {
                Image(systemName: settings.wordLevelDiff ? "character.textbox" : "textformat")
            }
            .buttonStyle(.borderless)
            .help(settings.wordLevelDiff ? "Disable word-level diff" : "Enable word-level diff")
        }
    }

    private var fileStatusIcon: some View {
        Group {
            if fileDiff.isNewFile {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
            } else if fileDiff.isDeletedFile {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            } else if fileDiff.isRenamed {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Diff Content

    private var diffContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Panel headers
                HStack(spacing: 0) {
                    Text("Original")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: geometry.size.width * dividerPosition - 2)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 4)

                    Text("Modified")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: geometry.size.width * (1 - dividerPosition) - 2)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                }

                Divider()

                // Synchronized scroll content - single ScrollView for both panels
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(alignedLines) { alignedLine in
                            HStack(spacing: 0) {
                                // Left panel line
                                leftLineView(alignedLine)
                                    .frame(width: geometry.size.width * dividerPosition - 2)

                                // Divider
                                Rectangle()
                                    .fill(Color(nsColor: .separatorColor))
                                    .frame(width: 4)

                                // Right panel line
                                rightLineView(alignedLine)
                                    .frame(width: geometry.size.width * (1 - dividerPosition) - 2)
                            }
                        }
                    }
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 4)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newPosition = dividerPosition + value.translation.width / 800
                        dividerPosition = max(0.2, min(0.8, newPosition))
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Line Views

    private func leftLineView(_ alignedLine: AlignedDiffLine) -> some View {
        HStack(spacing: 0) {
            // Line number
            if settings.showLineNumbers {
                Text(alignedLine.oldLine?.oldLineNumber.map { "\($0)" } ?? "")
                    .frame(width: 50, alignment: .trailing)
                    .padding(.horizontal, 4)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .background(lineNumberBackground(for: alignedLine.changeType, isLeft: true))
            }

            // Gutter indicator
            Text(gutterIndicator(for: alignedLine, isLeft: true))
                .frame(width: 20, alignment: .center)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(gutterColor(for: alignedLine.changeType, isLeft: true))
                .background(alignedLine.changeType.leftBackground)

            // Line content
            if let oldLine = alignedLine.oldLine, alignedLine.changeType == .modification, settings.wordLevelDiff {
                wordDiffView(oldLine: oldLine, newLine: alignedLine.newLine, isLeft: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alignedLine.changeType.leftBackground)
            } else {
                Text(alignedLine.oldLine?.content ?? "")
                    .font(.system(.body, design: .monospaced))
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alignedLine.changeType.leftBackground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 22)
    }

    private func rightLineView(_ alignedLine: AlignedDiffLine) -> some View {
        HStack(spacing: 0) {
            // Line number
            if settings.showLineNumbers {
                Text(alignedLine.newLine?.newLineNumber.map { "\($0)" } ?? "")
                    .frame(width: 50, alignment: .trailing)
                    .padding(.horizontal, 4)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .background(lineNumberBackground(for: alignedLine.changeType, isLeft: false))
            }

            // Gutter indicator
            Text(gutterIndicator(for: alignedLine, isLeft: false))
                .frame(width: 20, alignment: .center)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(gutterColor(for: alignedLine.changeType, isLeft: false))
                .background(alignedLine.changeType.rightBackground)

            // Line content
            if let newLine = alignedLine.newLine, alignedLine.changeType == .modification, settings.wordLevelDiff {
                wordDiffView(oldLine: alignedLine.oldLine, newLine: newLine, isLeft: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alignedLine.changeType.rightBackground)
            } else {
                Text(alignedLine.newLine?.content ?? "")
                    .font(.system(.body, design: .monospaced))
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alignedLine.changeType.rightBackground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 22)
    }

    private func wordDiffView(oldLine: DiffLine?, newLine: DiffLine?, isLeft: Bool) -> some View {
        let oldContent = oldLine?.content ?? ""
        let newContent = newLine?.content ?? ""
        // Use optimized word diff with caching
        let (oldSegments, newSegments) = OptimizedWordDiff.compare(old: oldContent, new: newContent)

        return HStack(spacing: 0) {
            ForEach(isLeft ? oldSegments : newSegments) { segment in
                Text(segment.text)
                    .font(.system(.body, design: .monospaced))
                    .background(
                        segment.isChanged
                            ? (isLeft ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                            : Color.clear
                    )
            }
            Spacer()
        }
        .padding(.trailing, 8)
    }

    private func gutterIndicator(for alignedLine: AlignedDiffLine, isLeft: Bool) -> String {
        switch alignedLine.changeType {
        case .deletion:
            return isLeft ? "-" : ""
        case .addition:
            return isLeft ? "" : "+"
        case .modification:
            return isLeft ? "-" : "+"
        case .context:
            return ""
        }
    }

    private func gutterColor(for changeType: AlignedChangeType, isLeft: Bool) -> Color {
        switch changeType {
        case .deletion:
            return .red
        case .addition:
            return .green
        case .modification:
            return isLeft ? .red : .green
        case .context:
            return .secondary
        }
    }

    private func lineNumberBackground(for changeType: AlignedChangeType, isLeft: Bool) -> Color {
        let baseColor = Color(nsColor: .controlBackgroundColor).opacity(0.5)

        switch changeType {
        case .deletion, .modification:
            return isLeft ? Color.red.opacity(0.1) : baseColor
        case .addition:
            return isLeft ? baseColor : Color.green.opacity(0.1)
        case .context:
            return baseColor
        }
    }

    // MARK: - Special Views

    private var binaryFileView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("Binary file")
                .font(.headline)

            Text("Binary files cannot be displayed in diff view")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyDiffView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.green)

            Text("No changes")
                .font(.headline)

            Text("This file has no differences")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Diff View Container (Toggle between Unified and Side-by-Side)

/// Container view that allows toggling between unified and side-by-side diff views
struct DiffViewContainer: View {
    let fileDiff: FileDiff
    @State private var viewMode: DiffViewMode = .sideBySide

    var body: some View {
        VStack(spacing: 0) {
            // View mode toggle
            viewModeToggle

            Divider()

            // Content based on mode
            Group {
                switch viewMode {
                case .unified:
                    UnifiedDiffView(fileDiff: fileDiff)
                case .sideBySide:
                    SideBySideDiffView(fileDiff: fileDiff)
                }
            }
        }
    }

    private var viewModeToggle: some View {
        HStack {
            Spacer()

            Picker("View Mode", selection: $viewMode) {
                ForEach(DiffViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Multi-File Diff View with Toggle

/// Enhanced multi-file diff view with mode toggle
struct EnhancedMultiFileDiffView: View {
    let diff: Diff
    @State private var selectedFileIndex: Int = 0
    @State private var viewMode: DiffViewMode = .sideBySide

    var body: some View {
        if diff.isEmpty {
            emptyView
        } else {
            HSplitView {
                // File list
                fileList
                    .frame(minWidth: 200, maxWidth: 300)

                // Selected file diff
                VStack(spacing: 0) {
                    // View mode toggle
                    viewModeToggle

                    Divider()

                    if selectedFileIndex < diff.files.count {
                        switch viewMode {
                        case .unified:
                            UnifiedDiffView(fileDiff: diff.files[selectedFileIndex])
                        case .sideBySide:
                            SideBySideDiffView(fileDiff: diff.files[selectedFileIndex])
                        }
                    } else {
                        Text("Select a file to view diff")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }

    private var viewModeToggle: some View {
        HStack {
            Spacer()

            Picker("View Mode", selection: $viewMode) {
                ForEach(DiffViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var fileList: some View {
        List(selection: $selectedFileIndex) {
            ForEach(Array(diff.files.enumerated()), id: \.offset) { index, file in
                HStack {
                    fileStatusIcon(for: file)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.displayName)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        HStack(spacing: 8) {
                            if file.additions > 0 {
                                Text("+\(file.additions)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            if file.deletions > 0 {
                                Text("-\(file.deletions)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Spacer()
                }
                .tag(index)
                .padding(.vertical, 2)
            }
        }
        .listStyle(.sidebar)
    }

    private func fileStatusIcon(for file: FileDiff) -> some View {
        Group {
            if file.isNewFile {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
            } else if file.isDeletedFile {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            } else if file.isRenamed {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            } else if file.isBinary {
                Image(systemName: "doc.zipper")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("No changes")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Working directory is clean")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Side by Side Diff") {
    let lines = [
        DiffLine(type: .context, content: "import Foundation", oldLineNumber: 1, newLineNumber: 1),
        DiffLine(type: .context, content: "", oldLineNumber: 2, newLineNumber: 2),
        DiffLine(type: .deletion, content: "func oldFunction() {", oldLineNumber: 3, newLineNumber: nil),
        DiffLine(type: .addition, content: "func newFunction() {", oldLineNumber: nil, newLineNumber: 3),
        DiffLine(type: .context, content: "    print(\"Hello\")", oldLineNumber: 4, newLineNumber: 4),
        DiffLine(type: .deletion, content: "    let x = 5", oldLineNumber: 5, newLineNumber: nil),
        DiffLine(type: .addition, content: "    let x = 10", oldLineNumber: nil, newLineNumber: 5),
        DiffLine(type: .addition, content: "    print(\"World\")", oldLineNumber: nil, newLineNumber: 6),
        DiffLine(type: .context, content: "}", oldLineNumber: 6, newLineNumber: 7),
    ]

    let hunk = DiffHunk(oldStart: 1, oldCount: 6, newStart: 1, newCount: 7, header: "func example()", lines: lines)
    let fileDiff = FileDiff(oldPath: "Example.swift", newPath: "Example.swift", hunks: [hunk])

    return SideBySideDiffView(fileDiff: fileDiff)
        .frame(width: 1000, height: 400)
}

#Preview("Diff View Container") {
    let lines = [
        DiffLine(type: .context, content: "import Foundation", oldLineNumber: 1, newLineNumber: 1),
        DiffLine(type: .deletion, content: "let message = \"Hello\"", oldLineNumber: 2, newLineNumber: nil),
        DiffLine(type: .addition, content: "let message = \"Hello World\"", oldLineNumber: nil, newLineNumber: 2),
    ]

    let hunk = DiffHunk(oldStart: 1, oldCount: 2, newStart: 1, newCount: 2, lines: lines)
    let fileDiff = FileDiff(oldPath: "Test.swift", newPath: "Test.swift", hunks: [hunk])

    return DiffViewContainer(fileDiff: fileDiff)
        .frame(width: 1000, height: 400)
}
