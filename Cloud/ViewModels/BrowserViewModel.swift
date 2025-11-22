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
  @Published var isHistoryPanelVisible: Bool = false
  @Published var searchQuery: String = ""
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
    // Load spaces from UserDefaults if available
    loadSpaces()

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
    // ✓ Utiliser la configuration optimisée (cohérence > stealth)
    let configuration = OptimizedWebKitConfig.createConfiguration()

    // Use CustomWKWebView to disable rubber banding
    let webView = CustomWKWebView(
      frame: NSRect(x: 0, y: 0, width: 100, height: 100), configuration: configuration)

    // ✓ Setup avec User-Agent STABLE et configuration optimale
    OptimizedWebKitConfig.setupWebView(webView)

    // ✓ Pas d'injection JavaScript agressive (détectée par OpenAI/Claude)

    webViews[tab.id] = webView

    // Observe isLoading via KVO to sync with tab model
    // This ensures isLoading is updated even without navigationDelegate
    let tabId = tab.id
    loadingObservations[tabId] = webView.observe(\.isLoading, options: [.new]) { [weak self] webView, change in
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

    // Remove WebView and KVO observation
    webViews.removeValue(forKey: tabId)
    loadingObservations.removeValue(forKey: tabId)
    tabs.removeAll { $0.id == tabId }

    // Update active tab - only select tabs from the SAME space
    if activeTabId == tabId {
      let tabsInSameSpace = tabs.filter { $0.spaceId == closedTabSpaceId }
      if let nextTab = tabsInSameSpace.first {
        activeTabId = nextTab.id
      } else {
        activeTabId = nil
      }
    }

    // Persist tabs
    saveTabs()
  }

  func selectTab(_ tabId: UUID) {
    // Determine transition direction based on tab index
    if let currentTabId = activeTabId,
       let currentIndex = tabs.firstIndex(where: { $0.id == currentTabId }),
       let newIndex = tabs.firstIndex(where: { $0.id == tabId }) {
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
      entry.title.lowercased().contains(lowercased) ||
      entry.url.absoluteString.lowercased().contains(lowercased)
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
      searchQuery = ""
      spotlightSelectedIndex = 0
      suggestions = []
    }
  }

  func hideSpotlight() {
    isSpotlightVisible = false
    searchQuery = ""
    spotlightSelectedIndex = 0
  }

  func openLocation() {
    if let url = activeTab?.url {
      searchQuery = url.absoluteString
    } else {
      searchQuery = ""
    }
    isSpotlightVisible = true
  }

  func searchResults(for query: String) -> [SearchResult] {
    var results: [SearchResult] = []

    // Add "Summarize Page" command if there's an active tab with content
    if let activeTab = tabs.first(where: { $0.id == activeTabId }),
       !activeTab.isLoading,
       activeTab.url.absoluteString != "about:blank",
       query.localizedCaseInsensitiveContains("summ") || query.isEmpty {
      results.append(SearchResult(
        type: .command,
        title: "Summarize Page",
        subtitle: "Generate AI summary of current page",
        url: nil,
        tabId: activeTabId,
        favicon: nil
      ))
    }

    // Filter tabs by active space
    let spaceTabs = tabs.filter { $0.spaceId == activeSpaceId }

    if query.isEmpty {
      results.append(contentsOf: spaceTabs.map { tab in
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

    // 2. Add search suggestion (second if URL, first otherwise)
    let searchUrl = URL(
      string: "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
    )
    results.append(
      SearchResult(
        type: .suggestion,
        title: query,
        subtitle: "Search Google",
        url: searchUrl
      ))

    // 3. Add Google suggestions (skip if matches the first search result)
    for suggestion in suggestions where suggestion.title.lowercased() != lowercasedQuery {
      results.append(suggestion)
    }

    // 4. Search history
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

    // 5. Search tabs (only in current space)
    for tab in spaceTabs
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

    // 6. Search bookmarks
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

    print(
      "🔍 Spotlight: selectSearchResult called with type: \(result.type), title: \(result.title)")

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
    case .command:
      // Handle Summarize Page command
      hideSpotlight()
      summaryTask = Task {
        await summarizePage()
      }
    }
  }

  // MARK: - Summary Methods
  @MainActor
  func summarizePage() async {
    guard let activeTab = tabs.first(where: { $0.id == activeTabId }),
          let webView = getWebView(for: activeTab.id) else {
      summaryError = "No active page to summarize"
      return
    }

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
      let pageContent = try await webView.evaluateJavaScript("document.body.innerText") as? String ?? ""

      guard !isSummaryCancelled else { return }

      guard !pageContent.isEmpty else {
        throw NSError(domain: "BrowserViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Page has no text content"])
      }

      // Clean content (remove excessive whitespace)
      let cleanedContent = pageContent
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")

      // Check for cancellation
      guard !isSummaryCancelled else { return }

      // Generate content hash for caching
      let contentHash = await cacheService.generateContentHash(cleanedContent)

      // Check cache first
      if let cachedSummary = await cacheService.getCachedSummary(for: activeTab.url, contentHash: contentHash) {
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
  func restorePage() {
    // Set cancellation flag to stop any ongoing summary generation
    isSummaryCancelled = true
    summaryTask?.cancel()
    summaryTask = nil

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
       !decoded.isEmpty {
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
       spaces.contains(where: { $0.id == spaceId }) {
      activeSpaceId = spaceId
    } else if let firstSpace = spaces.first {
      activeSpaceId = firstSpace.id
    }

    // Then load tab - only from the active space
    if let tabIdString = UserDefaults.standard.string(forKey: "cloud_activeTabId"),
       let tabId = UUID(uuidString: tabIdString),
       let tab = tabs.first(where: { $0.id == tabId }),
       tab.spaceId == activeSpaceId {
      activeTabId = tabId
    } else if let activeSpaceId = activeSpaceId,
              let firstTabInSpace = tabs.first(where: { $0.spaceId == activeSpaceId }) {
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
}
