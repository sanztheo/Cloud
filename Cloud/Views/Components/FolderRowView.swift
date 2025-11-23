//
//  FolderRowView.swift
//  Cloud
//

import SwiftUI

struct FolderRowView: View {
    @ObservedObject var viewModel: BrowserViewModel
    let folder: TabFolder
    let textColor: Color
    let secondaryTextColor: Color

    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editedName: String = ""
    @State private var isTargeted: Bool = false
    @State private var hoveredTabId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Folder header
            HStack(spacing: 6) {
                // Expand/collapse chevron
                Image(systemName: folder.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(secondaryTextColor)
                    .frame(width: 12)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.toggleFolderExpanded(folder.id)
                        }
                    }

                // Folder icon
                Image(systemName: folder.isExpanded ? "folder.fill" : "folder")
                    .font(.system(size: 12))
                    .foregroundColor(secondaryTextColor)

                // Folder name (editable)
                if isEditing {
                    TextField("Folder name", text: $editedName, onCommit: {
                        if !editedName.isEmpty {
                            viewModel.renameFolder(folder.id, to: editedName)
                        }
                        isEditing = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textColor)
                } else {
                    Text(folder.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textColor)
                        .onTapGesture(count: 2) {
                            editedName = folder.name
                            isEditing = true
                        }
                }

                Spacer()

                // Tab count
                Text("\(viewModel.tabsInFolder(folder.id).count)")
                    .font(.system(size: 10))
                    .foregroundColor(secondaryTextColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isTargeted ? Color.accentColor.opacity(0.2) : (isHovered ? Color.black.opacity(0.1) : Color.clear))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleFolderExpanded(folder.id)
                }
            }
            .reliableHover { hovering in
                isHovered = hovering
            }
            .contextMenu {
                Button("Rename") {
                    editedName = folder.name
                    isEditing = true
                }

                Divider()

                Button(folder.isExpanded ? "Collapse" : "Expand") {
                    viewModel.toggleFolderExpanded(folder.id)
                }

                Divider()

                Button("Delete Folder", role: .destructive) {
                    viewModel.deleteFolder(folder.id)
                }
            }
            .dropDestination(for: String.self) { items, _ in
                guard let tabIdString = items.first,
                      let tabId = UUID(uuidString: tabIdString) else { return false }
                viewModel.moveTabToFolder(tabId, folderId: folder.id)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }

            // Folder contents (tabs)
            if folder.isExpanded {
                VStack(spacing: 2) {
                    ForEach(viewModel.tabsInFolder(folder.id)) { tab in
                        folderTabRow(tab)
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 2)
            }
        }
    }

    private func folderTabRow(_ tab: BrowserTab) -> some View {
        HStack(spacing: 8) {
            // Favicon
            if let favicon = tab.favicon {
                Image(nsImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 10))
                    .foregroundColor(secondaryTextColor)
                    .frame(width: 14, height: 14)
            }

            // Title
            Text(tab.title)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(textColor)

            Spacer()

            // Close button on hover
            if hoveredTabId == tab.id {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(secondaryTextColor)
                    .frame(width: 14, height: 14)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Circle())
                    .onTapGesture {
                        viewModel.closeTab(tab.id)
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    viewModel.activeTabId == tab.id
                        ? Color.black.opacity(0.15)
                        : (hoveredTabId == tab.id ? Color.black.opacity(0.08) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectTab(tab.id)
        }
        .reliableHover { hovering in
            hoveredTabId = hovering ? tab.id : nil
        }
        .draggable(tab.id.uuidString)
        .contextMenu {
            Button("Remove from Folder") {
                viewModel.moveTabToFolder(tab.id, folderId: nil)
            }

            Divider()

            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
                viewModel.pinTab(tab.id)
            }

            Divider()

            Button("Close Tab") {
                viewModel.closeTab(tab.id)
            }
        }
    }
}
