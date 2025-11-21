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
  @State private var isEditingAddress: Bool = false
  @FocusState private var isAddressFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      // Window controls (Arc style)
      windowControls
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)

      // Navigation controls (Arc style)
      navigationControls
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

      Divider()
        .padding(.horizontal, 12)

      // Address bar (Arc style)
      addressBar
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

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
        .id(viewModel.activeSpaceId)
        .transition(
          .asymmetric(
            insertion: .move(edge: viewModel.transitionDirection),
            removal: .move(edge: viewModel.transitionDirection == .leading ? .trailing : .leading)
          )
        )
      }

      Spacer()

      // Bottom actions
      bottomActions
    }
    .frame(width: viewModel.isSidebarCollapsed ? 0 : 240)
    .background(
      ZStack {
        AppColors.sidebarBackground(for: viewModel.activeSpace?.theme)
        SwipeGestureView(
          onSwipeLeft: {
            viewModel.switchToNextSpace()
          },
          onSwipeRight: {
            viewModel.switchToPreviousSpace()
          }
        )
      }
    )
    .clipped()
  }

  // MARK: - Window Controls (Arc Style)
  private var windowControls: some View {
    HStack(spacing: 8) {
      // Close button
      Circle()
        .fill(Color.red)
        .frame(width: 12, height: 12)
        .onTapGesture {
          NSApplication.shared.keyWindow?.close()
        }

      // Minimize button
      Circle()
        .fill(Color.yellow)
        .frame(width: 12, height: 12)
        .onTapGesture {
          NSApplication.shared.keyWindow?.miniaturize(nil)
        }

      // Maximize button
      Circle()
        .fill(Color.green)
        .frame(width: 12, height: 12)
        .onTapGesture {
          NSApplication.shared.keyWindow?.zoom(nil)
        }

      Spacer()
    }
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
        .sheet(isPresented: $isAddingSpace) {
          SpaceCreationSheet(
            isPresented: $isAddingSpace,
            viewModel: viewModel
          )
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
  }

  private func spaceButton(_ space: Space) -> some View {
    Button(action: { viewModel.selectSpace(space.id) }) {
      VStack(spacing: 4) {
        Text(space.icon)
          .font(.system(size: 18))
          .frame(width: 40, height: 40)
          .background(
            viewModel.activeSpaceId == space.id
              ? space.color.opacity(0.3) : Color(nsColor: .controlBackgroundColor)
          )
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(viewModel.activeSpaceId == space.id ? space.color : Color.clear, lineWidth: 2)
          )
      }
    }
    .buttonStyle(.plain)
    .help(space.name)
  }


  // MARK: - Pinned Tabs Section
  private func pinnedTabsSection(_ tabs: [BrowserTab]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("PINNED")
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.top, 4)

      LazyVGrid(
        columns: [
          GridItem(.flexible()),
          GridItem(.flexible()),
          GridItem(.flexible()),
        ], spacing: 8
      ) {
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
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
          Image(systemName: "globe")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
      }
      .frame(width: 44, height: 44)
      .background(
        viewModel.activeTabId == tab.id
          ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor)
      )
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
            .clipShape(RoundedRectangle(cornerRadius: 3))
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
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(
            viewModel.activeTabId == tab.id
              ? Color.accentColor.opacity(0.2)
              : (hoveredTabId == tab.id ? Color(nsColor: .controlBackgroundColor) : Color.clear))
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

  // MARK: - Navigation Controls (Arc Style)
  private var navigationControls: some View {
    HStack(spacing: 8) {
      // Back
      Button(action: { viewModel.goBack() }) {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(
            viewModel.activeTab?.canGoBack == true
              ? AppColors.navigationButtonActive : AppColors.navigationButtonDisabled
          )
          .frame(width: 32, height: 32)
          .background(AppColors.navigationButtonBackground)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .disabled(viewModel.activeTab?.canGoBack != true)
      .help("Go Back")

      // Forward
      Button(action: { viewModel.goForward() }) {
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(
            viewModel.activeTab?.canGoForward == true
              ? AppColors.navigationButtonActive : AppColors.navigationButtonDisabled
          )
          .frame(width: 32, height: 32)
          .background(AppColors.navigationButtonBackground)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .disabled(viewModel.activeTab?.canGoForward != true)
      .help("Go Forward")

      Spacer()

      // Reload
      Button(action: { viewModel.reload() }) {
        Image(systemName: viewModel.activeTab?.isLoading == true ? "xmark" : "arrow.clockwise")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(AppColors.navigationButtonActive)
          .frame(width: 32, height: 32)
          .background(AppColors.navigationButtonBackground)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .help(viewModel.activeTab?.isLoading == true ? "Stop" : "Reload")
    }
  }

  // MARK: - Address Bar (Arc Style)
  private var addressBar: some View {
    Button(action: { viewModel.openLocation() }) {
      HStack(spacing: 8) {
        // Security indicator
        if let url = viewModel.activeTab?.url {
          Image(systemName: url.scheme == "https" ? "lock.fill" : "globe")
            .font(.system(size: 10))
            .foregroundColor(url.scheme == "https" ? .green : .secondary)
        }

        // URL text (Domain only)
        Text(viewModel.activeTab?.url.host ?? "Search or enter URL")
          .font(.system(size: 12))
          .foregroundColor(AppColors.addressBarText)
          .lineLimit(1)
          .truncationMode(.tail)

        Spacer()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(AppColors.addressBarBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(AppColors.addressBarBorder, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Bottom Actions
  private var bottomActions: some View {
    VStack(spacing: 8) {
      Divider()

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(viewModel.spaces) { space in
            spaceButton(space)
          }

          // Add space button
          Button(action: { isAddingSpace = true }) {
            Image(systemName: "plus")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(.secondary)
              .frame(width: 40, height: 40)
              .background(Color(nsColor: .controlBackgroundColor))
              .clipShape(RoundedRectangle(cornerRadius: 10))
          }
          .buttonStyle(.plain)
          .sheet(isPresented: $isAddingSpace) {
            SpaceCreationSheet(
              isPresented: $isAddingSpace,
              viewModel: viewModel
            )
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
    }
  }
}
