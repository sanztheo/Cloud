//
//  BrowserViewModel.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import Foundation
import SwiftUI
import WebKit
import Combine

class BrowserViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var spaces: [Space] = []
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabId: UUID?
    @Published var activeSpaceId: UUID?
    @Published var bookmarks: [Bookmark] = []
    @Published var history: [HistoryEntry] = []
    @Published var isSpotlightVisible: Bool = false
    @Published var isSidebarCollapsed: Bool = false
    @Published var searchQuery: String = ""
    @Published var addressBarText: String = ""
    @Published var spotlightSelectedIndex: Int = 0

    // MARK: - WebView Management
    private var webViews: [UUID: WKWebView] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Chrome User Agent
    static let chromeUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    // MARK: - Initialization
    init() {
        setupInitialData()
        loadPersistedData()
    }

    private func setupInitialData() {
        // Create default space
        let personalSpace = Space(name: "Personal", icon: "person.fill", color: .blue)
        spaces = [personalSpace]
        activeSpaceId = personalSpace.id

        // Create initial tab
        let initialTab = BrowserTab(
            url: URL(string: "https://www.google.com")!,
            title: "Google",
            spaceId: personalSpace.id
        )
        tabs = [initialTab]
        activeTabId = initialTab.id

        // Create WebView for initial tab
        _ = createWebView(for: initialTab)
    }

    // MARK: - WebView Management
    func createWebView(for tab: BrowserTab) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 100, height: 100), configuration: configuration)
        webView.customUserAgent = Self.chromeUserAgent
        webView.allowsBackForwardNavigationGestures = true

        // Ensure webview fills its container
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]

        webViews[tab.id] = webView
        loadURL(tab.url, for: tab.id)

        return webView
    }

    func getWebView(for tabId: UUID) -> WKWebView? {
        if let webView = webViews[tabId] {
            return webView
        }

        if let tab = tabs.first(where: { $0.id == tabId }) {
            return createWebView(for: tab)
        }

        return nil
    }

    // MARK: - Tab Management
    func createNewTab(url: URL? = nil, inSpace spaceId: UUID? = nil) {
        let targetSpaceId = spaceId ?? activeSpaceId ?? spaces.first!.id
        let targetUrl = url ?? URL(string: "https://www.google.com")!

        let newTab = BrowserTab(
            url: targetUrl,
            title: "New Tab",
            spaceId: targetSpaceId
        )

        tabs.append(newTab)
        activeTabId = newTab.id
        _ = createWebView(for: newTab)
    }

    func closeTab(_ tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }

        // Remove WebView
        webViews.removeValue(forKey: tabId)
        tabs.remove(at: index)

        // Update active tab
        if activeTabId == tabId {
            if tabs.isEmpty {
                createNewTab()
            } else {
                let newIndex = min(index, tabs.count - 1)
                activeTabId = tabs[newIndex].id
            }
        }
    }

    func selectTab(_ tabId: UUID) {
        activeTabId = tabId
        if let tab = tabs.first(where: { $0.id == tabId }) {
            addressBarText = tab.url.absoluteString
        }
    }

    func pinTab(_ tabId: UUID) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].isPinned.toggle()
        }
    }

    func moveTab(_ tabId: UUID, toSpace spaceId: UUID) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].spaceId = spaceId
        }
    }

    // MARK: - Navigation
    func loadURL(_ url: URL, for tabId: UUID) {
        guard let webView = webViews[tabId] else { return }
        let request = URLRequest(url: url)
        webView.load(request)

        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].url = url
            tabs[index].isLoading = true
        }
    }

    func navigateToAddress(_ address: String) {
        guard let tabId = activeTabId else { return }

        var urlString = address
        if !address.contains("://") {
            if address.contains(".") && !address.contains(" ") {
                urlString = "https://\(address)"
            } else {
                urlString = "https://www.google.com/search?q=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address)"
            }
        }

        if let url = URL(string: urlString) {
            loadURL(url, for: tabId)
            addToHistory(url: url, title: address)
        }
    }

    func goBack() {
        guard let tabId = activeTabId,
              let webView = webViews[tabId],
              webView.canGoBack else { return }
        webView.goBack()
    }

    func goForward() {
        guard let tabId = activeTabId,
              let webView = webViews[tabId],
              webView.canGoForward else { return }
        webView.goForward()
    }

    func reload() {
        guard let tabId = activeTabId,
              let webView = webViews[tabId] else { return }
        webView.reload()
    }

    func stopLoading() {
        guard let tabId = activeTabId,
              let webView = webViews[tabId] else { return }
        webView.stopLoading()
    }

    // MARK: - Tab State Updates
    func updateTabState(tabId: UUID, title: String? = nil, url: URL? = nil, isLoading: Bool? = nil, canGoBack: Bool? = nil, canGoForward: Bool? = nil) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }

        if let title = title {
            tabs[index].title = title
        }
        if let url = url {
            tabs[index].url = url
            if tabId == activeTabId {
                addressBarText = url.absoluteString
            }
        }
        if let isLoading = isLoading {
            tabs[index].isLoading = isLoading
        }
        if let canGoBack = canGoBack {
            tabs[index].canGoBack = canGoBack
        }
        if let canGoForward = canGoForward {
            tabs[index].canGoForward = canGoForward
        }
    }

    // MARK: - Space Management
    func createNewSpace(name: String, icon: String, color: Color) {
        let newSpace = Space(name: name, icon: icon, color: color)
        spaces.append(newSpace)
    }

    func selectSpace(_ spaceId: UUID) {
        activeSpaceId = spaceId

        // Select first tab in space or create new one
        if let firstTab = tabs.first(where: { $0.spaceId == spaceId }) {
            activeTabId = firstTab.id
        } else {
            createNewTab(inSpace: spaceId)
        }
    }

    func deleteSpace(_ spaceId: UUID) {
        guard spaces.count > 1 else { return }

        // Move tabs to first space
        let firstSpaceId = spaces.first(where: { $0.id != spaceId })!.id
        for i in tabs.indices where tabs[i].spaceId == spaceId {
            tabs[i].spaceId = firstSpaceId
        }

        spaces.removeAll { $0.id == spaceId }

        if activeSpaceId == spaceId {
            activeSpaceId = firstSpaceId
        }
    }

    // MARK: - Bookmarks
    func addBookmark(url: URL, title: String) {
        let bookmark = Bookmark(url: url, title: title)
        bookmarks.append(bookmark)
        saveBookmarks()
    }

    func removeBookmark(_ bookmarkId: UUID) {
        bookmarks.removeAll { $0.id == bookmarkId }
        saveBookmarks()
    }

    func isBookmarked(url: URL) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    // MARK: - History
    func addToHistory(url: URL, title: String) {
        let entry = HistoryEntry(url: url, title: title)
        history.insert(entry, at: 0)

        // Keep only last 1000 entries
        if history.count > 1000 {
            history = Array(history.prefix(1000))
        }

        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    // MARK: - Search/Spotlight
    func toggleSpotlight() {
        isSpotlightVisible.toggle()
        if isSpotlightVisible {
            searchQuery = ""
        }
    }

    func searchResults(for query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []
        let lowercasedQuery = query.lowercased()

        // Search tabs
        for tab in tabs where tab.title.lowercased().contains(lowercasedQuery) || tab.url.absoluteString.lowercased().contains(lowercasedQuery) {
            results.append(SearchResult(
                type: .tab,
                title: tab.title,
                subtitle: tab.url.host ?? tab.url.absoluteString,
                url: tab.url,
                tabId: tab.id
            ))
        }

        // Search bookmarks
        for bookmark in bookmarks where bookmark.title.lowercased().contains(lowercasedQuery) || bookmark.url.absoluteString.lowercased().contains(lowercasedQuery) {
            results.append(SearchResult(
                type: .bookmark,
                title: bookmark.title,
                subtitle: bookmark.url.host ?? bookmark.url.absoluteString,
                url: bookmark.url
            ))
        }

        // Search history
        for entry in history.prefix(20) where entry.title.lowercased().contains(lowercasedQuery) || entry.url.absoluteString.lowercased().contains(lowercasedQuery) {
            results.append(SearchResult(
                type: .history,
                title: entry.title,
                subtitle: entry.url.host ?? entry.url.absoluteString,
                url: entry.url
            ))
        }

        // Add search suggestion
        results.append(SearchResult(
            type: .suggestion,
            title: "Search Google for \"\(query)\"",
            subtitle: "google.com",
            url: URL(string: "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
        ))

        return results
    }

    func selectSearchResult(_ result: SearchResult) {
        isSpotlightVisible = false

        switch result.type {
        case .tab:
            if let tabId = result.tabId {
                selectTab(tabId)
            }
        case .bookmark, .history, .suggestion:
            if let url = result.url {
                if let tabId = activeTabId {
                    loadURL(url, for: tabId)
                } else {
                    createNewTab(url: url)
                }
            }
        }
    }

    // MARK: - Sidebar
    func toggleSidebar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSidebarCollapsed.toggle()
        }
    }

    // MARK: - Computed Properties
    var activeTab: BrowserTab? {
        tabs.first { $0.id == activeTabId }
    }

    var activeSpace: Space? {
        spaces.first { $0.id == activeSpaceId }
    }

    func tabsForSpace(_ spaceId: UUID) -> [BrowserTab] {
        tabs.filter { $0.spaceId == spaceId }
    }

    func pinnedTabsForSpace(_ spaceId: UUID) -> [BrowserTab] {
        tabs.filter { $0.spaceId == spaceId && $0.isPinned }
    }

    func unpinnedTabsForSpace(_ spaceId: UUID) -> [BrowserTab] {
        tabs.filter { $0.spaceId == spaceId && !$0.isPinned }
    }

    // MARK: - Persistence
    private func loadPersistedData() {
        loadBookmarks()
        loadHistory()
    }

    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: "cloud_bookmarks")
        }
    }

    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: "cloud_bookmarks"),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            bookmarks = decoded
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "cloud_history")
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "cloud_history"),
           let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            history = decoded
        }
    }
}
