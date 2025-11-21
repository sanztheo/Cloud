//
//  BrowserViewModel.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import Combine
import Foundation
import SwiftUI
import WebKit

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

  // MARK: - Search Suggestions
  private let suggestionsService = GoogleSuggestionsService()
  @Published var suggestions: [SearchResult] = []

  // MARK: - Optimized Configuration (2025 Best Practices)
  // User-Agent STABLE - pas de rotation (red flag pour les systèmes anti-bot)
  private static let stableUserAgent = OptimizedWebKitConfig.stableUserAgent

  // IMPORTANT: Pas de JavaScript "stealth" agressif
  // Les modifications de navigator.* sont détectées par les systèmes anti-bot modernes
  // WKWebView rapporte naturellement les bonnes propriétés (cohérentes avec macOS)
  // Pour plus d'infos: voir OptimizedWebKitConfig.swift documentation

  // PAS de JavaScript d'injection - WKWebView rapporte naturellement les bonnes propriétés
  // L'injection agressive est DÉTECTÉE par les systèmes anti-bot modernes (OpenAI, Claude, etc.)

  // MARK: - Initialization
  init() {
    setupInitialData()
    loadPersistedData()
    setupSearchSubscriptions()
  }

  private func setupSearchSubscriptions() {
    $searchQuery
      .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
      .removeDuplicates()
      .flatMap { [weak self] query -> AnyPublisher<[String], Never> in
        guard let self = self, !query.isEmpty else {
          return Just([]).eraseToAnyPublisher()
        }
        return self.suggestionsService.fetchSuggestions(for: query)
      }
      .receive(on: RunLoop.main)
      .sink { [weak self] suggestions in
        guard let self = self else { return }

        self.suggestions = suggestions.map { suggestion in
          SearchResult(
            type: .suggestion,
            title: suggestion,
            subtitle: "Google Search",
            url: URL(
              string:
                "https://www.google.com/search?q=\(suggestion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? suggestion)"
            )
          )
        }
      }
      .store(in: &cancellables)
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
    // ✓ Utiliser la configuration optimisée (cohérence > stealth)
    let configuration = OptimizedWebKitConfig.createConfiguration()

    let webView = WKWebView(
      frame: NSRect(x: 0, y: 0, width: 100, height: 100), configuration: configuration)

    // ✓ Setup avec User-Agent STABLE et configuration optimale
    OptimizedWebKitConfig.setupWebView(webView)

    // ✓ Pas d'injection JavaScript agressive (détectée par OpenAI/Claude)

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

    // Load favicon for the new tab
    loadFavicon(for: newTab.id, url: targetUrl)
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

    // ✓ En-têtes minimaux et cohérents (pas de faux headers suspects)
    var request = URLRequest(url: url)
    OptimizedWebKitConfig.configureRequest(&request)

    // Debug log pour les sites avec protection forte
    if OptimizedWebKitConfig.hasStrongBotProtection(url: url) {
      OptimizedWebKitConfig.logDiagnostic(for: webView, url: url)
    }

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
        urlString =
          "https://www.google.com/search?q=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address)"
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
      webView.canGoBack
    else { return }
    webView.goBack()
  }

  func goForward() {
    guard let tabId = activeTabId,
      let webView = webViews[tabId],
      webView.canGoForward
    else { return }
    webView.goForward()
  }

  func reload() {
    guard let tabId = activeTabId,
      let webView = webViews[tabId]
    else { return }
    webView.reload()
  }

  func stopLoading() {
    guard let tabId = activeTabId,
      let webView = webViews[tabId]
    else { return }
    webView.stopLoading()
  }

  // MARK: - Tab State Updates
  func updateTabState(
    tabId: UUID, title: String? = nil, url: URL? = nil, isLoading: Bool? = nil,
    canGoBack: Bool? = nil, canGoForward: Bool? = nil
  ) {
    guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }

    if let title = title {
      tabs[index].title = title
    }
    if let url = url {
      tabs[index].url = url
      if tabId == activeTabId {
        addressBarText = url.absoluteString
      }
      // Load favicon when URL changes
      loadFavicon(for: tabId, url: url)
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

  // MARK: - Favicon Loading
  private func loadFavicon(for tabId: UUID, url: URL) {
    guard let host = url.host else { return }

    // Use Google's favicon service
    let faviconURLString = "https://www.google.com/s2/favicons?domain=\(host)&sz=64"
    guard let faviconURL = URL(string: faviconURLString) else { return }

    URLSession.shared.dataTask(with: faviconURL) { [weak self] data, _, _ in
      guard let self = self,
        let data = data,
        let image = NSImage(data: data),
        let index = self.tabs.firstIndex(where: { $0.id == tabId })
      else { return }

      DispatchQueue.main.async {
        self.tabs[index].favicon = image
      }
    }.resume()
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
    if query.isEmpty {
      return tabs.map { tab in
        SearchResult(
          type: .tab,
          title: tab.title,
          subtitle: tab.url.host ?? tab.url.absoluteString,
          url: tab.url,
          tabId: tab.id,
          favicon: tab.favicon
        )
      }
    }

    var results: [SearchResult] = []
    let lowercasedQuery = query.lowercased()

    // 1. Check if query looks like a URL (contains dot and no spaces)
    if query.contains(".") && !query.contains(" ") {
      let urlString = query.hasPrefix("http") ? query : "https://\(query)"
      if let url = URL(string: urlString) {
        results.append(
          SearchResult(
            type: .website,
            title: query,
            subtitle: "Open website",
            url: url
          ))
      }
    }

    // 2. Add search suggestions (Google suggestions)
    if !suggestions.isEmpty {
      results.append(contentsOf: suggestions)
    } else {
      // Fallback to generic search if no suggestions yet
      results.append(
        SearchResult(
          type: .suggestion,
          title: "Search Google for \"\(query)\"",
          subtitle: "google.com",
          url: URL(
            string:
              "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
          )
        ))
    }

    // 3. Search history
    for entry in history.prefix(20)
    where entry.title.lowercased().contains(lowercasedQuery)
      || entry.url.absoluteString.lowercased().contains(lowercasedQuery)
    {
      results.append(
        SearchResult(
          type: .history,
          title: entry.title,
          subtitle: entry.url.host ?? entry.url.absoluteString,
          url: entry.url
        ))
    }

    // 4. Search tabs
    for tab in tabs
    where tab.title.lowercased().contains(lowercasedQuery)
      || tab.url.absoluteString.lowercased().contains(lowercasedQuery)
    {
      results.append(
        SearchResult(
          type: .tab,
          title: tab.title,
          subtitle: tab.url.host ?? tab.url.absoluteString,
          url: tab.url,
          tabId: tab.id,
          favicon: tab.favicon
        ))
    }

    // 5. Search bookmarks
    for bookmark in bookmarks
    where bookmark.title.lowercased().contains(lowercasedQuery)
      || bookmark.url.absoluteString.lowercased().contains(lowercasedQuery)
    {
      results.append(
        SearchResult(
          type: .bookmark,
          title: bookmark.title,
          subtitle: bookmark.url.host ?? bookmark.url.absoluteString,
          url: bookmark.url
        ))
    }

    return results
  }

  func selectSearchResult(_ result: SearchResult) {
    isSpotlightVisible = false

    print("🔍 Spotlight: selectSearchResult called with type: \(result.type), title: \(result.title)")

    switch result.type {
    case .tab:
      // Switch to existing tab instead of creating new one
      if let tabId = result.tabId {
        print("  → Switching to existing tab")
        selectTab(tabId)
      }
    case .bookmark, .history, .suggestion, .website:
      // Create NEW tab for bookmarks, history, suggestions, and websites (Arc-style behavior)
      if let url = result.url {
        print("  → Creating new tab for URL: \(url)")
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
      let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
    {
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
      let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
    {
      history = decoded
    }
  }
}
