//
//  BrowserViewModel+Spaces.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Extension handling Space creation, selection, and management.
//

import Foundation
import SwiftUI

// MARK: - Space Management
extension BrowserViewModel {

  func createNewSpace(name: String, icon: String, color: Color, theme: SpaceTheme? = nil) {
    let newSpace = Space(name: name, icon: icon, color: color, theme: theme)
    spaces.append(newSpace)
    saveSpaces()
  }

  func updateSpace(id: UUID, name: String, icon: String, color: Color, theme: SpaceTheme?) {
    if let index = spaces.firstIndex(where: { $0.id == id }) {
      spaces[index].name = name
      spaces[index].icon = icon
      spaces[index].color = color
      spaces[index].theme = theme
      saveSpaces()
    }
  }

  func selectSpace(_ spaceId: UUID) {
    activeSpaceId = spaceId

    // Sync isLoading state with actual WebView state for tabs in this space
    // This fixes the bug where tabs show loading spinner after app restart
    // because the navigationDelegate wasn't assigned when WebViews were created
    syncLoadingStateForSpace(spaceId)

    // Select first tab in space (0 tabs = Welcome to Cloud)
    if let firstTab = tabs.first(where: { $0.spaceId == spaceId }) {
      activeTabId = firstTab.id
    } else {
      activeTabId = nil
    }
  }

  /// Synchronizes the isLoading state of tabs with the actual WebView loading state
  func syncLoadingStateForSpace(_ spaceId: UUID) {
    for i in tabs.indices where tabs[i].spaceId == spaceId {
      let tabId = tabs[i].id
      if let webView = webViews[tabId] {
        // Sync with actual WebView state
        tabs[i].isLoading = webView.isLoading
      }
    }
  }

  func deleteSpace(_ spaceId: UUID) {
    guard spaces.count > 1 else { return }

    // Move tabs to first space
    let firstSpaceId = spaces.first(where: { $0.id != spaceId })!.id
    for i in tabs.indices where tabs[i].spaceId == spaceId {
      tabs[i].spaceId = firstSpaceId
    }

    spaces.removeAll { $0.id == spaceId }

    if activeSpaceId == spaceId {
      activeSpaceId = firstSpaceId
    }
  }

  func switchToNextSpace(animated: Bool = true) {
    guard let currentId = activeSpaceId,
      let currentIndex = spaces.firstIndex(where: { $0.id == currentId })
    else { return }

    transitionDirection = .trailing
    let nextIndex = (currentIndex + 1) % spaces.count
    if animated {
      withAnimation(.easeInOut(duration: 0.25)) {
        selectSpace(spaces[nextIndex].id)
      }
    } else {
      selectSpace(spaces[nextIndex].id)
    }
  }

  func switchToPreviousSpace(animated: Bool = true) {
    guard let currentId = activeSpaceId,
      let currentIndex = spaces.firstIndex(where: { $0.id == currentId })
    else { return }

    transitionDirection = .leading
    let prevIndex = (currentIndex - 1 + spaces.count) % spaces.count
    if animated {
      withAnimation(.easeInOut(duration: 0.25)) {
        selectSpace(spaces[prevIndex].id)
      }
    } else {
      selectSpace(spaces[prevIndex].id)
    }
  }
}
