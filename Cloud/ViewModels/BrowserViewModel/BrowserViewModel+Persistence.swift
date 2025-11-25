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

  // MARK: - User-Scoped Storage Keys
  private func storageKey(_ base: String) -> String {
    guard let userId = SupabaseService.shared.currentUserId else {
      return base  // Fallback to unscoped key if no user
    }
    return "\(base)_\(userId)"
  }

  func loadPersistedData() {
    loadBookmarks()
    loadHistory()
  }

  // MARK: - Tabs Persistence
  func saveTabs() {
    // Filter tabs for current user
    let currentUserId = SupabaseService.shared.currentUserId
    let userTabs = tabs.map { tab -> BrowserTab in
      var updatedTab = tab
      updatedTab.userId = currentUserId
      return updatedTab
    }

    if let encoded = try? JSONEncoder().encode(userTabs) {
      UserDefaults.standard.set(encoded, forKey: storageKey("cloud_tabs"))
    }
    saveActiveIds()
  }

  func loadTabs() {
    let currentUserId = SupabaseService.shared.currentUserId

    if let data = UserDefaults.standard.data(forKey: storageKey("cloud_tabs")),
      let decoded = try? JSONDecoder().decode([BrowserTab].self, from: data),
      !decoded.isEmpty
    {
      // Filter tabs by current user or accept tabs without userId (legacy data)
      tabs = decoded.filter { tab in
        tab.userId == nil || tab.userId == currentUserId
      }

      // Reload favicons for restored tabs
      for tab in tabs {
        loadFavicon(for: tab.id, url: tab.url)
      }
    }
  }

  func saveActiveIds() {
    if let activeTabId = activeTabId {
      UserDefaults.standard.set(activeTabId.uuidString, forKey: storageKey("cloud_activeTabId"))
    }
    if let activeSpaceId = activeSpaceId {
      UserDefaults.standard.set(activeSpaceId.uuidString, forKey: storageKey("cloud_activeSpaceId"))
    }
  }

  func loadActiveIds() {
    // Load space FIRST
    if let spaceIdString = UserDefaults.standard.string(forKey: storageKey("cloud_activeSpaceId")),
      let spaceId = UUID(uuidString: spaceIdString),
      spaces.contains(where: { $0.id == spaceId })
    {
      activeSpaceId = spaceId
    } else if let firstSpace = spaces.first {
      activeSpaceId = firstSpace.id
    }

    // Then load tab - only from the active space
    if let tabIdString = UserDefaults.standard.string(forKey: storageKey("cloud_activeTabId")),
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
    let currentUserId = SupabaseService.shared.currentUserId
    let userBookmarks = bookmarks.map { bookmark -> Bookmark in
      var updatedBookmark = bookmark
      updatedBookmark.userId = currentUserId
      return updatedBookmark
    }

    if let encoded = try? JSONEncoder().encode(userBookmarks) {
      UserDefaults.standard.set(encoded, forKey: storageKey("cloud_bookmarks"))
    }
  }

  func loadBookmarks() {
    let currentUserId = SupabaseService.shared.currentUserId

    if let data = UserDefaults.standard.data(forKey: storageKey("cloud_bookmarks")),
      let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
    {
      bookmarks = decoded.filter { bookmark in
        bookmark.userId == nil || bookmark.userId == currentUserId
      }
    } else {
      // No bookmarks found for this user - ensure array is empty
      bookmarks = []
    }
  }

  // MARK: - History Persistence
  func saveHistory() {
    let currentUserId = SupabaseService.shared.currentUserId
    let userHistory = history.map { entry -> HistoryEntry in
      var updatedEntry = entry
      updatedEntry.userId = currentUserId
      return updatedEntry
    }

    if let encoded = try? JSONEncoder().encode(userHistory) {
      UserDefaults.standard.set(encoded, forKey: storageKey("cloud_history"))
    }
  }

  func loadHistory() {
    let currentUserId = SupabaseService.shared.currentUserId

    if let data = UserDefaults.standard.data(forKey: storageKey("cloud_history")),
      let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
    {
      history = decoded.filter { entry in
        entry.userId == nil || entry.userId == currentUserId
      }
    } else {
      // No history found for this user - ensure array is empty
      history = []
    }
  }

  // MARK: - Spaces Persistence
  func saveSpaces() {
    let currentUserId = SupabaseService.shared.currentUserId
    let userSpaces = spaces.map { space -> Space in
      var updatedSpace = space
      updatedSpace.userId = currentUserId
      return updatedSpace
    }

    if let encoded = try? JSONEncoder().encode(userSpaces) {
      UserDefaults.standard.set(encoded, forKey: storageKey("cloud_spaces"))
    }
  }

  func loadSpaces() {
    let currentUserId = SupabaseService.shared.currentUserId

    if let data = UserDefaults.standard.data(forKey: storageKey("cloud_spaces")),
      let decoded = try? JSONDecoder().decode([Space].self, from: data)
    {
      spaces = decoded.filter { space in
        space.userId == nil || space.userId == currentUserId
      }

      // Set active space to first one if not set
      if activeSpaceId == nil, let firstSpace = spaces.first {
        activeSpaceId = firstSpace.id
      }
    }
  }

  // MARK: - Folders Persistence
  func saveFolders() {
    let currentUserId = SupabaseService.shared.currentUserId
    let userFolders = folders.map { folder -> TabFolder in
      var updatedFolder = folder
      updatedFolder.userId = currentUserId
      return updatedFolder
    }

    if let encoded = try? JSONEncoder().encode(userFolders) {
      UserDefaults.standard.set(encoded, forKey: storageKey("cloud_folders"))
    }
  }

  func loadFolders() {
    let currentUserId = SupabaseService.shared.currentUserId

    if let data = UserDefaults.standard.data(forKey: storageKey("cloud_folders")),
      let decoded = try? JSONDecoder().decode([TabFolder].self, from: data)
    {
      folders = decoded.filter { folder in
        folder.userId == nil || folder.userId == currentUserId
      }
    }
  }

  // MARK: - Session Management
  func clearSessionData() {
    tabs.removeAll()
    spaces.removeAll()
    folders.removeAll()
    bookmarks.removeAll()
    history.removeAll()
    activeTabId = nil
    activeSpaceId = nil

    // Clear RAG index
    Task {
      await LocalRAGService.shared.clearIndex()
      print("✅ Cleared RAG index on sign out")
    }
  }
}
