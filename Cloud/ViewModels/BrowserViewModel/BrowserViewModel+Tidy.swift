//
//  BrowserViewModel+Tidy.swift
//  Cloud
//
//  Extension handling AI-powered tab categorization (Tidy feature).
//

import Foundation

// MARK: - Tidy (Tab Categorization)
extension BrowserViewModel {

  // MARK: - Computed Properties

  /// Returns true if tidy button should be shown (4+ ungrouped tabs without category in current space)
  var shouldShowTidy: Bool {
    guard let spaceId = activeSpaceId else { return false }
    let uncategorizedTabs = tabs.filter {
      $0.spaceId == spaceId &&
      $0.folderId == nil &&
      !$0.isPinned &&
      $0.category == nil
    }
    return uncategorizedTabs.count >= 4
  }

  /// Groups tabs by category for display in sidebar
  /// Returns array of tuples: (category name, tabs in that category)
  /// Categories are sorted alphabetically, with "Other" always last
  func groupedTabsByCategory(for spaceId: UUID) -> [(category: String, tabs: [BrowserTab])] {
    let ungroupedTabs = tabs.filter {
      $0.spaceId == spaceId &&
      $0.folderId == nil &&
      !$0.isPinned
    }

    // Group tabs by category
    var categoryGroups: [String: [BrowserTab]] = [:]
    for tab in ungroupedTabs {
      if let category = tab.category {
        categoryGroups[category, default: []].append(tab)
      }
    }

    // Sort categories alphabetically, but keep "Other" at the end
    let sortedCategories = categoryGroups.keys.sorted { cat1, cat2 in
      if cat1 == "Other" { return false }
      if cat2 == "Other" { return true }
      return cat1 < cat2
    }

    return sortedCategories.map { category in
      (category: category, tabs: categoryGroups[category] ?? [])
    }
  }

  /// Returns tabs without a category for the given space
  func uncategorizedTabsForSpace(_ spaceId: UUID) -> [BrowserTab] {
    tabs.filter {
      $0.spaceId == spaceId &&
      $0.folderId == nil &&
      !$0.isPinned &&
      $0.category == nil
    }
  }

  /// Returns ungrouped (non-pinned, not in folder) tabs for the given space
  func ungroupedTabsForSpace(_ spaceId: UUID) -> [BrowserTab] {
    tabs.filter {
      $0.spaceId == spaceId &&
      $0.folderId == nil &&
      !$0.isPinned
    }
  }

  /// Check if there are any categorized tabs in the space
  func hasCategorizedTabs(in spaceId: UUID) -> Bool {
    tabs.contains {
      $0.spaceId == spaceId &&
      $0.folderId == nil &&
      !$0.isPinned &&
      $0.category != nil
    }
  }

  // MARK: - Actions

  /// Categorize tabs in the current space using AI
  @MainActor
  func tidyTabs() async {
    guard let spaceId = activeSpaceId else { return }

    // Get uncategorized tabs to process
    let tabsToProcess = uncategorizedTabsForSpace(spaceId)
    guard !tabsToProcess.isEmpty else { return }

    let service = TabCategorizationService()

    do {
      // Call AI service to categorize tabs
      let categories = try await service.categorizeTabsWithAI(tabs: tabsToProcess)

      // Apply categories to tabs
      for (tabId, category) in categories {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
          tabs[index].category = category
        }
      }

      // Save changes
      saveTabs()

    } catch {
      print("Tidy error: \(error.localizedDescription)")
    }
  }

  /// Clear category from a specific tab
  func clearTabCategory(_ tabId: UUID) {
    if let index = tabs.firstIndex(where: { $0.id == tabId }) {
      tabs[index].category = nil
      saveTabs()
    }
  }

  /// Clear all categories in the current space
  func clearAllCategories() {
    guard let spaceId = activeSpaceId else { return }

    for index in tabs.indices {
      if tabs[index].spaceId == spaceId {
        tabs[index].category = nil
      }
    }
    saveTabs()
  }
}
