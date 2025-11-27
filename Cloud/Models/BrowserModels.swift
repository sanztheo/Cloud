//
//  BrowserModels.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import Foundation
import SwiftUI

// MARK: - Tab Model
struct BrowserTab: Identifiable, Equatable, Codable {
  let id: UUID
  var url: URL
  var title: String
  var favicon: NSImage?  // Not persisted, reloaded on restore
  var isLoading: Bool
  var canGoBack: Bool
  var canGoForward: Bool
  var isPinned: Bool
  var spaceId: UUID
  var folderId: UUID?
  var sortOrder: Int
  var userId: String?  // User ID for data isolation
  var category: String?  // AI-assigned category for Tidy feature

  init(
    id: UUID = UUID(),
    url: URL = URL(string: "https://www.google.com")!,
    title: String = "New Tab",
    favicon: NSImage? = nil,
    isLoading: Bool = false,
    canGoBack: Bool = false,
    canGoForward: Bool = false,
    isPinned: Bool = false,
    spaceId: UUID,
    folderId: UUID? = nil,
    sortOrder: Int = 0,
    userId: String? = nil,
    category: String? = nil
  ) {
    self.id = id
    self.url = url
    self.title = title
    self.favicon = favicon
    self.isLoading = isLoading
    self.canGoBack = canGoBack
    self.canGoForward = canGoForward
    self.isPinned = isPinned
    self.spaceId = spaceId
    self.folderId = folderId
    self.sortOrder = sortOrder
    self.userId = userId
    self.category = category
  }

  // Custom coding keys to exclude favicon (NSImage is not Codable) and isLoading (runtime state)
  enum CodingKeys: String, CodingKey {
    case id, url, title, canGoBack, canGoForward, isPinned, spaceId, folderId, sortOrder, userId, category
    // Note: isLoading is excluded - it's a runtime state, not persisted
  }

  // Custom decoder to handle isLoading (not persisted, always starts as false)
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    url = try container.decode(URL.self, forKey: .url)
    title = try container.decode(String.self, forKey: .title)
    canGoBack = try container.decode(Bool.self, forKey: .canGoBack)
    canGoForward = try container.decode(Bool.self, forKey: .canGoForward)
    isPinned = try container.decode(Bool.self, forKey: .isPinned)
    spaceId = try container.decode(UUID.self, forKey: .spaceId)
    folderId = try container.decodeIfPresent(UUID.self, forKey: .folderId)
    sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    userId = try container.decodeIfPresent(String.self, forKey: .userId)
    category = try container.decodeIfPresent(String.self, forKey: .category)
    // Runtime state - not persisted
    favicon = nil
    isLoading = false
  }

  static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - Space Model
struct Space: Identifiable, Equatable, Codable {
  let id: UUID
  var name: String
  var icon: String
  var colorHex: String  // Store as hex string for Codable
  var theme: SpaceTheme?
  var userId: String?  // User ID for data isolation

  // Computed property for Color
  var color: Color {
    get { Color(hex: colorHex) }
    set { colorHex = newValue.toHex() ?? "#0066FF" }
  }

  init(
    id: UUID = UUID(),
    name: String = "Personal",
    icon: String = "person.fill",
    color: Color = .blue,
    theme: SpaceTheme? = nil,
    userId: String? = nil
  ) {
    self.id = id
    self.name = name
    self.icon = icon
    self.colorHex = color.toHex() ?? "#0066FF"
    self.theme = theme
    self.userId = userId
  }

  // Custom coding keys to exclude computed property
  enum CodingKeys: String, CodingKey {
    case id, name, icon, colorHex, theme, userId
  }
}

// MARK: - Tab Folder Model
struct TabFolder: Identifiable, Equatable, Codable {
  let id: UUID
  var name: String
  var isExpanded: Bool
  var spaceId: UUID
  var sortOrder: Int
  var userId: String?  // User ID for data isolation

  init(
    id: UUID = UUID(),
    name: String = "New Folder",
    isExpanded: Bool = true,
    spaceId: UUID,
    sortOrder: Int = 0,
    userId: String? = nil
  ) {
    self.id = id
    self.name = name
    self.isExpanded = isExpanded
    self.spaceId = spaceId
    self.sortOrder = sortOrder
    self.userId = userId
  }
}

// MARK: - Bookmark Model
struct Bookmark: Identifiable, Codable {
  let id: UUID
  var url: URL
  var title: String
  var dateAdded: Date
  var folderId: UUID?
  var userId: String?  // User ID for data isolation

  init(
    id: UUID = UUID(),
    url: URL,
    title: String,
    dateAdded: Date = Date(),
    folderId: UUID? = nil,
    userId: String? = nil
  ) {
    self.id = id
    self.url = url
    self.title = title
    self.dateAdded = dateAdded
    self.folderId = folderId
    self.userId = userId
  }
}

// MARK: - History Entry Model
struct HistoryEntry: Identifiable, Codable {
  let id: UUID
  let url: URL
  let title: String
  let visitDate: Date
  var visitCount: Int
  var lastVisitDate: Date
  var typedCount: Int
  var userId: String?  // User ID for data isolation

  init(
    id: UUID = UUID(),
    url: URL,
    title: String,
    visitDate: Date = Date(),
    visitCount: Int = 1,
    lastVisitDate: Date? = nil,
    typedCount: Int = 0,
    userId: String? = nil
  ) {
    self.id = id
    self.url = url
    self.title = title
    self.visitDate = visitDate
    self.visitCount = visitCount
    self.lastVisitDate = lastVisitDate ?? visitDate
    self.typedCount = typedCount
    self.userId = userId
  }

  // Computed property for frecency score
  var frecencyScore: Double {
    FrecencyCalculator.calculateScore(
      visitCount: visitCount,
      lastVisitDate: lastVisitDate,
      typedCount: typedCount
    )
  }

  // Helper method to increment visit count
  mutating func recordVisit(typed: Bool = false) {
    visitCount += 1
    lastVisitDate = Date()
    if typed {
      typedCount += 1
    }
  }
}

// MARK: - Search Result for Spotlight
enum SearchResultType {
  case tab
  case bookmark
  case history
  case suggestion
  case website
  case command  // For Spotlight commands like "Summarize Page"
}

struct SearchResult: Identifiable {
  let id: UUID
  let type: SearchResultType
  let title: String
  let subtitle: String
  let url: URL?
  let tabId: UUID?
  let favicon: NSImage?
  let matchScore: Int?  // AI search match percentage (0-100)

  init(
    id: UUID = UUID(),
    type: SearchResultType,
    title: String,
    subtitle: String,
    url: URL? = nil,
    tabId: UUID? = nil,
    favicon: NSImage? = nil,
    matchScore: Int? = nil
  ) {
    self.id = id
    self.type = type
    self.title = title
    self.subtitle = subtitle
    self.url = url
    self.tabId = tabId
    self.favicon = favicon
    self.matchScore = matchScore
  }
}
