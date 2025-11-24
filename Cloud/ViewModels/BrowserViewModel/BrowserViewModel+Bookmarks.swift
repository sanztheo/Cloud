//
//  BrowserViewModel+Bookmarks.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Extension handling bookmark creation and management.
//

import Foundation

// MARK: - Bookmarks
extension BrowserViewModel {

  func addBookmark(url: URL, title: String) {
    let currentUserId = SupabaseService.shared.currentUserId
    let bookmark = Bookmark(url: url, title: title, userId: currentUserId)
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
}
