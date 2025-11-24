//
//  BrowserViewModel+Folders.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Extension handling tab folder creation and management.
//

import Foundation

// MARK: - Folder Management
extension BrowserViewModel {

  func createFolder(in spaceId: UUID, name: String = "New Folder", startEditing: Bool = true) -> TabFolder {
    let currentUserId = SupabaseService.shared.currentUserId
    let maxOrder = folders.filter { $0.spaceId == spaceId }.map { $0.sortOrder }.max() ?? -1
    let folder = TabFolder(name: name, spaceId: spaceId, sortOrder: maxOrder + 1, userId: currentUserId)
    folders.append(folder)
    saveFolders()
    // Trigger edit mode for the new folder
    if startEditing {
      editingFolderId = folder.id
    }
    return folder
  }

  func deleteFolder(_ folderId: UUID) {
    // Move all tabs in this folder back to ungrouped
    for i in tabs.indices where tabs[i].folderId == folderId {
      tabs[i].folderId = nil
    }
    folders.removeAll { $0.id == folderId }
    saveFolders()
    saveTabs()
  }

  func renameFolder(_ folderId: UUID, to name: String) {
    if let index = folders.firstIndex(where: { $0.id == folderId }) {
      folders[index].name = name
      saveFolders()
    }
  }

  func toggleFolderExpanded(_ folderId: UUID) {
    if let index = folders.firstIndex(where: { $0.id == folderId }) {
      folders[index].isExpanded.toggle()
      saveFolders()
    }
  }

  func moveTabToFolder(_ tabId: UUID, folderId: UUID?) {
    if let index = tabs.firstIndex(where: { $0.id == tabId }) {
      tabs[index].folderId = folderId
      // Update sort order to be last in folder
      if let folderId = folderId {
        let maxOrder = tabs.filter { $0.folderId == folderId }.map { $0.sortOrder }.max() ?? -1
        tabs[index].sortOrder = maxOrder + 1
      }
      saveTabs()
    }
  }

  func foldersForSpace(_ spaceId: UUID) -> [TabFolder] {
    folders.filter { $0.spaceId == spaceId }.sorted { $0.sortOrder < $1.sortOrder }
  }

  func tabsInFolder(_ folderId: UUID) -> [BrowserTab] {
    tabs.filter { $0.folderId == folderId && !$0.isPinned }.sorted { $0.sortOrder < $1.sortOrder }
  }

  func ungroupedTabsForSpace(_ spaceId: UUID) -> [BrowserTab] {
    tabs.filter { $0.spaceId == spaceId && $0.folderId == nil && !$0.isPinned }.sorted { $0.sortOrder < $1.sortOrder }
  }
}
