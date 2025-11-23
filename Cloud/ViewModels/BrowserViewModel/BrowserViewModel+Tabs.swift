//
//  BrowserViewModel+Tabs.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Extension handling tab creation, selection, and management.
//

import AppKit
import Foundation

// MARK: - Tab Management
extension BrowserViewModel {

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
  func loadFavicon(for tabId: UUID, url: URL) {
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
}
