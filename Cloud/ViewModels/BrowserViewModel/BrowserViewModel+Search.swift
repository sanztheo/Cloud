//
//  BrowserViewModel+Search.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Extension handling Spotlight search, suggestions, and result selection.
//

import Combine
import Foundation

// MARK: - Search/Spotlight
extension BrowserViewModel {

  func setupSearchSubscriptions() {
    $searchQuery
      .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
      .removeDuplicates()
      .flatMap { [weak self] query -> AnyPublisher<[String], Never> in
        guard let self = self, !query.isEmpty, !self.isAskMode, !self.isAISearchMode else {
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

  func resetSpotlightInputState() {
    // Always reset search query and selection when opening/closing Spotlight
    searchQuery = ""
    spotlightSelectedIndex = 0
    suggestions = []
    isAskMode = false
    askQuestion = ""
    resetAISearch()
  }

  func activateAskMode() {
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

    // Add "Search History with AI" command - only when query is empty or explicitly matches keywords
    // Use word boundary matching to avoid false positives (e.g., "gmail" contains "ai")
    let lowercasedQuery = query.lowercased()
    let queryWords = Set(lowercasedQuery.split(separator: " ").map { String($0) })
    let aiKeywords: Set<String> = ["search", "history", "ai", "find", "cherche", "historique"]
    let hasAIKeyword = !queryWords.isDisjoint(with: aiKeywords)
      || lowercasedQuery == "ai"
      || lowercasedQuery.hasPrefix("ai ")
      || lowercasedQuery.hasSuffix(" ai")

    let aiSearchMatches = query.isEmpty || hasAIKeyword

    if aiSearchMatches && EmbeddingService.shared.isAvailable {
      results.append(
        SearchResult(
          type: .command,
          title: "Search History with AI",
          subtitle: "Find pages using natural language",
          url: nil,
          tabId: nil,
          favicon: nil
        ))
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
    // Use a Set to track seen URLs and avoid duplicates
    var seenHistoryKeys = Set<String>()
    var historyMatches: [(score: Int, result: SearchResult)] = []

    for entry in history.prefix(100) {
      let matchScore = smartMatchScore(query: lowercasedQuery, entry: entry)
      if matchScore > 0 {
        // Deduplicate by host + title (same page = same result)
        let dedupeKey = "\(entry.url.host ?? "")||\(entry.title)"
        guard !seenHistoryKeys.contains(dedupeKey) else { continue }
        seenHistoryKeys.insert(dedupeKey)

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

  func smartMatchScore(query: String, entry: HistoryEntry) -> Int {
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

  func smartMatchScore(query: String, tab: BrowserTab) -> Int {
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

  func smartMatchScore(query: String, bookmark: Bookmark) -> Int {
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

  func calculateMatchScore(
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

  func fuzzyMatch(pattern: String, text: String) -> Bool {
    var patternIndex = pattern.startIndex

    for char in text {
      if patternIndex < pattern.endIndex && char == pattern[patternIndex] {
        patternIndex = pattern.index(after: patternIndex)
      }
    }

    return patternIndex == pattern.endIndex
  }

  func calculateFrecencyScore(for entry: HistoryEntry) -> Int {
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
      hideSpotlight()
    case .bookmark, .history, .suggestion, .website:
      // Create NEW tab for bookmarks, history, suggestions, and websites (Arc-style behavior)
      if let url = result.url {
        print("  → Creating new tab for URL: \(url)")
        createNewTab(url: url)
      }
      hideSpotlight()
    case .command:
      if result.title == "Ask About WebPage" {
        activateAskMode()
      } else if result.title == "Search History with AI" {
        activateAISearchMode()
      } else {
        // Handle Summarize Page command
        hideSpotlight()
        summaryTask = Task {
          await summarizePage()
        }
      }
    }
  }
}
