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
  @Published var folders: [TabFolder] = []
  @Published var editingFolderId: UUID?  // Folder to auto-edit after creation
  @Published var isSpotlightVisible: Bool = false
  @Published var isSidebarCollapsed: Bool = false
  @Published var isHistoryPanelVisible: Bool = false
  @Published var searchQuery: String = ""
  @Published var isAskMode: Bool = false  // Spotlight "Ask About WebPage" mode
  @Published var askQuestion: String = ""  // User-provided question for the active page
  @Published var addressBarText: String = ""
  @Published var spotlightSelectedIndex: Int = 0
  @Published var transitionDirection: Edge = .trailing
  @Published var spaceSwipeDragOffset: CGFloat = 0

  // Summary functionality
  @Published var isSummarizing: Bool = false
  @Published var summaryText: String = ""
  @Published var isSummaryComplete: Bool = false
  @Published var summarizingStatus: String = "Summarizing page..."
  @Published var summaryError: String? = nil

  // MARK: - Download Manager
  @Published var downloadManager = DownloadManager()
  @Published var unreadDownloadsCount: Int = 0

  // MARK: - WebView Management
  private var webViews: [UUID: WKWebView] = [:]
  private var cancellables = Set<AnyCancellable>()
  private var loadingObservations: [UUID: NSKeyValueObservation] = [:]

  // MARK: - Search Suggestions
  private let suggestionsService = GoogleSuggestionsService()
  @Published var suggestions: [SearchResult] = []

  // MARK: - Services
  private let openAIService = OpenAIService()
  private let cacheService = SummaryCacheService.shared

  // Task for summary generation (to support cancellation)
  private var summaryTask: Task<Void, Never>?
  private var isSummaryCancelled: Bool = false

  // MARK: - Stealth Configuration (2025 Best Practices)
  // Uses StealthWebKitConfig for optimal anti-detection settings
  // Key principles:
  // - Stable User-Agent matching actual macOS version
  // - Minimal HTTP headers (what Safari actually sends)
  // - NO JavaScript injection (90-100% detection rate)
  // - Default data store for cookie persistence
  // See StealthWebKitConfig.swift for full documentation

  // MARK: - Initialization
  init() {
    setupInitialData()
    loadPersistedData()
    setupSearchSubscriptions()
    setupDownloadNotifications()
  }

  private func setupDownloadNotifications() {
    // Listen for new downloads and increment unread count
    // Use dropFirst to skip the initial load from persistence
    downloadManager.$downloads
      .dropFirst()
      .scan(([], [])) {
        (previous: ([DownloadItem], [DownloadItem]), current: [DownloadItem]) -> (
          [DownloadItem], [DownloadItem]
        ) in
        return (previous.1, current)
      }
      .sink { [weak self] (previous, current) in
        guard let self = self else { return }
        // Check if new downloads were added
        let previousIds = Set(previous.map { $0.id })
        let newDownloads = current.filter { !previousIds.contains($0.id) }
        if !newDownloads.isEmpty {
          self.unreadDownloadsCount += newDownloads.count
        }
      }
      .store(in: &cancellables)
  }

  func clearUnreadDownloads() {
    unreadDownloadsCount = 0
  }

  private func setupSearchSubscriptions() {
    $searchQuery
      .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
      .removeDuplicates()
      .flatMap { [weak self] query -> AnyPublisher<[String], Never> in
        guard let self = self, !query.isEmpty, !self.isAskMode else {
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
    // Load spaces from UserDefaults if available
    loadSpaces()
    loadFolders()

    // If no spaces exist, create default space
    if spaces.isEmpty {
      let personalSpace = Space(name: "Personal", icon: "👤", color: .blue)
      spaces = [personalSpace]
      activeSpaceId = personalSpace.id
      saveSpaces()
    }

    // Load persisted tabs
    loadTabs()
    loadActiveIds()

    // Create WebViews for all restored tabs (allow 0 tabs)
    // KVO observers are set up in createWebView() to automatically sync isLoading state
    for tab in tabs {
      _ = createWebView(for: tab)
    }
  }

  // MARK: - WebView Management

  func createWebView(for tab: BrowserTab) -> WKWebView {
    // ✓ Use enhanced stealth configuration (2025 best practices)
    let configuration = StealthWebKitConfig.createConfiguration()

    // Use CustomWKWebView for download handling
    let webView = CustomWKWebView(
      frame: NSRect(x: 0, y: 0, width: 100, height: 100), configuration: configuration)

    // ✓ Apply stealth settings (stable User-Agent matching OS, natural behavior)
    StealthWebKitConfig.setupWebView(webView)

    webViews[tab.id] = webView

    // Observe isLoading via KVO to sync with tab model
    // This ensures isLoading is updated even without navigationDelegate
    let tabId = tab.id
    loadingObservations[tabId] = webView.observe(\.isLoading, options: [.new]) {
      [weak self] webView, change in
      guard let self = self else { return }
      DispatchQueue.main.async {
        if let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
          self.tabs[index].isLoading = webView.isLoading
        }
      }
    }

    loadURL(tab.url, for: tabId)

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

    // Persist tabs
    saveTabs()
  }

  func closeTab(_ tabId: UUID) {
    guard let tab = tabs.first(where: { $0.id == tabId }) else { return }
    let closedTabSpaceId = tab.spaceId

    // Protected tabs: pinned tabs and tabs in folders cannot be closed with Ctrl+W
    // They stay open - user just gets redirected to another tab or Welcome screen
    let isProtected = tab.isPinned || tab.folderId != nil

    if isProtected {
      // Don't delete the tab, just switch to another ungrouped tab or Welcome
      if activeTabId == tabId {
        let ungroupedTabsInSpace = tabs.filter {
          $0.spaceId == closedTabSpaceId && $0.folderId == nil && !$0.isPinned && $0.id != tabId
        }
        if let nextTab = ungroupedTabsInSpace.first {
          activeTabId = nextTab.id
        } else {
          activeTabId = nil
        }
      }
      return
    }

    // Remove WebView and KVO observation for non-protected tabs
    webViews.removeValue(forKey: tabId)
    loadingObservations.removeValue(forKey: tabId)
    tabs.removeAll { $0.id == tabId }

    // Update active tab - only select UNGROUPED, NON-PINNED tabs
    if activeTabId == tabId {
      let availableTabs = tabs.filter {
        $0.spaceId == closedTabSpaceId && $0.folderId == nil && !$0.isPinned
      }
      if let nextTab = availableTabs.first {
        activeTabId = nextTab.id
      } else {
        // No available tabs left - show Welcome screen
        activeTabId = nil
      }
    }

    // Persist tabs
    saveTabs()
  }

  func clearUngroupedTabs(in spaceId: UUID) {
    let ungroupedTabs = tabs.filter { $0.spaceId == spaceId && $0.folderId == nil && !$0.isPinned }
    let wasActiveInUngrouped = ungroupedTabs.contains { $0.id == activeTabId }

    // Close all ungrouped tabs
    for tab in ungroupedTabs {
      webViews.removeValue(forKey: tab.id)
      loadingObservations.removeValue(forKey: tab.id)
    }
    tabs.removeAll { $0.spaceId == spaceId && $0.folderId == nil && !$0.isPinned }

    // If active tab was among cleared tabs, show Welcome screen (don't switch to folder tabs)
    if wasActiveInUngrouped {
      activeTabId = nil
    }

    saveTabs()
  }

  func selectTab(_ tabId: UUID) {
    // Determine transition direction based on tab index
    if let currentTabId = activeTabId,
      let currentIndex = tabs.firstIndex(where: { $0.id == currentTabId }),
      let newIndex = tabs.firstIndex(where: { $0.id == tabId })
    {
      transitionDirection = newIndex > currentIndex ? .trailing : .leading
    }

    activeTabId = tabId
    if let tab = tabs.first(where: { $0.id == tabId }) {
      addressBarText = tab.url.absoluteString
    }

    // Persist active tab
    saveTabs()
  }

  func pinTab(_ tabId: UUID) {
    if let index = tabs.firstIndex(where: { $0.id == tabId }) {
      tabs[index].isPinned.toggle()
      saveTabs()
    }
  }

  func moveTab(_ tabId: UUID, toSpace spaceId: UUID) {
    if let index = tabs.firstIndex(where: { $0.id == tabId }) {
      tabs[index].spaceId = spaceId
      saveTabs()
    }
  }

  // MARK: - Navigation
  func loadURL(_ url: URL, for tabId: UUID) {
    guard let webView = webViews[tabId] else { return }

    // ✓ Minimal, system-consistent headers (what Safari actually sends)
    var request = URLRequest(url: url)
    StealthWebKitConfig.configureRequest(&request)

    // Debug log for sites with strong bot protection
    if StealthWebKitConfig.hasStrongBotProtection(url: url) {
      StealthWebKitConfig.logDiagnostic(for: webView, url: url)
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

    var shouldPersist = false

    if let title = title {
      tabs[index].title = title
      shouldPersist = true
    }
    if let url = url {
      tabs[index].url = url
      if tabId == activeTabId {
        addressBarText = url.absoluteString
      }
      // Load favicon when URL changes
      loadFavicon(for: tabId, url: url)
      shouldPersist = true
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

    // Persist only when URL or title changes (not for loading state changes)
    if shouldPersist {
      saveTabs()
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
  func createNewSpace(name: String, icon: String, color: Color, theme: SpaceTheme? = nil) {
    let newSpace = Space(name: name, icon: icon, color: color, theme: theme)
    spaces.append(newSpace)
    saveSpaces()
  }

  func updateSpace(id: UUID, name: String, icon: String, color: Color, theme: SpaceTheme?) {
    if let index = spaces.firstIndex(where: { $0.id == id }) {
      spaces[index].name = name
      spaces[index].icon = icon
      spaces[index].color = color
      spaces[index].theme = theme
      saveSpaces()
    }
  }

  func selectSpace(_ spaceId: UUID) {
    activeSpaceId = spaceId

    // Sync isLoading state with actual WebView state for tabs in this space
    // This fixes the bug where tabs show loading spinner after app restart
    // because the navigationDelegate wasn't assigned when WebViews were created
    syncLoadingStateForSpace(spaceId)

    // Select first tab in space (0 tabs = Welcome to Cloud)
    if let firstTab = tabs.first(where: { $0.spaceId == spaceId }) {
      activeTabId = firstTab.id
    } else {
      activeTabId = nil
    }
  }

  /// Synchronizes the isLoading state of tabs with the actual WebView loading state
  private func syncLoadingStateForSpace(_ spaceId: UUID) {
    for i in tabs.indices where tabs[i].spaceId == spaceId {
      let tabId = tabs[i].id
      if let webView = webViews[tabId] {
        // Sync with actual WebView state
        tabs[i].isLoading = webView.isLoading
      }
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

  func switchToNextSpace(animated: Bool = true) {
    guard let currentId = activeSpaceId,
      let currentIndex = spaces.firstIndex(where: { $0.id == currentId })
    else { return }

    transitionDirection = .trailing
    let nextIndex = (currentIndex + 1) % spaces.count
    if animated {
      withAnimation(.easeInOut(duration: 0.25)) {
        selectSpace(spaces[nextIndex].id)
      }
    } else {
      selectSpace(spaces[nextIndex].id)
    }
  }

  func switchToPreviousSpace(animated: Bool = true) {
    guard let currentId = activeSpaceId,
      let currentIndex = spaces.firstIndex(where: { $0.id == currentId })
    else { return }

    transitionDirection = .leading
    let prevIndex = (currentIndex - 1 + spaces.count) % spaces.count
    if animated {
      withAnimation(.easeInOut(duration: 0.25)) {
        selectSpace(spaces[prevIndex].id)
      }
    } else {
      selectSpace(spaces[prevIndex].id)
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

  func toggleHistoryPanel() {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
      isHistoryPanelVisible.toggle()
    }
  }

  func filteredHistory(searchText: String) -> [HistoryEntry] {
    guard !searchText.isEmpty else { return history }
    let lowercased = searchText.lowercased()
    return history.filter { entry in
      entry.title.lowercased().contains(lowercased)
        || entry.url.absoluteString.lowercased().contains(lowercased)
    }
  }

  func groupedHistory(searchText: String) -> [(String, [HistoryEntry])] {
    let filtered = filteredHistory(searchText: searchText)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

    var groups: [(String, [HistoryEntry])] = []

    let todayEntries = filtered.filter { calendar.isDate($0.visitDate, inSameDayAs: today) }
    let yesterdayEntries = filtered.filter { calendar.isDate($0.visitDate, inSameDayAs: yesterday) }
    let weekEntries = filtered.filter { $0.visitDate >= weekAgo && $0.visitDate < yesterday }
    let olderEntries = filtered.filter { $0.visitDate < weekAgo }

    if !todayEntries.isEmpty { groups.append(("Today", todayEntries)) }
    if !yesterdayEntries.isEmpty { groups.append(("Yesterday", yesterdayEntries)) }
    if !weekEntries.isEmpty { groups.append(("This Week", weekEntries)) }
    if !olderEntries.isEmpty { groups.append(("Older", olderEntries)) }

    return groups
  }

  func removeFromHistory(_ id: UUID) {
    history.removeAll { $0.id == id }
    saveHistory()
  }

  // MARK: - Search/Spotlight
  func toggleSpotlight() {
    isSpotlightVisible.toggle()
    if isSpotlightVisible {
      // Always reset search query and selection when opening via Cmd+T
      resetSpotlightInputState()
    }
  }

  func hideSpotlight() {
    isSpotlightVisible = false
    resetSpotlightInputState()
  }

  func openLocation() {
    isAskMode = false
    askQuestion = ""
    if let url = activeTab?.url {
      searchQuery = url.absoluteString
    } else {
      searchQuery = ""
    }
    isSpotlightVisible = true
  }

  private func resetSpotlightInputState() {
    // Always reset search query and selection when opening/closing Spotlight
    searchQuery = ""
    spotlightSelectedIndex = 0
    suggestions = []
    isAskMode = false
    askQuestion = ""
  }

  private func activateAskMode() {
    isSpotlightVisible = true
    isAskMode = true
    askQuestion = ""
    searchQuery = ""
    spotlightSelectedIndex = 0
    suggestions = []
  }

  func searchResults(for query: String) -> [SearchResult] {
    var results: [SearchResult] = []

    // When asking about the current page, we hide regular search results
    if isAskMode {
      return results
    }

    // Add "Summarize Page" command if there's an active tab with content
    if let activeTab = tabs.first(where: { $0.id == activeTabId }),
      !activeTab.isLoading,
      activeTab.url.absoluteString != "about:blank",
      query.localizedCaseInsensitiveContains("summ") || query.isEmpty
    {
      results.append(
        SearchResult(
          type: .command,
          title: "Summarize Page",
          subtitle: "Generate AI summary of current page",
          url: nil,
          tabId: activeTabId,
          favicon: nil
        ))

      let askQueryMatches =
        query.isEmpty
          || query.localizedCaseInsensitiveContains("ask")
          || query.localizedCaseInsensitiveContains("question")
          || query.localizedCaseInsensitiveContains("page")

      if askQueryMatches {
        results.append(
          SearchResult(
            type: .command,
            title: "Ask About WebPage",
            subtitle: "Ask AI a question about this page",
            url: nil,
            tabId: activeTabId,
            favicon: nil
          ))
      }
    }

    // Filter tabs by active space
    let spaceTabs = tabs.filter { $0.spaceId == activeSpaceId }

    if query.isEmpty {
      results.append(
        contentsOf: spaceTabs.map { tab in
          SearchResult(
            type: .tab,
            title: tab.title,
            subtitle: tab.url.host ?? tab.url.absoluteString,
            url: tab.url,
            tabId: tab.id,
            favicon: tab.favicon
          )
        })
      return results
    }

    let lowercasedQuery = query.lowercased()

    // Check if query looks like a URL (contains "://" OR contains dot and no spaces)
    let looksLikeURL = query.contains("://") || (query.contains(".") && !query.contains(" "))

    // 1. If it looks like a URL, add "Open website" FIRST (so Enter navigates directly)
    if looksLikeURL {
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

    // 2. Collect high-quality history matches with fuzzy matching and frecency scoring
    var historyMatches: [(score: Int, result: SearchResult)] = []
    for entry in history.prefix(100) {
      let matchScore = smartMatchScore(query: lowercasedQuery, entry: entry)
      if matchScore > 0 {
        let frecencyScore = calculateFrecencyScore(for: entry)
        let totalScore = matchScore + frecencyScore

        historyMatches.append((
          score: totalScore,
          result: SearchResult(
            type: .history,
            title: entry.title,
            subtitle: entry.url.host ?? entry.url.absoluteString,
            url: entry.url
          )
        ))
      }
    }

    // Sort history matches by combined score (highest first)
    historyMatches.sort { $0.score > $1.score }

    // Add top history matches BEFORE search suggestions
    let topHistoryMatches = historyMatches.prefix(5).map { $0.result }
    results.append(contentsOf: topHistoryMatches)

    // 3. Add search suggestion
    let searchUrl = URL(
      string:
        "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
    )
    results.append(
      SearchResult(
        type: .suggestion,
        title: query,
        subtitle: "Search Google",
        url: searchUrl
      ))

    // 4. Add Google suggestions (skip if matches the first search result)
    for suggestion in suggestions where suggestion.title.lowercased() != lowercasedQuery {
      results.append(suggestion)
    }

    // 5. Search tabs (only in current space)
    var tabMatches: [(score: Int, result: SearchResult)] = []
    for tab in spaceTabs {
      let matchScore = smartMatchScore(query: lowercasedQuery, tab: tab)
      if matchScore > 0 {
        tabMatches.append((
          score: matchScore,
          result: SearchResult(
            type: .tab,
            title: tab.title,
            subtitle: tab.url.host ?? tab.url.absoluteString,
            url: tab.url,
            tabId: tab.id,
            favicon: tab.favicon
          )
        ))
      }
    }

    tabMatches.sort { $0.score > $1.score }
    results.append(contentsOf: tabMatches.map { $0.result })

    // 6. Search bookmarks
    var bookmarkMatches: [(score: Int, result: SearchResult)] = []
    for bookmark in bookmarks {
      let matchScore = smartMatchScore(query: lowercasedQuery, bookmark: bookmark)
      if matchScore > 0 {
        bookmarkMatches.append((
          score: matchScore,
          result: SearchResult(
            type: .bookmark,
            title: bookmark.title,
            subtitle: bookmark.url.host ?? bookmark.url.absoluteString,
            url: bookmark.url
          )
        ))
      }
    }

    bookmarkMatches.sort { $0.score > $1.score }
    results.append(contentsOf: bookmarkMatches.map { $0.result })

    return results
  }

  // MARK: - Smart Matching & Scoring

  private func smartMatchScore(query: String, entry: HistoryEntry) -> Int {
    let domain = entry.url.host?.lowercased() ?? ""
    let path = entry.url.path.lowercased()
    let fullUrl = entry.url.absoluteString.lowercased()
    let title = entry.title.lowercased()

    return calculateMatchScore(
      query: query,
      domain: domain,
      path: path,
      fullUrl: fullUrl,
      title: title
    )
  }

  private func smartMatchScore(query: String, tab: BrowserTab) -> Int {
    let domain = tab.url.host?.lowercased() ?? ""
    let path = tab.url.path.lowercased()
    let fullUrl = tab.url.absoluteString.lowercased()
    let title = tab.title.lowercased()

    return calculateMatchScore(
      query: query,
      domain: domain,
      path: path,
      fullUrl: fullUrl,
      title: title
    )
  }

  private func smartMatchScore(query: String, bookmark: Bookmark) -> Int {
    let domain = bookmark.url.host?.lowercased() ?? ""
    let path = bookmark.url.path.lowercased()
    let fullUrl = bookmark.url.absoluteString.lowercased()
    let title = bookmark.title.lowercased()

    return calculateMatchScore(
      query: query,
      domain: domain,
      path: path,
      fullUrl: fullUrl,
      title: title
    )
  }

  private func calculateMatchScore(
    query: String, domain: String, path: String, fullUrl: String, title: String
  ) -> Int {
    // Exact prefix match on domain (highest priority)
    if domain.hasPrefix(query) {
      return 90
    }

    // Substring match in domain (e.g., "linke" matches "linkedin.com")
    if domain.contains(query) {
      return 80
    }

    // Fuzzy match in domain
    if fuzzyMatch(pattern: query, text: domain) {
      return 70
    }

    // Match in path
    if path.contains(query) {
      return 50
    }

    // Fuzzy match in full URL
    if fuzzyMatch(pattern: query, text: fullUrl) {
      return 40
    }

    // Match in title
    if title.contains(query) {
      return 30
    }

    // Fuzzy match in title
    if fuzzyMatch(pattern: query, text: title) {
      return 20
    }

    return 0
  }

  private func fuzzyMatch(pattern: String, text: String) -> Bool {
    var patternIndex = pattern.startIndex

    for char in text {
      if patternIndex < pattern.endIndex && char == pattern[patternIndex] {
        patternIndex = pattern.index(after: patternIndex)
      }
    }

    return patternIndex == pattern.endIndex
  }

  private func calculateFrecencyScore(for entry: HistoryEntry) -> Int {
    let now = Date()
    let daysSinceVisit = Calendar.current.dateComponents([.day], from: entry.visitDate, to: now).day ?? 0

    // Recency boost: recent visits score higher
    let recencyScore: Int
    switch daysSinceVisit {
    case 0:
      recencyScore = 10  // Today
    case 1:
      recencyScore = 8   // Yesterday
    case 2...6:
      recencyScore = 5   // This week
    case 7...30:
      recencyScore = 2   // This month
    default:
      recencyScore = 0   // Older
    }

    return recencyScore
  }

  func selectSearchResult(_ result: SearchResult) {
    print(
      "🔍 Spotlight: selectSearchResult called with type: \(result.type), title: \(result.title)")

    switch result.type {
    case .tab:
      // Switch to existing tab instead of creating new one
      if let tabId = result.tabId {
        print("  → Switching to existing tab")
        selectTab(tabId)
      }
      isSpotlightVisible = false
    case .bookmark, .history, .suggestion, .website:
      // Create NEW tab for bookmarks, history, suggestions, and websites (Arc-style behavior)
      if let url = result.url {
        print("  → Creating new tab for URL: \(url)")
        createNewTab(url: url)
      }
      isSpotlightVisible = false
    case .command:
      if result.title == "Ask About WebPage" {
        activateAskMode()
      } else {
        // Handle Summarize Page command
        hideSpotlight()
        summaryTask = Task {
          await summarizePage()
        }
      }
    }
  }

  // MARK: - Summary Methods
  @MainActor
  func summarizePage() async {
    guard let activeTab = tabs.first(where: { $0.id == activeTabId }),
      let webView = getWebView(for: activeTab.id)
    else {
      summaryError = "No active page to summarize"
      return
    }

    isAskMode = false
    askQuestion = ""

    // Reset cancellation flag
    isSummaryCancelled = false

    // Reset state
    isSummarizing = true
    summaryText = ""
    isSummaryComplete = false
    summaryError = nil
    summarizingStatus = "Extracting page content..."

    do {
      // Check for cancellation
      guard !isSummaryCancelled else { return }

      // Extract page content using JavaScript
      let pageContent =
        try await webView.evaluateJavaScript("document.body.innerText") as? String ?? ""

      guard !isSummaryCancelled else { return }

      guard !pageContent.isEmpty else {
        throw NSError(
          domain: "BrowserViewModel", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Page has no text content"])
      }

      // Clean content (remove excessive whitespace)
      let cleanedContent =
        pageContent
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")

      // Check for cancellation
      guard !isSummaryCancelled else { return }

      // Generate content hash for caching
      let contentHash = await cacheService.generateContentHash(cleanedContent)

      // Check cache first
      if let cachedSummary = await cacheService.getCachedSummary(
        for: activeTab.url, contentHash: contentHash)
      {
        guard !isSummaryCancelled else { return }
        summarizingStatus = "Loading cached summary..."
        summaryText = cachedSummary
        isSummaryComplete = true
        return
      }

      // Generate summary via API
      summarizingStatus = "Generating AI summary..."
      let stream = try await openAIService.streamSummary(for: cleanedContent)

      // Process streaming response with cancellation checks
      for try await chunk in stream {
        guard !isSummaryCancelled else { return }
        summaryText += chunk
      }

      // Check for cancellation before caching
      guard !isSummaryCancelled else { return }

      // Cache the generated summary
      await cacheService.cacheSummary(summaryText, for: activeTab.url, contentHash: contentHash)

      isSummaryComplete = true

    } catch let error as OpenAIError {
      if !isSummaryCancelled {
        summaryError = error.localizedDescription
        isSummarizing = false
      }
    } catch {
      if !isSummaryCancelled {
        summaryError = "Failed to generate summary: \(error.localizedDescription)"
        isSummarizing = false
      }
    }
  }

  @MainActor
  func askAboutPage(question: String) async {
    let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedQuestion.isEmpty else {
      summaryError = "Please enter a question about the page."
      return
    }

    guard let activeTab = tabs.first(where: { $0.id == activeTabId }),
      let webView = getWebView(for: activeTab.id)
    else {
      summaryError = "No active page to analyze"
      return
    }

    // Exit ask mode once the request starts (prevents stale badge)
    isAskMode = false
    askQuestion = trimmedQuestion

    // Reset cancellation flag
    isSummaryCancelled = false

    // Reset state
    isSummarizing = true
    summaryText = ""
    isSummaryComplete = false
    summaryError = nil
    summarizingStatus = "Extracting page content..."

    do {
      // Check for cancellation
      guard !isSummaryCancelled else { return }

      // Extract page content using JavaScript
      let pageContent =
        try await webView.evaluateJavaScript("document.body.innerText") as? String ?? ""

      guard !isSummaryCancelled else { return }

      guard !pageContent.isEmpty else {
        throw NSError(
          domain: "BrowserViewModel", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Page has no text content"])
      }

      // Clean content (remove excessive whitespace)
      let cleanedContent =
        pageContent
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")

      // Check for cancellation
      guard !isSummaryCancelled else { return }

      // Generate answer via API
      summarizingStatus = "Answering your question..."
      let stream = try await openAIService.streamAskAboutPage(
        content: cleanedContent, question: trimmedQuestion)

      // Process streaming response with cancellation checks
      for try await chunk in stream {
        guard !isSummaryCancelled else { return }
        summaryText += chunk
      }

      // Check for cancellation
      guard !isSummaryCancelled else { return }

      isSummaryComplete = true

    } catch let error as OpenAIError {
      if !isSummaryCancelled {
        summaryError = error.localizedDescription
        isSummarizing = false
      }
    } catch {
      if !isSummaryCancelled {
        summaryError = "Failed to generate answer: \(error.localizedDescription)"
        isSummarizing = false
      }
    }
  }

  func beginAskAboutPage(with question: String) {
    summaryTask = Task { [weak self] in
      guard let self = self else { return }
      await self.askAboutPage(question: question)
    }
  }

  @MainActor
  func restorePage() {
    // Set cancellation flag to stop any ongoing summary generation
    isSummaryCancelled = true
    summaryTask?.cancel()
    summaryTask = nil
    askQuestion = ""

    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
      isSummarizing = false
      summaryText = ""
      isSummaryComplete = false
      summaryError = nil
      summarizingStatus = ""
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

  // MARK: - Folder Management

  func createFolder(in spaceId: UUID, name: String = "New Folder", startEditing: Bool = true) -> TabFolder {
    let maxOrder = folders.filter { $0.spaceId == spaceId }.map { $0.sortOrder }.max() ?? -1
    let folder = TabFolder(name: name, spaceId: spaceId, sortOrder: maxOrder + 1)
    folders.append(folder)
    saveFolders()
    // Trigger edit mode for the new folder
    if startEditing {
      editingFolderId = folder.id
    }
    return folder
  }

  func deleteFolder(_ folderId: UUID) {
    // Move all tabs in this folder back to ungrouped
    for i in tabs.indices where tabs[i].folderId == folderId {
      tabs[i].folderId = nil
    }
    folders.removeAll { $0.id == folderId }
    saveFolders()
    saveTabs()
  }

  func renameFolder(_ folderId: UUID, to name: String) {
    if let index = folders.firstIndex(where: { $0.id == folderId }) {
      folders[index].name = name
      saveFolders()
    }
  }

  func toggleFolderExpanded(_ folderId: UUID) {
    if let index = folders.firstIndex(where: { $0.id == folderId }) {
      folders[index].isExpanded.toggle()
      saveFolders()
    }
  }

  func moveTabToFolder(_ tabId: UUID, folderId: UUID?) {
    if let index = tabs.firstIndex(where: { $0.id == tabId }) {
      tabs[index].folderId = folderId
      // Update sort order to be last in folder
      if let folderId = folderId {
        let maxOrder = tabs.filter { $0.folderId == folderId }.map { $0.sortOrder }.max() ?? -1
        tabs[index].sortOrder = maxOrder + 1
      }
      saveTabs()
    }
  }

  func foldersForSpace(_ spaceId: UUID) -> [TabFolder] {
    folders.filter { $0.spaceId == spaceId }.sorted { $0.sortOrder < $1.sortOrder }
  }

  func tabsInFolder(_ folderId: UUID) -> [BrowserTab] {
    tabs.filter { $0.folderId == folderId && !$0.isPinned }.sorted { $0.sortOrder < $1.sortOrder }
  }

  func ungroupedTabsForSpace(_ spaceId: UUID) -> [BrowserTab] {
    tabs.filter { $0.spaceId == spaceId && $0.folderId == nil && !$0.isPinned }.sorted { $0.sortOrder < $1.sortOrder }
  }

  // MARK: - Persistence
  private func loadPersistedData() {
    loadBookmarks()
    loadHistory()
  }

  // MARK: - Tabs Persistence
  func saveTabs() {
    if let encoded = try? JSONEncoder().encode(tabs) {
      UserDefaults.standard.set(encoded, forKey: "cloud_tabs")
    }
    saveActiveIds()
  }

  private func loadTabs() {
    if let data = UserDefaults.standard.data(forKey: "cloud_tabs"),
      let decoded = try? JSONDecoder().decode([BrowserTab].self, from: data),
      !decoded.isEmpty
    {
      tabs = decoded
      // Reload favicons for restored tabs
      for tab in tabs {
        loadFavicon(for: tab.id, url: tab.url)
      }
    }
  }

  private func saveActiveIds() {
    if let activeTabId = activeTabId {
      UserDefaults.standard.set(activeTabId.uuidString, forKey: "cloud_activeTabId")
    }
    if let activeSpaceId = activeSpaceId {
      UserDefaults.standard.set(activeSpaceId.uuidString, forKey: "cloud_activeSpaceId")
    }
  }

  private func loadActiveIds() {
    // Load space FIRST
    if let spaceIdString = UserDefaults.standard.string(forKey: "cloud_activeSpaceId"),
      let spaceId = UUID(uuidString: spaceIdString),
      spaces.contains(where: { $0.id == spaceId })
    {
      activeSpaceId = spaceId
    } else if let firstSpace = spaces.first {
      activeSpaceId = firstSpace.id
    }

    // Then load tab - only from the active space
    if let tabIdString = UserDefaults.standard.string(forKey: "cloud_activeTabId"),
      let tabId = UUID(uuidString: tabIdString),
      let tab = tabs.first(where: { $0.id == tabId }),
      tab.spaceId == activeSpaceId
    {
      activeTabId = tabId
    } else if let activeSpaceId = activeSpaceId,
      let firstTabInSpace = tabs.first(where: { $0.spaceId == activeSpaceId })
    {
      activeTabId = firstTabInSpace.id
    } else {
      activeTabId = nil
    }
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

  // MARK: - Spaces Persistence

  private func saveSpaces() {
    if let encoded = try? JSONEncoder().encode(spaces) {
      UserDefaults.standard.set(encoded, forKey: "cloud_spaces")
    }
  }

  private func loadSpaces() {
    if let data = UserDefaults.standard.data(forKey: "cloud_spaces"),
      let decoded = try? JSONDecoder().decode([Space].self, from: data)
    {
      spaces = decoded
      // Set active space to first one if not set
      if activeSpaceId == nil, let firstSpace = spaces.first {
        activeSpaceId = firstSpace.id
      }
    }
  }

  // MARK: - Folders Persistence

  private func saveFolders() {
    if let encoded = try? JSONEncoder().encode(folders) {
      UserDefaults.standard.set(encoded, forKey: "cloud_folders")
    }
  }

  private func loadFolders() {
    if let data = UserDefaults.standard.data(forKey: "cloud_folders"),
      let decoded = try? JSONDecoder().decode([TabFolder].self, from: data)
    {
      folders = decoded
    }
  }
}
