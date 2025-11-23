//
//  BrowserViewModel+Persistence.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Extension handling data persistence (UserDefaults save/load).
//

import Foundation

// MARK: - Persistence
extension BrowserViewModel {

  func loadPersistedData() {
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

  func loadTabs() {
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

  func saveActiveIds() {
    if let activeTabId = activeTabId {
      UserDefaults.standard.set(activeTabId.uuidString, forKey: "cloud_activeTabId")
    }
    if let activeSpaceId = activeSpaceId {
      UserDefaults.standard.set(activeSpaceId.uuidString, forKey: "cloud_activeSpaceId")
    }
  }

  func loadActiveIds() {
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

  // MARK: - Bookmarks Persistence
  func saveBookmarks() {
    if let encoded = try? JSONEncoder().encode(bookmarks) {
      UserDefaults.standard.set(encoded, forKey: "cloud_bookmarks")
    }
  }

  func loadBookmarks() {
    if let data = UserDefaults.standard.data(forKey: "cloud_bookmarks"),
      let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
    {
      bookmarks = decoded
    }
  }

  // MARK: - History Persistence
  func saveHistory() {
    if let encoded = try? JSONEncoder().encode(history) {
      UserDefaults.standard.set(encoded, forKey: "cloud_history")
    }
  }

  func loadHistory() {
    if let data = UserDefaults.standard.data(forKey: "cloud_history"),
      let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
    {
      history = decoded
    }
  }

  // MARK: - Spaces Persistence
  func saveSpaces() {
    if let encoded = try? JSONEncoder().encode(spaces) {
      UserDefaults.standard.set(encoded, forKey: "cloud_spaces")
    }
  }

  func loadSpaces() {
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
  func saveFolders() {
    if let encoded = try? JSONEncoder().encode(folders) {
      UserDefaults.standard.set(encoded, forKey: "cloud_folders")
    }
  }

  func loadFolders() {
    if let data = UserDefaults.standard.data(forKey: "cloud_folders"),
      let decoded = try? JSONDecoder().decode([TabFolder].self, from: data)
    {
      folders = decoded
    }
  }
}
