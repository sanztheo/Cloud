//
//  BrowserViewModel+History.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Extension handling browsing history management.
//

import Foundation
import SwiftUI

// MARK: - History
extension BrowserViewModel {

  func addToHistory(url: URL, title: String) {
    let currentUserId = SupabaseService.shared.currentUserId
    let entry = HistoryEntry(url: url, title: title, userId: currentUserId)
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
    let currentUserId = SupabaseService.shared.currentUserId

    // Filter by userId first (include entries with nil userId for legacy data or no userId for current user)
    let userHistory = history.filter { entry in
      entry.userId == currentUserId || (entry.userId == nil && currentUserId == nil)
    }

    guard !searchText.isEmpty else { return userHistory }
    let lowercased = searchText.lowercased()
    return userHistory.filter { entry in
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
}
