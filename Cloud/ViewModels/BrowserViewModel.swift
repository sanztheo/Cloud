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
    private var currentUserAgentIndex = 0

    // MARK: - Anti-Detection Configuration
    private static let userAgents = [
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0"
    ]

    // Legacy support - keep for backward compatibility
    static let chromeUserAgent = userAgents[0]

    // Anti-detection JavaScript that will be injected into every page
    private static let stealthScript = """
    (function() {
        // Mask navigator.webdriver property
        Object.defineProperty(navigator, 'webdriver', {
            get: () => undefined,
            configurable: true
        });

        // Add realistic plugins
        Object.defineProperty(navigator, 'plugins', {
            get: () => {
                return Object.create(PluginArray.prototype, {
                    length: { value: 3 },
                    0: {
                        value: Object.create(Plugin.prototype, {
                            name: { value: 'Chrome PDF Plugin' },
                            description: { value: 'Portable Document Format' },
                            filename: { value: 'internal-pdf-viewer' },
                            length: { value: 1 },
                            0: {
                                value: Object.create(MimeType.prototype, {
                                    type: { value: 'application/pdf' },
                                    suffixes: { value: 'pdf' },
                                    description: { value: 'Portable Document Format' },
                                    enabledPlugin: { get: function() { return this; } }
                                })
                            }
                        })
                    },
                    1: {
                        value: Object.create(Plugin.prototype, {
                            name: { value: 'Chrome PDF Viewer' },
                            description: { value: 'Portable Document Format' },
                            filename: { value: 'mhjfbmdgcfjbbpaeojofohoefgiehjai' },
                            length: { value: 1 },
                            0: {
                                value: Object.create(MimeType.prototype, {
                                    type: { value: 'application/pdf' },
                                    suffixes: { value: 'pdf' },
                                    description: { value: 'Portable Document Format' },
                                    enabledPlugin: { get: function() { return this; } }
                                })
                            }
                        })
                    },
                    2: {
                        value: Object.create(Plugin.prototype, {
                            name: { value: 'Native Client' },
                            description: { value: 'Native Client Executable' },
                            filename: { value: 'internal-nacl-plugin' },
                            length: { value: 2 },
                            0: {
                                value: Object.create(MimeType.prototype, {
                                    type: { value: 'application/x-nacl' },
                                    suffixes: { value: '' },
                                    description: { value: 'Native Client Executable' },
                                    enabledPlugin: { get: function() { return this; } }
                                })
                            },
                            1: {
                                value: Object.create(MimeType.prototype, {
                                    type: { value: 'application/x-pnacl' },
                                    suffixes: { value: '' },
                                    description: { value: 'Portable Native Client Executable' },
                                    enabledPlugin: { get: function() { return this; } }
                                })
                            }
                        })
                    }
                });
            },
            configurable: true
        });

        // Set proper languages
        Object.defineProperty(navigator, 'languages', {
            get: () => ['en-US', 'en', 'fr'],
            configurable: true
        });

        // Add chrome object
        if (!window.chrome) {
            window.chrome = {
                runtime: {},
                loadTimes: function() {
                    return {
                        requestTime: Date.now() / 1000,
                        startLoadTime: Date.now() / 1000,
                        commitLoadTime: Date.now() / 1000,
                        finishDocumentLoadTime: Date.now() / 1000,
                        finishLoadTime: Date.now() / 1000,
                        firstPaintTime: Date.now() / 1000,
                        firstPaintAfterLoadTime: Date.now() / 1000,
                        navigationType: 'Other',
                        wasFetchedViaSpdy: false,
                        wasNpnNegotiated: true,
                        npnNegotiatedProtocol: 'h2',
                        wasAlternateProtocolAvailable: false,
                        connectionInfo: 'h2'
                    };
                },
                csi: function() {
                    return {
                        onloadT: Date.now(),
                        startE: Date.now() - 100,
                        pageT: Date.now() - Date.now()
                    };
                },
                app: {
                    isInstalled: false
                }
            };
        }

        // Mask permissions
        const originalQuery = navigator.permissions ? navigator.permissions.query : undefined;
        if (originalQuery) {
            navigator.permissions.query = function(parameters) {
                if (parameters.name === 'notifications') {
                    return Promise.resolve({ state: Notification.permission });
                }
                return originalQuery.apply(this, arguments);
            };
        }

        // Add realistic hardware concurrency
        Object.defineProperty(navigator, 'hardwareConcurrency', {
            get: () => 8,
            configurable: true
        });

        // Add device memory
        Object.defineProperty(navigator, 'deviceMemory', {
            get: () => 8,
            configurable: true
        });

        // Mask automation controlled flag
        Object.defineProperty(navigator, 'webdriver', {
            get: () => false,
            configurable: true
        });

        // Override toString methods to appear native
        const originalToString = Object.prototype.toString;
        Object.prototype.toString = function() {
            if (this === navigator) return '[object Navigator]';
            if (this === window.chrome) return '[object Object]';
            return originalToString.call(this);
        };

        // Add realistic connection info
        if (navigator.connection) {
            Object.defineProperty(navigator.connection, 'rtt', {
                get: () => 50,
                configurable: true
            });
            Object.defineProperty(navigator.connection, 'downlink', {
                get: () => 10,
                configurable: true
            });
            Object.defineProperty(navigator.connection, 'effectiveType', {
                get: () => '4g',
                configurable: true
            });
        }

        // Fix Intl.DateTimeFormat timezone
        const originalDateTimeFormat = Intl.DateTimeFormat;
        Intl.DateTimeFormat = function(...args) {
            if (args[1] && args[1].timeZone === undefined) {
                args[1].timeZone = 'America/New_York';
            }
            return new originalDateTimeFormat(...args);
        };

        // Console warning protection
        const originalWarn = console.warn;
        console.warn = function(...args) {
            const msg = args[0];
            if (typeof msg === 'string' && msg.includes('non-standards-compliant')) {
                return;
            }
            return originalWarn.apply(console, args);
        };
    })();
    """

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

    /// Gets a random user agent from the pool for rotation
    private func getRandomUserAgent() -> String {
        // Rotate through user agents sequentially to maintain consistency per session
        // but vary across different sessions
        currentUserAgentIndex = (currentUserAgentIndex + 1) % Self.userAgents.count
        return Self.userAgents[currentUserAgentIndex]
    }

    /// Gets a specific user agent by index for consistency within a tab session
    private func getUserAgent(for tabId: UUID) -> String {
        // Use tab ID hash to consistently assign same UA to same tab
        let hash = tabId.hashValue
        let index = abs(hash) % Self.userAgents.count
        return Self.userAgents[index]
    }

    /// Creates an enhanced WKWebViewConfiguration with anti-detection settings
    private func createStealthConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let preferences = WKPreferences()

        // Enable JavaScript
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences

        // Allow inline media playback
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Suppress incremental rendering to appear more human-like
        configuration.suppressesIncrementalRendering = false

        // Set website data store with cookies enabled
        let dataStore = WKWebsiteDataStore.default()
        configuration.websiteDataStore = dataStore

        // Allow air play
        configuration.allowsAirPlayForMediaPlayback = true

        return configuration
    }

    /// Injects stealth JavaScript into the webView
    private func injectStealthScript(into webView: WKWebView) {
        let userScript = WKUserScript(
            source: Self.stealthScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.addUserScript(userScript)
    }

    func createWebView(for tab: BrowserTab) -> WKWebView {
        // Create enhanced configuration with anti-detection settings
        let configuration = createStealthConfiguration()

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 100, height: 100), configuration: configuration)

        // Set tab-specific user agent for consistency within the tab
        webView.customUserAgent = getUserAgent(for: tab.id)

        // Enable gestures
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        // Inject stealth script
        injectStealthScript(into: webView)

        // Ensure webview fills its container
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]

        // Additional configuration for enhanced stealth
        webView.allowsLinkPreview = true

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

        // Create request with enhanced headers for anti-detection
        var request = URLRequest(url: url)

        // Add comprehensive HTTP headers to appear like a real browser
        request.setValue("en-US,en;q=0.9,fr;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")

        // Set referrer based on the URL domain
        if url.host == "google.com" || url.host?.contains("google") == true {
            request.setValue("https://www.google.com/", forHTTPHeaderField: "Referer")
        } else {
            // Use Google as referrer for most sites to appear natural
            request.setValue("https://www.google.com/", forHTTPHeaderField: "Referer")
        }

        // Additional headers for enhanced stealth
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("none", forHTTPHeaderField: "Sec-CH-UA-Mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "Sec-CH-UA-Platform")

        // Set Chrome client hints
        request.setValue("\"Chromium\";v=\"131\", \"Not_A Brand\";v=\"24\"", forHTTPHeaderField: "Sec-CH-UA")

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
            // Switch to existing tab instead of creating new one
            if let tabId = result.tabId {
                selectTab(tabId)
            }
        case .bookmark, .history, .suggestion:
            // Create NEW tab for bookmarks, history, and suggestions (Arc-style behavior)
            if let url = result.url {
                createNewTab(url: url)
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
