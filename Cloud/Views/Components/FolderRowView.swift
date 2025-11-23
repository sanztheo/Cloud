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
    @FocusState private var isTextFieldFocused: Bool

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
                    TextField("Folder name", text: $editedName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textColor)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            commitRename()
                        }
                        .onExitCommand {
                            cancelRename()
                        }
                        .onChange(of: isTextFieldFocused) { _, focused in
                            if !focused && isEditing {
                                // Lost focus - commit the rename
                                commitRename()
                            }
                        }
                } else {
                    Text(folder.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textColor)
                        .onTapGesture(count: 2) {
                            startEditing()
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
                    .fill(isEditing ? Color.black.opacity(0.15) : (isTargeted ? Color.accentColor.opacity(0.2) : (isHovered ? Color.black.opacity(0.1) : Color.clear)))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditing {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.toggleFolderExpanded(folder.id)
                    }
                }
            }
            .reliableHover { hovering in
                isHovered = hovering
            }
            .contextMenu {
                Button("Rename") {
                    startEditing()
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
                VStack(spacing: 4) {
                    ForEach(viewModel.tabsInFolder(folder.id)) { tab in
                        folderTabRow(tab)
                    }
                }
                .padding(.top, 2)
            }
        }
        .onAppear {
            // Auto-start editing if this folder was just created
            if viewModel.editingFolderId == folder.id {
                viewModel.editingFolderId = nil
                startEditing()
            }
        }
        .onChange(of: viewModel.editingFolderId) { _, newValue in
            // Handle case where editingFolderId is set after view appeared
            if newValue == folder.id {
                viewModel.editingFolderId = nil
                startEditing()
            }
        }
    }

    // MARK: - Rename Helpers

    private func startEditing() {
        editedName = folder.name
        isEditing = true
        // Delay focus to ensure TextField is rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isTextFieldFocused = true
        }
    }

    private func commitRename() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && trimmedName != folder.name {
            viewModel.renameFolder(folder.id, to: trimmedName)
        }
        isEditing = false
        isTextFieldFocused = false
    }

    private func cancelRename() {
        editedName = folder.name
        isEditing = false
        isTextFieldFocused = false
    }

    // MARK: - Tab Row

    private func folderTabRow(_ tab: BrowserTab) -> some View {
        HStack(spacing: 8) {
            // Favicon
            if let favicon = tab.favicon {
                Image(nsImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                    .foregroundColor(secondaryTextColor)
                    .frame(width: 16, height: 16)
            }

            // Title
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(textColor)

            Spacer()

            // Loading indicator or close button
            if tab.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            } else if hoveredTabId == tab.id {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(secondaryTextColor)
                    .frame(width: 16, height: 16)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Circle())
                    .onTapGesture {
                        viewModel.closeTab(tab.id)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    viewModel.activeTabId == tab.id
                        ? Color.black.opacity(0.2)
                        : (hoveredTabId == tab.id ? Color.black.opacity(0.1) : Color.clear)
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
