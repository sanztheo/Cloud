//
//  SidebarView.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import SwiftUI

// MARK: - Title Bar Drag Area (for window dragging and double-click zoom)
struct TitleBarDragArea: NSViewRepresentable {
  func makeNSView(context: Context) -> TitleBarView {
    let view = TitleBarView()
    return view
  }

  func updateNSView(_ nsView: TitleBarView, context: Context) {}
}

class TitleBarView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    // Register for double-click
    let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
    clickGesture.numberOfClicksRequired = 2
    self.addGestureRecognizer(clickGesture)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var mouseDownCanMoveWindow: Bool {
    return true
  }

  @objc private func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
    guard let window = self.window else { return }

    // Check user preference for double-click action
    let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"

    if action == "Minimize" {
      window.performMiniaturize(nil)
    } else {
      window.performZoom(nil)
    }
  }
}

struct SidebarView: View {
  @ObservedObject var viewModel: BrowserViewModel
  @State private var hoveredTabId: UUID?
  @State private var hoveredSpaceId: UUID?
  @State private var isHoveringAddSpace: Bool = false
  @State private var isHoveringHistory: Bool = false
  @State private var isAddingSpace: Bool = false
  @State private var isEditingSpace: Space?
  @State private var isEditingAddress: Bool = false
  @FocusState private var isAddressFocused: Bool

  // Couleur du texte selon le mode du thème
  private var textColor: Color {
    guard let theme = viewModel.activeSpace?.theme else {
      return Color.black.opacity(0.8) // Default = auto = light text
    }
    return theme.mode == .dark ? .white : Color.black.opacity(0.8)
  }

  private var secondaryTextColor: Color {
    guard let theme = viewModel.activeSpace?.theme else {
      return Color.black.opacity(0.5) // Default = auto = light secondary
    }
    return theme.mode == .dark ? .white.opacity(0.6) : Color.black.opacity(0.5)
  }

  // Couleurs des boutons de navigation selon le mode
  private var navigationButtonActive: Color {
    guard let theme = viewModel.activeSpace?.theme else {
      return Color.black.opacity(0.6) // Default = auto = light buttons
    }
    return theme.mode == .dark ? .white.opacity(0.6) : Color.black.opacity(0.6)
  }

  private var navigationButtonDisabled: Color {
    guard let theme = viewModel.activeSpace?.theme else {
      return Color.black.opacity(0.4) // Default = auto = light buttons
    }
    return theme.mode == .dark ? .white.opacity(0.3) : Color.black.opacity(0.4)
  }

  // MARK: - Adjacent Spaces
  private var previousSpaceId: UUID? {
    guard let currentId = viewModel.activeSpaceId,
          let currentIndex = viewModel.spaces.firstIndex(where: { $0.id == currentId }),
          currentIndex > 0 else { return nil }
    return viewModel.spaces[currentIndex - 1].id
  }

  private var nextSpaceId: UUID? {
    guard let currentId = viewModel.activeSpaceId,
          let currentIndex = viewModel.spaces.firstIndex(where: { $0.id == currentId }),
          currentIndex < viewModel.spaces.count - 1 else { return nil }
    return viewModel.spaces[currentIndex + 1].id
  }

  private func calculateTabsOffset(containerWidth: CGFloat) -> CGFloat {
    // Base offset to center on current space
    let baseOffset: CGFloat = previousSpaceId != nil ? -containerWidth : 0
    // Add drag offset
    return baseOffset + viewModel.spaceSwipeDragOffset
  }

  // MARK: - Interpolated Background Color
  private var interpolatedBackgroundColor: Color {
    let currentColor = AppColors.sidebarBackground(for: viewModel.activeSpace?.theme)
    let dragOffset = viewModel.spaceSwipeDragOffset
    let sidebarWidth: CGFloat = 240

    // No drag, return current color
    guard abs(dragOffset) > 0 else { return currentColor }

    // Calculate progress (0 to 1)
    let progress = abs(dragOffset) / sidebarWidth

    // Determine target color based on drag direction
    let targetColor: Color
    if dragOffset > 0 {
      // Dragging right -> going to previous space
      if let prevId = previousSpaceId,
         let prevSpace = viewModel.spaces.first(where: { $0.id == prevId }) {
        targetColor = AppColors.sidebarBackground(for: prevSpace.theme)
      } else {
        return currentColor
      }
    } else {
      // Dragging left -> going to next space
      if let nextId = nextSpaceId,
         let nextSpace = viewModel.spaces.first(where: { $0.id == nextId }) {
        targetColor = AppColors.sidebarBackground(for: nextSpace.theme)
      } else {
        return currentColor
      }
    }

    return currentColor.interpolate(to: targetColor, progress: progress)
  }

  @ViewBuilder
  private func tabsListContent(for spaceId: UUID) -> some View {
    ScrollView {
      LazyVStack(spacing: 4) {
        let pinnedTabs = viewModel.pinnedTabsForSpace(spaceId)
        if !pinnedTabs.isEmpty {
          pinnedTabsSection(pinnedTabs)
        }

        let unpinnedTabs = viewModel.unpinnedTabsForSpace(spaceId)
        ForEach(unpinnedTabs) { tab in
          tabRow(tab)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 8)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Draggable title bar area with double-click to zoom
      TitleBarDragArea()
        .frame(height: 28)

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

      // Tabs list with swipe gesture - shows adjacent spaces during swipe
      GeometryReader { geometry in
        HStack(spacing: 0) {
          // Previous space tabs (left)
          if let prevSpaceId = previousSpaceId {
            tabsListContent(for: prevSpaceId)
              .frame(width: geometry.size.width)
          }

          // Current space tabs (center)
          if let currentSpaceId = viewModel.activeSpaceId {
            tabsListContent(for: currentSpaceId)
              .frame(width: geometry.size.width)
          }

          // Next space tabs (right)
          if let nextSpaceId = nextSpaceId {
            tabsListContent(for: nextSpaceId)
              .frame(width: geometry.size.width)
          }
        }
        .offset(x: calculateTabsOffset(containerWidth: geometry.size.width))
      }
      .clipped()

      Spacer()

      // Bottom actions
      bottomActions
    }
    .frame(width: viewModel.isSidebarCollapsed ? 0 : 240)
    .background(
      ZStack {
        interpolatedBackgroundColor
        SwipeGestureView(
          onSwipeLeft: {
            viewModel.switchToNextSpace(animated: false)
          },
          onSwipeRight: {
            viewModel.switchToPreviousSpace(animated: false)
          },
          onDragOffsetChanged: { offset in
            viewModel.spaceSwipeDragOffset = offset
          },
          onDragEnded: { _, didSwipe in
            if didSwipe {
              // Swipe réussi: reset immédiat sans animation
              viewModel.spaceSwipeDragOffset = 0
            } else {
              // Swipe annulé: animation de snap-back
              withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewModel.spaceSwipeDragOffset = 0
              }
            }
          },
          sidebarWidth: 240
        )
      }
    )
    .clipped()
    .sheet(item: $isEditingSpace) { space in
      SpaceEditSheet(
        space: space,
        isPresented: Binding(
          get: { isEditingSpace != nil },
          set: { if !$0 { isEditingSpace = nil } }
        ),
        viewModel: viewModel
      )
    }
  }

  // MARK: - Space Button
  private func spaceButton(_ space: Space) -> some View {
    Button(action: { viewModel.selectSpace(space.id) }) {
      Text(space.icon)
        .font(.system(size: 14))
        .frame(width: 28, height: 28)
        .background(
          viewModel.activeSpaceId == space.id
            ? space.color.opacity(0.3)
            : (hoveredSpaceId == space.id ? Color.black.opacity(0.2) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(
              viewModel.activeSpaceId == space.id ? Color.black.opacity(0.3) : Color.clear,
              lineWidth: 1.5
            )
        )
    }
    .buttonStyle(.plain)
    .onHover { isHovering in
      hoveredSpaceId = isHovering ? space.id : nil
    }
    .help(space.name)
    .contextMenu {
      Button("Settings") {
        isEditingSpace = space
      }

      Divider()

      Button("Delete Space", role: .destructive) {
        viewModel.deleteSpace(space.id)
      }
    }
  }


  // MARK: - Pinned Tabs Section
  private func pinnedTabsSection(_ tabs: [BrowserTab]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("PINNED")
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(secondaryTextColor)
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
            .foregroundColor(secondaryTextColor)
        }
      }
      .frame(width: 44, height: 44)
      .background(
        viewModel.activeTabId == tab.id
          ? Color.black.opacity(0.2) : Color.black.opacity(0.1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(viewModel.activeTabId == tab.id ? Color.black.opacity(0.3) : Color.clear, lineWidth: 2)
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
          Button(action: { viewModel.closeTab(tab.id) }) {
            Image(systemName: "xmark")
              .font(.system(size: 8, weight: .bold))
              .foregroundColor(secondaryTextColor)
              .frame(width: 16, height: 16)
              .background(Color.black.opacity(0.2))
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
              ? Color.black.opacity(0.2)
              : (hoveredTabId == tab.id ? Color.black.opacity(0.1) : Color.clear))
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
              ? navigationButtonActive : navigationButtonDisabled
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
              ? navigationButtonActive : navigationButtonDisabled
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
          .foregroundColor(navigationButtonActive)
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
        // Security indicator or search icon
        if let url = viewModel.activeTab?.url {
          Image(systemName: url.scheme == "https" ? "lock.fill" : "globe")
            .font(.system(size: 10))
            .foregroundColor(url.scheme == "https" ? .green : secondaryTextColor)
        } else {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 10))
            .foregroundColor(secondaryTextColor)
        }

        // URL text (Domain only) or placeholder
        Text(viewModel.activeTab?.url.host ?? "Search or Enter URL...")
          .font(.system(size: 12))
          .foregroundColor(secondaryTextColor)
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

      HStack(spacing: 6) {
        Spacer()
          // History button
          Button(action: { viewModel.toggleHistoryPanel() }) {
            Image(systemName: "clock.arrow.circlepath")
              .font(.system(size: 12))
              .foregroundColor(textColor)
              .frame(width: 28, height: 28)
              .background(isHoveringHistory ? Color.black.opacity(0.2) : Color.clear)
              .clipShape(RoundedRectangle(cornerRadius: 6))
          }
          .buttonStyle(.plain)
          .onHover { hovering in isHoveringHistory = hovering }
          .help("History")

          Divider()
            .frame(height: 20)

          ForEach(viewModel.spaces) { space in
            spaceButton(space)
          }

          // Add space button
          Button(action: { isAddingSpace = true }) {
            Image(systemName: "plus")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(secondaryTextColor)
              .frame(width: 28, height: 28)
              .background(isHoveringAddSpace ? Color.black.opacity(0.2) : Color.clear)
              .clipShape(RoundedRectangle(cornerRadius: 6))
          }
          .buttonStyle(.plain)
          .onHover { isHovering in
            isHoveringAddSpace = isHovering
          }
          .sheet(isPresented: $isAddingSpace) {
            SpaceCreationSheet(
              isPresented: $isAddingSpace,
              viewModel: viewModel
            )
          }
        Spacer()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
    }
  }
}
