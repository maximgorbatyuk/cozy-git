//
//  DiffOptimizations.swift
//  CozyGit
//
//  Phase 19: Performance Optimization - Diff Optimizations

import Foundation

// MARK: - Optimized Line Aligner

/// Optimized version of line alignment with caching
enum OptimizedLineAligner {
    /// Cache for aligned lines
    private static var alignmentCache = [String: [AlignedDiffLine]]()
    private static let cacheLimit = 50

    /// Align lines from a FileDiff with caching
    static func alignLines(from fileDiff: FileDiff) -> [AlignedDiffLine] {
        let cacheKey = generateCacheKey(for: fileDiff)

        if let cached = alignmentCache[cacheKey] {
            return cached
        }

        let aligned = computeAlignedLines(from: fileDiff)

        // Manage cache size
        if alignmentCache.count >= cacheLimit {
            // Remove oldest entries (simple FIFO)
            let keysToRemove = alignmentCache.keys.prefix(10)
            for key in keysToRemove {
                alignmentCache.removeValue(forKey: key)
            }
        }

        alignmentCache[cacheKey] = aligned
        return aligned
    }

    /// Clear the alignment cache
    static func clearCache() {
        alignmentCache.removeAll()
    }

    private static func generateCacheKey(for fileDiff: FileDiff) -> String {
        // Use file paths and hunk count as cache key
        return "\(fileDiff.oldPath):\(fileDiff.newPath):\(fileDiff.hunks.count):\(fileDiff.hunks.map { $0.lines.count }.reduce(0, +))"
    }

    private static func computeAlignedLines(from fileDiff: FileDiff) -> [AlignedDiffLine] {
        var alignedLines: [AlignedDiffLine] = []
        alignedLines.reserveCapacity(fileDiff.hunks.reduce(0) { $0 + $1.lines.count })

        for hunk in fileDiff.hunks {
            alignedLines.append(contentsOf: alignHunkLines(hunk.lines))
        }

        return alignedLines
    }

    private static func alignHunkLines(_ lines: [DiffLine]) -> [AlignedDiffLine] {
        var aligned: [AlignedDiffLine] = []
        aligned.reserveCapacity(lines.count)

        var pendingDeletions: [DiffLine] = []
        var pendingAdditions: [DiffLine] = []

        for line in lines {
            switch line.type {
            case .context:
                aligned.append(contentsOf: matchPendingChanges(&pendingDeletions, &pendingAdditions))
                aligned.append(AlignedDiffLine(oldLine: line, newLine: line))

            case .deletion:
                pendingDeletions.append(line)

            case .addition:
                pendingAdditions.append(line)

            case .hunkHeader, .noNewline:
                break
            }
        }

        aligned.append(contentsOf: matchPendingChanges(&pendingDeletions, &pendingAdditions))
        return aligned
    }

    private static func matchPendingChanges(_ deletions: inout [DiffLine], _ additions: inout [DiffLine]) -> [AlignedDiffLine] {
        var aligned: [AlignedDiffLine] = []
        aligned.reserveCapacity(max(deletions.count, additions.count))

        let matchCount = min(deletions.count, additions.count)

        for i in 0..<matchCount {
            aligned.append(AlignedDiffLine(oldLine: deletions[i], newLine: additions[i]))
        }

        for i in matchCount..<deletions.count {
            aligned.append(AlignedDiffLine(oldLine: deletions[i], newLine: nil))
        }

        for i in matchCount..<additions.count {
            aligned.append(AlignedDiffLine(oldLine: nil, newLine: additions[i]))
        }

        deletions.removeAll(keepingCapacity: true)
        additions.removeAll(keepingCapacity: true)

        return aligned
    }
}

// MARK: - Optimized Word Diff

/// Optimized word-level diff with caching
enum OptimizedWordDiff {
    /// Cache for word diff results
    private static var diffCache = [String: (oldSegments: [WordSegment], newSegments: [WordSegment])]()
    private static let cacheLimit = 200

    /// Compare two strings with caching
    static func compare(old: String, new: String) -> (oldSegments: [WordSegment], newSegments: [WordSegment]) {
        let cacheKey = "\(old.hashValue):\(new.hashValue)"

        if let cached = diffCache[cacheKey] {
            return cached
        }

        let result = computeDiff(old: old, new: new)

        // Manage cache size
        if diffCache.count >= cacheLimit {
            let keysToRemove = diffCache.keys.prefix(50)
            for key in keysToRemove {
                diffCache.removeValue(forKey: key)
            }
        }

        diffCache[cacheKey] = result
        return result
    }

    /// Clear the diff cache
    static func clearCache() {
        diffCache.removeAll()
    }

    private static func computeDiff(old: String, new: String) -> (oldSegments: [WordSegment], newSegments: [WordSegment]) {
        // Fast path: identical strings
        if old == new {
            let segment = WordSegment(text: old, isChanged: false)
            return ([segment], [segment])
        }

        // Fast path: one is empty
        if old.isEmpty {
            return ([], [WordSegment(text: new, isChanged: true)])
        }
        if new.isEmpty {
            return ([WordSegment(text: old, isChanged: true)], [])
        }

        // Fast path: very long strings - use simplified diff
        if old.count > 1000 || new.count > 1000 {
            return simplifiedDiff(old: old, new: new)
        }

        let oldWords = tokenize(old)
        let newWords = tokenize(new)

        // Use optimized LCS
        let lcs = optimizedLCS(oldWords, newWords)

        return buildSegments(oldWords: oldWords, newWords: newWords, lcs: lcs)
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        tokens.reserveCapacity(text.count / 4) // Rough estimate

        var currentToken = ""
        currentToken.reserveCapacity(20)
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

    private static func optimizedLCS(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count

        if m == 0 || n == 0 { return [] }

        // For very long sequences, use a space-optimized approach
        if m > 100 || n > 100 {
            return spaceSavingLCS(a, b)
        }

        // Standard DP approach
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

        // Backtrack
        var lcs: [String] = []
        lcs.reserveCapacity(min(m, n))
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

    private static func spaceSavingLCS(_ a: [String], _ b: [String]) -> [String] {
        // Use only O(min(m,n)) space
        let (shorter, longer) = a.count <= b.count ? (a, b) : (b, a)
        let m = shorter.count
        let n = longer.count

        var prev = [Int](repeating: 0, count: m + 1)
        var curr = [Int](repeating: 0, count: m + 1)

        for j in 1...n {
            for i in 1...m {
                if shorter[i - 1] == longer[j - 1] {
                    curr[i] = prev[i - 1] + 1
                } else {
                    curr[i] = max(prev[i], curr[i - 1])
                }
            }
            swap(&prev, &curr)
            curr = [Int](repeating: 0, count: m + 1)
        }

        // Simplified: just return matching words (not full LCS reconstruction)
        return shorter.filter { longer.contains($0) }
    }

    private static func buildSegments(
        oldWords: [String],
        newWords: [String],
        lcs: [String]
    ) -> (oldSegments: [WordSegment], newSegments: [WordSegment]) {
        var oldSegments: [WordSegment] = []
        var newSegments: [WordSegment] = []

        oldSegments.reserveCapacity(oldWords.count)
        newSegments.reserveCapacity(newWords.count)

        var lcsIndex = 0
        var oldIndex = 0
        var newIndex = 0

        while oldIndex < oldWords.count || newIndex < newWords.count {
            if lcsIndex < lcs.count {
                while oldIndex < oldWords.count && oldWords[oldIndex] != lcs[lcsIndex] {
                    oldSegments.append(WordSegment(text: oldWords[oldIndex], isChanged: true))
                    oldIndex += 1
                }
                while newIndex < newWords.count && newWords[newIndex] != lcs[lcsIndex] {
                    newSegments.append(WordSegment(text: newWords[newIndex], isChanged: true))
                    newIndex += 1
                }

                if oldIndex < oldWords.count && newIndex < newWords.count {
                    oldSegments.append(WordSegment(text: oldWords[oldIndex], isChanged: false))
                    newSegments.append(WordSegment(text: newWords[newIndex], isChanged: false))
                    oldIndex += 1
                    newIndex += 1
                    lcsIndex += 1
                }
            } else {
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

    private static func simplifiedDiff(old: String, new: String) -> (oldSegments: [WordSegment], newSegments: [WordSegment]) {
        // For very long strings, just mark everything as changed
        return (
            [WordSegment(text: old, isChanged: true)],
            [WordSegment(text: new, isChanged: true)]
        )
    }
}

// MARK: - Diff Chunking

/// Utilities for chunking large diffs
enum DiffChunker {
    /// Chunk a large diff into smaller pieces for incremental rendering
    static func chunk(_ fileDiff: FileDiff, chunkSize: Int = 100) -> [[DiffLine]] {
        var chunks: [[DiffLine]] = []
        var currentChunk: [DiffLine] = []
        currentChunk.reserveCapacity(chunkSize)

        for hunk in fileDiff.hunks {
            for line in hunk.lines {
                currentChunk.append(line)

                if currentChunk.count >= chunkSize {
                    chunks.append(currentChunk)
                    currentChunk = []
                    currentChunk.reserveCapacity(chunkSize)
                }
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    /// Get total line count for a diff
    static func lineCount(_ fileDiff: FileDiff) -> Int {
        fileDiff.hunks.reduce(0) { $0 + $1.lines.count }
    }

    /// Check if diff is large (might need chunking)
    static func isLargeDiff(_ fileDiff: FileDiff, threshold: Int = 500) -> Bool {
        lineCount(fileDiff) > threshold
    }
}

// MARK: - Syntax Highlighting Cache

/// Cache for syntax-highlighted content
actor SyntaxHighlightCache {
    private var cache: [String: NSAttributedString] = [:]
    private let maxEntries: Int

    init(maxEntries: Int = 500) {
        self.maxEntries = maxEntries
    }

    func get(key: String) -> NSAttributedString? {
        cache[key]
    }

    func set(key: String, value: NSAttributedString) {
        if cache.count >= maxEntries {
            // Remove random 10% to avoid constant eviction
            let keysToRemove = cache.keys.prefix(maxEntries / 10)
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
        cache[key] = value
    }

    func clear() {
        cache.removeAll()
    }
}
