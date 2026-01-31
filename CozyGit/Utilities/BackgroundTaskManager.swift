//
//  BackgroundTaskManager.swift
//  CozyGit
//
//  Phase 19: Performance Optimization - Background Operations

import Foundation
import Combine

// MARK: - Task Priority

/// Priority for background tasks
enum TaskPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Background Task

/// A background task wrapper
struct BackgroundTask: Identifiable {
    let id: UUID
    let name: String
    let priority: TaskPriority
    let work: @Sendable () async throws -> Void
    let createdAt: Date

    init(
        name: String,
        priority: TaskPriority = .normal,
        work: @escaping @Sendable () async throws -> Void
    ) {
        self.id = UUID()
        self.name = name
        self.priority = priority
        self.work = work
        self.createdAt = Date()
    }
}

// MARK: - Background Task Manager

/// Manages background task execution with queuing and throttling
@MainActor
final class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()

    // MARK: - Published State

    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var queuedTaskCount: Int = 0
    @Published private(set) var currentTaskName: String?

    // MARK: - Private State

    private var taskQueue: [BackgroundTask] = []
    private var runningTasks: Set<UUID> = []
    private let maxConcurrentTasks: Int
    private var processingTask: Task<Void, Never>?

    // Throttling
    private var throttleTimers: [String: Date] = [:]

    // Debouncing
    private var debounceTasks: [String: Task<Void, Never>] = [:]

    init(maxConcurrentTasks: Int = 3) {
        self.maxConcurrentTasks = maxConcurrentTasks
    }

    // MARK: - Task Submission

    /// Submit a task to the background queue
    func submit(_ task: BackgroundTask) {
        // Insert based on priority (higher priority first)
        let insertIndex = taskQueue.firstIndex { $0.priority < task.priority } ?? taskQueue.endIndex
        taskQueue.insert(task, at: insertIndex)
        queuedTaskCount = taskQueue.count

        processQueue()
    }

    /// Submit a simple async work block
    func submit(
        name: String,
        priority: TaskPriority = .normal,
        work: @escaping @Sendable () async throws -> Void
    ) {
        let task = BackgroundTask(name: name, priority: priority, work: work)
        submit(task)
    }

    // MARK: - Throttling

    /// Execute work only if the specified time has passed since last execution
    func throttle(
        key: String,
        interval: TimeInterval,
        work: @escaping @Sendable () async throws -> Void
    ) {
        let now = Date()

        if let lastExecution = throttleTimers[key],
           now.timeIntervalSince(lastExecution) < interval {
            // Too soon, skip
            return
        }

        throttleTimers[key] = now
        submit(name: "Throttled: \(key)", work: work)
    }

    /// Clear throttle timer for a key
    func clearThrottle(key: String) {
        throttleTimers.removeValue(forKey: key)
    }

    // MARK: - Debouncing

    /// Execute work after a delay, cancelling any pending execution
    func debounce(
        key: String,
        delay: TimeInterval,
        work: @escaping @Sendable () async throws -> Void
    ) {
        // Cancel existing debounce task
        debounceTasks[key]?.cancel()

        // Create new debounce task
        debounceTasks[key] = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            if !Task.isCancelled {
                await MainActor.run {
                    self.submit(name: "Debounced: \(key)", work: work)
                    self.debounceTasks.removeValue(forKey: key)
                }
            }
        }
    }

    /// Cancel a pending debounce
    func cancelDebounce(key: String) {
        debounceTasks[key]?.cancel()
        debounceTasks.removeValue(forKey: key)
    }

    // MARK: - Queue Management

    /// Cancel all queued tasks
    func cancelAll() {
        taskQueue.removeAll()
        queuedTaskCount = 0

        for (_, task) in debounceTasks {
            task.cancel()
        }
        debounceTasks.removeAll()
    }

    /// Cancel tasks matching a predicate
    func cancel(where predicate: (BackgroundTask) -> Bool) {
        taskQueue.removeAll(where: predicate)
        queuedTaskCount = taskQueue.count
    }

    // MARK: - Private Methods

    private func processQueue() {
        guard !isProcessing || runningTasks.count < maxConcurrentTasks else { return }

        while let task = taskQueue.first, runningTasks.count < maxConcurrentTasks {
            taskQueue.removeFirst()
            queuedTaskCount = taskQueue.count
            executeTask(task)
        }
    }

    private func executeTask(_ task: BackgroundTask) {
        runningTasks.insert(task.id)
        isProcessing = true
        currentTaskName = task.name

        Task {
            do {
                try await task.work()
            } catch {
                Logger.shared.error("Background task '\(task.name)' failed: \(error)", category: .app)
            }

            await MainActor.run {
                self.runningTasks.remove(task.id)

                if self.runningTasks.isEmpty {
                    self.isProcessing = false
                    self.currentTaskName = nil
                }

                self.processQueue()
            }
        }
    }
}

// MARK: - Coalescing Request Manager

/// Manages coalesced requests to prevent duplicate operations
actor CoalescingRequestManager {
    private var pendingRequests: [String: Task<Any, Error>] = [:]

    /// Execute a request, coalescing with any existing request for the same key
    func request<T>(
        key: String,
        work: @escaping () async throws -> T
    ) async throws -> T {
        // If there's already a pending request, wait for it
        if let existing = pendingRequests[key] {
            // swiftlint:disable:next force_cast
            return try await existing.value as! T
        }

        // Create new request
        let task = Task<Any, Error> {
            try await work()
        }

        pendingRequests[key] = task

        do {
            let result = try await task.value
            pendingRequests.removeValue(forKey: key)
            // swiftlint:disable:next force_cast
            return result as! T
        } catch {
            pendingRequests.removeValue(forKey: key)
            throw error
        }
    }

    /// Cancel a pending request
    func cancel(key: String) {
        pendingRequests[key]?.cancel()
        pendingRequests.removeValue(forKey: key)
    }

    /// Cancel all pending requests
    func cancelAll() {
        for (_, task) in pendingRequests {
            task.cancel()
        }
        pendingRequests.removeAll()
    }
}

// MARK: - Rate Limiter

/// Token bucket rate limiter
actor RateLimiter {
    private let maxTokens: Int
    private let refillRate: Double // tokens per second
    private var tokens: Double
    private var lastRefill: Date

    init(maxTokens: Int, refillRate: Double) {
        self.maxTokens = maxTokens
        self.refillRate = refillRate
        self.tokens = Double(maxTokens)
        self.lastRefill = Date()
    }

    /// Attempt to acquire a token
    func acquire() async -> Bool {
        refill()

        if tokens >= 1 {
            tokens -= 1
            return true
        }

        return false
    }

    /// Wait for a token to become available
    func acquireWait() async {
        while true {
            refill()

            if tokens >= 1 {
                tokens -= 1
                return
            }

            // Wait for refill
            let waitTime = (1 - tokens) / refillRate
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
    }

    private func refill() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefill)
        let refillAmount = elapsed * refillRate

        tokens = min(Double(maxTokens), tokens + refillAmount)
        lastRefill = now
    }
}

// MARK: - Batch Processor

/// Processes items in batches with configurable batch size and delay
actor BatchProcessor<Item> {
    private var items: [Item] = []
    private var batchTask: Task<Void, Never>?
    private let batchSize: Int
    private let maxDelay: TimeInterval
    private let processor: @Sendable ([Item]) async -> Void

    init(
        batchSize: Int = 10,
        maxDelay: TimeInterval = 0.5,
        processor: @escaping @Sendable ([Item]) async -> Void
    ) {
        self.batchSize = batchSize
        self.maxDelay = maxDelay
        self.processor = processor
    }

    /// Add an item to the batch
    func add(_ item: Item) {
        items.append(item)

        if items.count >= batchSize {
            processBatch()
        } else if batchTask == nil {
            // Start delay timer
            batchTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(maxDelay * 1_000_000_000))
                if !Task.isCancelled {
                    await self.processBatch()
                }
            }
        }
    }

    /// Add multiple items to the batch
    func add(_ newItems: [Item]) {
        items.append(contentsOf: newItems)

        if items.count >= batchSize {
            processBatch()
        } else if batchTask == nil {
            batchTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(maxDelay * 1_000_000_000))
                if !Task.isCancelled {
                    await self.processBatch()
                }
            }
        }
    }

    /// Force process current batch
    func flush() {
        processBatch()
    }

    private func processBatch() {
        batchTask?.cancel()
        batchTask = nil

        guard !items.isEmpty else { return }

        let batch = items
        items.removeAll()

        Task {
            await processor(batch)
        }
    }
}

// MARK: - Incremental Loader

/// Loads data incrementally with pagination support
@MainActor
final class IncrementalLoader<Item: Identifiable>: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var hasMore: Bool = true
    @Published private(set) var error: Error?

    private let pageSize: Int
    private let loader: (Int, Int) async throws -> [Item]
    private var currentOffset: Int = 0

    init(
        pageSize: Int = 50,
        loader: @escaping (Int, Int) async throws -> [Item]
    ) {
        self.pageSize = pageSize
        self.loader = loader
    }

    /// Load initial data
    func loadInitial() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        currentOffset = 0

        do {
            let newItems = try await loader(0, pageSize)
            items = newItems
            hasMore = newItems.count >= pageSize
            currentOffset = newItems.count
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Load next page
    func loadMore() async {
        guard !isLoading && hasMore else { return }

        isLoading = true
        error = nil

        do {
            let newItems = try await loader(currentOffset, pageSize)
            items.append(contentsOf: newItems)
            hasMore = newItems.count >= pageSize
            currentOffset += newItems.count
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Reset and reload
    func reset() async {
        items = []
        currentOffset = 0
        hasMore = true
        error = nil
        await loadInitial()
    }
}
