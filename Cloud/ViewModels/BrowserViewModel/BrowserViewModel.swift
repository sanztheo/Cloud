//
//  BrowserViewModel.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Core ViewModel containing properties and initialization.
//  Extensions are organized in separate files by responsibility.
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
  var webViews: [UUID: WKWebView] = [:]
  var cancellables = Set<AnyCancellable>()
  var loadingObservations: [UUID: NSKeyValueObservation] = [:]

  // MARK: - Search Suggestions
  let suggestionsService = GoogleSuggestionsService()
  @Published var suggestions: [SearchResult] = []

  // MARK: - AI Search State
  var _isAISearchMode: Bool = false
  var _aiSearchResults: [SearchResult] = []

  // MARK: - Services
  let openAIService = OpenAIService()
  let cacheService = SummaryCacheService.shared

  // Task for summary generation (to support cancellation)
  var summaryTask: Task<Void, Never>?
  var isSummaryCancelled: Bool = false

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

    // Index history for semantic search after a short delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.indexHistoryForSemanticSearch()
    }
  }

  func setupDownloadNotifications() {
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

  func setupInitialData() {
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
}
