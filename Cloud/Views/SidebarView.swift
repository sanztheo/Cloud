//
//  SidebarView.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @State private var hoveredTabId: UUID?
    @State private var isAddingSpace: Bool = false
    @State private var newSpaceName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Space selector
            spaceSelector

            Divider()
                .padding(.horizontal, 12)

            // Tabs list
            ScrollView {
                LazyVStack(spacing: 4) {
                    // Pinned tabs
                    if let spaceId = viewModel.activeSpaceId {
                        let pinnedTabs = viewModel.pinnedTabsForSpace(spaceId)
                        if !pinnedTabs.isEmpty {
                            pinnedTabsSection(pinnedTabs)
                        }

                        // Regular tabs
                        let unpinnedTabs = viewModel.unpinnedTabsForSpace(spaceId)
                        ForEach(unpinnedTabs) { tab in
                            tabRow(tab)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }

            Spacer()

            // Bottom actions
            bottomActions
        }
        .frame(width: viewModel.isSidebarCollapsed ? 0 : 240)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipped()
    }

    // MARK: - Space Selector
    private var spaceSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.spaces) { space in
                    spaceButton(space)
                }

                // Add space button
                Button(action: { isAddingSpace = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isAddingSpace) {
                    addSpacePopover
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func spaceButton(_ space: Space) -> some View {
        Button(action: { viewModel.selectSpace(space.id) }) {
            VStack(spacing: 4) {
                Image(systemName: space.icon)
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.activeSpaceId == space.id ? .white : space.color)
                    .frame(width: 32, height: 32)
                    .background(viewModel.activeSpaceId == space.id ? space.color : Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .buttonStyle(.plain)
        .help(space.name)
    }

    private var addSpacePopover: some View {
        VStack(spacing: 12) {
            Text("New Space")
                .font(.headline)

            TextField("Space name", text: $newSpaceName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    isAddingSpace = false
                    newSpaceName = ""
                }

                Button("Create") {
                    if !newSpaceName.isEmpty {
                        viewModel.createNewSpace(
                            name: newSpaceName,
                            icon: "folder.fill",
                            color: .purple
                        )
                        newSpaceName = ""
                        isAddingSpace = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 200)
    }

    // MARK: - Pinned Tabs Section
    private func pinnedTabsSection(_ tabs: [BrowserTab]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PINNED")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 4)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(tabs) { tab in
                    pinnedTabItem(tab)
                }
            }
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 4)
        }
    }

    private func pinnedTabItem(_ tab: BrowserTab) -> some View {
        Button(action: { viewModel.selectTab(tab.id) }) {
            VStack(spacing: 4) {
                if let favicon = tab.favicon {
                    Image(nsImage: favicon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .background(viewModel.activeTabId == tab.id ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.activeTabId == tab.id ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .contextMenu {
            tabContextMenu(tab)
        }
    }

    // MARK: - Tab Row
    private func tabRow(_ tab: BrowserTab) -> some View {
        Button(action: { viewModel.selectTab(tab.id) }) {
            HStack(spacing: 8) {
                // Favicon
                if let favicon = tab.favicon {
                    Image(nsImage: favicon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                }

                // Title
                Text(tab.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)

                Spacer()

                // Loading indicator or close button
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else if hoveredTabId == tab.id {
                    Button(action: { viewModel.closeTab(tab.id) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewModel.activeTabId == tab.id ? Color.accentColor.opacity(0.2) : (hoveredTabId == tab.id ? Color(nsColor: .controlBackgroundColor) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredTabId = isHovering ? tab.id : nil
        }
        .contextMenu {
            tabContextMenu(tab)
        }
    }

    // MARK: - Tab Context Menu
    private func tabContextMenu(_ tab: BrowserTab) -> some View {
        Group {
            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
                viewModel.pinTab(tab.id)
            }

            Divider()

            Button("Duplicate Tab") {
                viewModel.createNewTab(url: tab.url)
            }

            Menu("Move to Space") {
                ForEach(viewModel.spaces) { space in
                    Button(space.name) {
                        viewModel.moveTab(tab.id, toSpace: space.id)
                    }
                }
            }

            Divider()

            Button("Close Tab") {
                viewModel.closeTab(tab.id)
            }

            Button("Close Other Tabs") {
                let otherTabs = viewModel.tabs.filter { $0.id != tab.id && $0.spaceId == tab.spaceId }
                for otherTab in otherTabs {
                    viewModel.closeTab(otherTab.id)
                }
            }
        }
    }

    // MARK: - Bottom Actions
    private var bottomActions: some View {
        VStack(spacing: 8) {
            Divider()

            HStack(spacing: 12) {
                // New tab button
                Button(action: { viewModel.createNewTab() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                        Text("New Tab")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("t", modifiers: .command)

                Spacer()

                // Settings button
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}
