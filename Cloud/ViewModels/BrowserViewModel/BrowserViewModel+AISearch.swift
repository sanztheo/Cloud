//
//  BrowserViewModel+AISearch.swift
//  Cloud
//
//  Extension for AI semantic search - simplified
//

import Combine
import Foundation

// MARK: - AI Search
extension BrowserViewModel {

  /// Check if AI search mode is active (single source of truth)
  var isAISearchMode: Bool {
    get { _isAISearchMode }
    set { _isAISearchMode = newValue }
  }

  /// AI search results
  var aiSearchResults: [SearchResult] {
    _aiSearchResults
  }

  /// Activate AI Search mode
  func activateAISearchMode() {
    isSpotlightVisible = true
    _isAISearchMode = true
    _aiSearchResults = []
    searchQuery = ""
    suggestions = []
  }

  /// Set AI results from search
  func setAIResults(_ results: [SearchResult]) {
    _aiSearchResults = results
  }

  /// Clear AI results (but stay in AI mode)
  func clearAIResults() {
    _aiSearchResults = []
  }

  /// Reset AI search (exit AI mode)
  func resetAISearch() {
    _isAISearchMode = false
    _aiSearchResults = []
  }

  /// Index history for semantic search
  func indexHistoryForSemanticSearch() {
    let recentHistory = Array(history.prefix(300))
    Task {
      do {
        try await LocalRAGService.shared.indexHistoryBatch(recentHistory)
        print("Indexed \(recentHistory.count) history entries")
      } catch {
        print("Failed to index history: \(error)")
      }
    }
  }
}
