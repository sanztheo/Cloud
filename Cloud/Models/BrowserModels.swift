//
//  BrowserModels.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import Foundation
import SwiftUI

// MARK: - Tab Model
struct BrowserTab: Identifiable, Equatable {
    let id: UUID
    var url: URL
    var title: String
    var favicon: NSImage?
    var isLoading: Bool
    var canGoBack: Bool
    var canGoForward: Bool
    var isPinned: Bool
    var spaceId: UUID

    init(
        id: UUID = UUID(),
        url: URL = URL(string: "https://www.google.com")!,
        title: String = "New Tab",
        favicon: NSImage? = nil,
        isLoading: Bool = false,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        isPinned: Bool = false,
        spaceId: UUID
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
    }

    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Space Model
struct Space: Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var color: Color

    init(
        id: UUID = UUID(),
        name: String = "Personal",
        icon: String = "person.fill",
        color: Color = .blue
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
    }
}

// MARK: - Bookmark Model
struct Bookmark: Identifiable, Codable {
    let id: UUID
    var url: URL
    var title: String
    var dateAdded: Date
    var folderId: UUID?

    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        dateAdded: Date = Date(),
        folderId: UUID? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.dateAdded = dateAdded
        self.folderId = folderId
    }
}

// MARK: - History Entry Model
struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let url: URL
    let title: String
    let visitDate: Date

    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        visitDate: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.visitDate = visitDate
    }
}

// MARK: - Search Result for Spotlight
enum SearchResultType {
    case tab
    case bookmark
    case history
    case suggestion
    case website
}

struct SearchResult: Identifiable {
    let id: UUID
    let type: SearchResultType
    let title: String
    let subtitle: String
    let url: URL?
    let tabId: UUID?

    init(
        id: UUID = UUID(),
        type: SearchResultType,
        title: String,
        subtitle: String,
        url: URL? = nil,
        tabId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.url = url
        self.tabId = tabId
    }
}
