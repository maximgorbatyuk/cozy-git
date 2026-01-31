//
//  PerformanceCache.swift
//  CozyGit
//
//  Phase 19: Performance Optimization - Caching System

import Foundation

// MARK: - Cache Entry

/// A cache entry with value and expiration time
struct CacheEntry<Value> {
    let value: Value
    let timestamp: Date
    let ttl: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

// MARK: - Generic Cache

/// Thread-safe generic cache with TTL support
actor GenericCache<Key: Hashable, Value> {
    private var storage: [Key: CacheEntry<Value>] = [:]
    private let defaultTTL: TimeInterval
    private let maxSize: Int

    init(defaultTTL: TimeInterval = 60.0, maxSize: Int = 100) {
        self.defaultTTL = defaultTTL
        self.maxSize = maxSize
    }

    /// Get a value from cache
    func get(_ key: Key) -> Value? {
        guard let entry = storage[key] else { return nil }

        if entry.isExpired {
            storage.removeValue(forKey: key)
            return nil
        }

        return entry.value
    }

    /// Set a value in cache
    func set(_ key: Key, value: Value, ttl: TimeInterval? = nil) {
        // Evict oldest entries if cache is full
        if storage.count >= maxSize {
            evictOldest()
        }

        storage[key] = CacheEntry(
            value: value,
            timestamp: Date(),
            ttl: ttl ?? defaultTTL
        )
    }

    /// Remove a value from cache
    func remove(_ key: Key) {
        storage.removeValue(forKey: key)
    }

    /// Clear all cache entries
    func clear() {
        storage.removeAll()
    }

    /// Remove expired entries
    func pruneExpired() {
        storage = storage.filter { !$0.value.isExpired }
    }

    /// Get cache statistics
    func stats() -> CacheStats {
        let expired = storage.values.filter { $0.isExpired }.count
        return CacheStats(
            totalEntries: storage.count,
            expiredEntries: expired,
            validEntries: storage.count - expired
        )
    }

    private func evictOldest() {
        // First, remove expired entries
        pruneExpired()

        // If still full, remove oldest 10%
        if storage.count >= maxSize {
            let sortedKeys = storage.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = max(1, maxSize / 10)
            for (key, _) in sortedKeys.prefix(toRemove) {
                storage.removeValue(forKey: key)
            }
        }
    }
}

/// Cache statistics
struct CacheStats {
    let totalEntries: Int
    let expiredEntries: Int
    let validEntries: Int
}

// MARK: - Repository Cache

/// Specialized cache for repository data
actor RepositoryCache {
    // Caches for different data types
    private let branchCache = GenericCache<String, [Branch]>(defaultTTL: 30.0, maxSize: 10)
    private let commitCache = GenericCache<String, [Commit]>(defaultTTL: 60.0, maxSize: 10)
    private let statusCache = GenericCache<String, [FileStatus]>(defaultTTL: 10.0, maxSize: 10)
    private let diffCache = GenericCache<String, Diff>(defaultTTL: 30.0, maxSize: 20)
    private let fileDiffCache = GenericCache<String, FileDiff>(defaultTTL: 30.0, maxSize: 50)
    private let tagCache = GenericCache<String, [Tag]>(defaultTTL: 60.0, maxSize: 10)
    private let stashCache = GenericCache<String, [Stash]>(defaultTTL: 30.0, maxSize: 10)
    private let remoteStatusCache = GenericCache<String, RemoteTrackingStatus>(defaultTTL: 15.0, maxSize: 10)

    // MARK: - Branch Cache

    func getBranches(for repoPath: String) async -> [Branch]? {
        await branchCache.get(repoPath)
    }

    func setBranches(_ branches: [Branch], for repoPath: String) async {
        await branchCache.set(repoPath, value: branches)
    }

    func invalidateBranches(for repoPath: String) async {
        await branchCache.remove(repoPath)
    }

    // MARK: - Commit Cache

    func getCommits(for repoPath: String, limit: Int) async -> [Commit]? {
        let key = "\(repoPath):\(limit)"
        return await commitCache.get(key)
    }

    func setCommits(_ commits: [Commit], for repoPath: String, limit: Int) async {
        let key = "\(repoPath):\(limit)"
        await commitCache.set(key, value: commits)
    }

    func invalidateCommits(for repoPath: String) async {
        await commitCache.clear()
    }

    // MARK: - Status Cache

    func getStatus(for repoPath: String) async -> [FileStatus]? {
        await statusCache.get(repoPath)
    }

    func setStatus(_ status: [FileStatus], for repoPath: String) async {
        await statusCache.set(repoPath, value: status)
    }

    func invalidateStatus(for repoPath: String) async {
        await statusCache.remove(repoPath)
    }

    // MARK: - Diff Cache

    func getDiff(for key: String) async -> Diff? {
        await diffCache.get(key)
    }

    func setDiff(_ diff: Diff, for key: String) async {
        await diffCache.set(key, value: diff)
    }

    func getFileDiff(for key: String) async -> FileDiff? {
        await fileDiffCache.get(key)
    }

    func setFileDiff(_ diff: FileDiff, for key: String) async {
        await fileDiffCache.set(key, value: diff)
    }

    func invalidateDiffs() async {
        await diffCache.clear()
        await fileDiffCache.clear()
    }

    // MARK: - Tag Cache

    func getTags(for repoPath: String) async -> [Tag]? {
        await tagCache.get(repoPath)
    }

    func setTags(_ tags: [Tag], for repoPath: String) async {
        await tagCache.set(repoPath, value: tags)
    }

    func invalidateTags(for repoPath: String) async {
        await tagCache.remove(repoPath)
    }

    // MARK: - Stash Cache

    func getStashes(for repoPath: String) async -> [Stash]? {
        await stashCache.get(repoPath)
    }

    func setStashes(_ stashes: [Stash], for repoPath: String) async {
        await stashCache.set(repoPath, value: stashes)
    }

    func invalidateStashes(for repoPath: String) async {
        await stashCache.remove(repoPath)
    }

    // MARK: - Remote Status Cache

    func getRemoteStatus(for repoPath: String) async -> RemoteTrackingStatus? {
        await remoteStatusCache.get(repoPath)
    }

    func setRemoteStatus(_ status: RemoteTrackingStatus, for repoPath: String) async {
        await remoteStatusCache.set(repoPath, value: status)
    }

    func invalidateRemoteStatus(for repoPath: String) async {
        await remoteStatusCache.remove(repoPath)
    }

    // MARK: - Global Operations

    /// Invalidate all caches for a repository
    func invalidateAll(for repoPath: String) async {
        await branchCache.remove(repoPath)
        await commitCache.clear() // Clear all commits as they're keyed by path:limit
        await statusCache.remove(repoPath)
        await diffCache.clear()
        await fileDiffCache.clear()
        await tagCache.remove(repoPath)
        await stashCache.remove(repoPath)
        await remoteStatusCache.remove(repoPath)
    }

    /// Get overall cache statistics
    func getAllStats() async -> [String: CacheStats] {
        return [
            "branches": await branchCache.stats(),
            "commits": await commitCache.stats(),
            "status": await statusCache.stats(),
            "diff": await diffCache.stats(),
            "fileDiff": await fileDiffCache.stats(),
            "tags": await tagCache.stats(),
            "stashes": await stashCache.stats(),
            "remoteStatus": await remoteStatusCache.stats()
        ]
    }
}

// MARK: - Memoization Helper

/// Memoization wrapper for expensive computations
final class Memoize<Input: Hashable, Output> {
    private var cache: [Input: Output] = [:]
    private let computation: (Input) -> Output
    private let maxSize: Int
    private var accessOrder: [Input] = []

    init(maxSize: Int = 100, _ computation: @escaping (Input) -> Output) {
        self.maxSize = maxSize
        self.computation = computation
    }

    func callAsFunction(_ input: Input) -> Output {
        if let cached = cache[input] {
            // Move to end of access order (LRU)
            if let index = accessOrder.firstIndex(of: input) {
                accessOrder.remove(at: index)
                accessOrder.append(input)
            }
            return cached
        }

        let result = computation(input)

        // Evict oldest if at capacity
        if cache.count >= maxSize, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }

        cache[input] = result
        accessOrder.append(input)

        return result
    }

    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}

// MARK: - Shared Cache Instance

extension DependencyContainer {
    static let repositoryCache = RepositoryCache()
}
