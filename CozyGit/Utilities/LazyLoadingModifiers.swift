//
//  LazyLoadingModifiers.swift
//  CozyGit
//
//  Phase 19: Performance Optimization - Lazy Loading Utilities

import SwiftUI

// MARK: - Lazy Loading View Modifier

/// View modifier that triggers loading when view appears near bottom
struct LazyLoadingModifier: ViewModifier {
    let isLoading: Bool
    let hasMore: Bool
    let threshold: CGFloat
    let onLoadMore: () async -> Void

    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                        .preference(key: ContentHeightPreferenceKey.self, value: geometry.size.height)
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                scrollOffset = offset
                checkLoadMore()
            }
            .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                contentHeight = height
            }
    }

    private func checkLoadMore() {
        guard !isLoading && hasMore else { return }

        // Check if scrolled near bottom
        if scrollOffset < threshold {
            Task {
                await onLoadMore()
            }
        }
    }
}

// MARK: - Preference Keys

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Extension

extension View {
    /// Add lazy loading behavior to a scrollable view
    func lazyLoading(
        isLoading: Bool,
        hasMore: Bool,
        threshold: CGFloat = 100,
        onLoadMore: @escaping () async -> Void
    ) -> some View {
        modifier(LazyLoadingModifier(
            isLoading: isLoading,
            hasMore: hasMore,
            threshold: threshold,
            onLoadMore: onLoadMore
        ))
    }
}

// MARK: - Paginated List View

/// A list view with built-in pagination support
struct PaginatedList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let isLoading: Bool
    let hasMore: Bool
    let onLoadMore: () async -> Void
    let content: (Item) -> Content

    @State private var loadingTaskID: UUID?

    init(
        items: [Item],
        isLoading: Bool,
        hasMore: Bool,
        onLoadMore: @escaping () async -> Void,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.isLoading = isLoading
        self.hasMore = hasMore
        self.onLoadMore = onLoadMore
        self.content = content
    }

    var body: some View {
        List {
            ForEach(items) { item in
                content(item)
                    .onAppear {
                        // Check if this is near the end
                        if shouldLoadMore(for: item) {
                            triggerLoadMore()
                        }
                    }
            }

            // Loading indicator at bottom
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            // Load more button if has more
            if hasMore && !isLoading {
                Button {
                    triggerLoadMore()
                } label: {
                    HStack {
                        Spacer()
                        Text("Load More")
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
            }
        }
    }

    private func shouldLoadMore(for item: Item) -> Bool {
        guard hasMore && !isLoading else { return false }

        // Check if item is in last 5 items
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            return index >= items.count - 5
        }
        return false
    }

    private func triggerLoadMore() {
        guard !isLoading && hasMore else { return }

        Task {
            await onLoadMore()
        }
    }
}

// MARK: - Lazy VStack with Pagination

/// A lazy VStack with built-in pagination
struct PaginatedLazyVStack<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let isLoading: Bool
    let hasMore: Bool
    let spacing: CGFloat
    let onLoadMore: () async -> Void
    let content: (Item) -> Content

    init(
        items: [Item],
        isLoading: Bool,
        hasMore: Bool,
        spacing: CGFloat = 0,
        onLoadMore: @escaping () async -> Void,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.isLoading = isLoading
        self.hasMore = hasMore
        self.spacing = spacing
        self.onLoadMore = onLoadMore
        self.content = content
    }

    var body: some View {
        LazyVStack(spacing: spacing) {
            ForEach(items) { item in
                content(item)
                    .onAppear {
                        if shouldLoadMore(for: item) {
                            Task {
                                await onLoadMore()
                            }
                        }
                    }
            }

            if isLoading {
                ProgressView()
                    .padding()
            }
        }
    }

    private func shouldLoadMore(for item: Item) -> Bool {
        guard hasMore && !isLoading else { return false }

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            return index >= items.count - 5
        }
        return false
    }
}

// MARK: - Virtual List

/// A virtual list that only renders visible items
struct VirtualList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let rowHeight: CGFloat
    let content: (Item) -> Content

    @State private var visibleRange: Range<Int> = 0..<0
    @State private var containerHeight: CGFloat = 0

    private let overscan: Int = 5

    init(
        items: [Item],
        rowHeight: CGFloat,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.rowHeight = rowHeight
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Top spacer
                    Color.clear
                        .frame(height: CGFloat(visibleRange.lowerBound) * rowHeight)

                    // Visible items
                    ForEach(visibleItems) { item in
                        content(item)
                            .frame(height: rowHeight)
                    }

                    // Bottom spacer
                    Color.clear
                        .frame(height: CGFloat(max(0, items.count - visibleRange.upperBound)) * rowHeight)
                }
                .background(
                    GeometryReader { scrollGeometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: scrollGeometry.frame(in: .named("virtualScroll")).minY
                            )
                    }
                )
            }
            .coordinateSpace(name: "virtualScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                updateVisibleRange(scrollOffset: -offset, containerHeight: geometry.size.height)
            }
            .onAppear {
                containerHeight = geometry.size.height
                updateVisibleRange(scrollOffset: 0, containerHeight: geometry.size.height)
            }
        }
    }

    private var visibleItems: [Item] {
        guard !items.isEmpty else { return [] }
        let safeRange = max(0, visibleRange.lowerBound)..<min(items.count, visibleRange.upperBound)
        return Array(items[safeRange])
    }

    private func updateVisibleRange(scrollOffset: CGFloat, containerHeight: CGFloat) {
        let firstVisible = max(0, Int(scrollOffset / rowHeight) - overscan)
        let visibleCount = Int(ceil(containerHeight / rowHeight)) + (overscan * 2)
        let lastVisible = min(items.count, firstVisible + visibleCount)

        visibleRange = firstVisible..<lastVisible
    }
}

// MARK: - Deferred View

/// A view that defers loading its content until visible
struct DeferredView<Content: View>: View {
    let content: () -> Content

    @State private var hasAppeared = false

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if hasAppeared {
                content()
            } else {
                Color.clear
                    .onAppear {
                        hasAppeared = true
                    }
            }
        }
    }
}

// MARK: - Throttled Search

/// A search field that throttles input
struct ThrottledSearchField: View {
    @Binding var text: String
    let placeholder: String
    let delay: TimeInterval
    let onSearch: (String) -> Void

    @State private var localText: String = ""
    @State private var searchTask: Task<Void, Never>?

    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        delay: TimeInterval = 0.3,
        onSearch: @escaping (String) -> Void
    ) {
        self._text = text
        self.placeholder = placeholder
        self.delay = delay
        self.onSearch = onSearch
        self._localText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(placeholder, text: $localText)
                .textFieldStyle(.plain)
                .onChange(of: localText) { _, newValue in
                    throttleSearch(newValue)
                }

            if !localText.isEmpty {
                Button {
                    localText = ""
                    text = ""
                    onSearch("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func throttleSearch(_ query: String) {
        searchTask?.cancel()

        searchTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            if !Task.isCancelled {
                await MainActor.run {
                    text = query
                    onSearch(query)
                }
            }
        }
    }
}
