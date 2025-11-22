//
//  BrowserView.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import SwiftUI

struct BrowserView: View {
  @StateObject private var viewModel = BrowserViewModel()
  @State private var showSettings = false
  @State private var floatingRotation: Double = 0
  @Namespace private var namespace

  // MARK: - Interpolated Background Color
  private var interpolatedBackgroundColor: Color {
    let currentColor = AppColors.background(for: viewModel.activeSpace?.theme)
    let dragOffset = viewModel.spaceSwipeDragOffset
    let sidebarWidth: CGFloat = 240

    guard abs(dragOffset) > 0 else { return currentColor }

    let progress = abs(dragOffset) / sidebarWidth

    // Get adjacent space based on drag direction
    guard let currentId = viewModel.activeSpaceId,
      let currentIndex = viewModel.spaces.firstIndex(where: { $0.id == currentId })
    else {
      return currentColor
    }

    let targetColor: Color
    if dragOffset > 0 {
      // Dragging right -> previous space
      guard currentIndex > 0 else { return currentColor }
      let prevSpace = viewModel.spaces[currentIndex - 1]
      targetColor = AppColors.background(for: prevSpace.theme)
    } else {
      // Dragging left -> next space
      guard currentIndex < viewModel.spaces.count - 1 else { return currentColor }
      let nextSpace = viewModel.spaces[currentIndex + 1]
      targetColor = AppColors.background(for: nextSpace.theme)
    }

    return currentColor.interpolate(to: targetColor, progress: progress)
  }

  var body: some View {
    ZStack {
      // Main content
      HStack(spacing: 0) {
        // Sidebar or Archive Panel
        if !viewModel.isSidebarCollapsed {
          if viewModel.isHistoryPanelVisible {
            // Archive panel (History + Downloads)
            ArchivePanelView(
              viewModel: viewModel,
              downloadManager: viewModel.downloadManager,
              theme: viewModel.activeSpace?.theme,
              isPresented: $viewModel.isHistoryPanelVisible
            )
            .frame(width: 400)
            .transition(.move(edge: .leading).combined(with: .opacity))
          } else {
            // Normal sidebar
            SidebarView(viewModel: viewModel)
              .frame(width: 240)
              .transition(.move(edge: .leading))
          }
        }

        // Main browser area - Arc style (floating with padding)
        webContent
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
          .padding(.top, 8)
          .padding(.bottom, 8)
          .padding(.trailing, 8)
          .padding(.leading, viewModel.isSidebarCollapsed ? 8 : 0)
      }

      // Spotlight overlay
      if viewModel.isSpotlightVisible {
        Color.black.opacity(0.3)
          .ignoresSafeArea()
          .onTapGesture {
            viewModel.isSpotlightVisible = false
          }

        SpotlightViewAppKit(viewModel: viewModel)
          .transition(.opacity.combined(with: .scale(scale: 0.95)))
      }
    }
    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.isSummarizing)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isSpotlightVisible)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isSidebarCollapsed)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isHistoryPanelVisible)
    .frame(minWidth: 800, minHeight: 600)
    .background(interpolatedBackgroundColor)
    .ignoresSafeArea(.all, edges: .top)
    .onAppear {
      setupKeyboardShortcuts()
    }
    .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
      viewModel.toggleSidebar()
    }
    .onReceive(NotificationCenter.default.publisher(for: .newTab)) { _ in
      viewModel.createNewTab()
    }
    .onReceive(NotificationCenter.default.publisher(for: .showSpotlight)) { _ in
      viewModel.toggleSpotlight()
    }
    .onReceive(NotificationCenter.default.publisher(for: .goBack)) { _ in
      viewModel.goBack()
    }
    .onReceive(NotificationCenter.default.publisher(for: .goForward)) { _ in
      viewModel.goForward()
    }
    .onReceive(NotificationCenter.default.publisher(for: .reload)) { _ in
      viewModel.reload()
    }
    .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
      showSettings = true
    }
    .sheet(isPresented: $showSettings) {
      SettingsWindow()
    }
  }

  // MARK: - Web Content
  @ViewBuilder
  private var webContent: some View {
    if let tabId = viewModel.activeTabId {
      GeometryReader { geometry in
        ScrollView(.vertical, showsIndicators: viewModel.isSummarizing) {
          VStack(spacing: 24) {
            // WebView - Use .id() to force SwiftUI to recreate view when tab changes
            WebViewRepresentable(tabId: tabId, viewModel: viewModel)
              .id(tabId)  // CRITICAL: Forces view recreation on tab change
              .frame(
                width: viewModel.isSummarizing ? 600 : geometry.size.width,
                height: viewModel.isSummarizing ? 400 : geometry.size.height
              )
              .clipShape(RoundedRectangle(cornerRadius: 12))
              .shadow(
                color: Color.black.opacity(viewModel.isSummarizing ? 0.2 : 0),
                radius: viewModel.isSummarizing ? 10 : 0,
                x: 0,
                y: viewModel.isSummarizing ? 4 : 0
              )
              .rotationEffect(.degrees(viewModel.isSummarizing ? floatingRotation : 0))
              .onChange(of: viewModel.isSummarizing) { _, isSummarizing in
                if isSummarizing {
                  startFloatingAnimation()
                } else {
                  withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    floatingRotation = 0
                  }
                }
              }
              .onChange(of: viewModel.isSummaryComplete) { _, isComplete in
                if isComplete {
                  withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    floatingRotation = 0
                  }
                }
              }

            // Summary View - Appears below
            if viewModel.isSummarizing {
              SummaryView(viewModel: viewModel)
                .frame(maxWidth: 800)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
          }
          .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
        }
        .scrollDisabled(!viewModel.isSummarizing)
      }
    } else {
      emptyState
    }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "cloud.fill")
        .font(.system(size: 64))
        .foregroundColor(.secondary.opacity(0.5))

      Text("Welcome to Cloud")
        .font(.title2)
        .foregroundColor(.secondary)

      Text("Press Cmd+T to open a new tab")
        .font(.body)
        .foregroundColor(.secondary.opacity(0.7))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(NSColor.windowBackgroundColor))
  }

  // MARK: - Floating Animation
  private func startFloatingAnimation() {
    guard !viewModel.isSummaryComplete else {
      floatingRotation = 0
      return
    }
    floatingRotation = -1
    withAnimation(
      Animation.easeInOut(duration: 2)
        .repeatForever(autoreverses: true)
    ) {
      floatingRotation = 1
    }
  }

  // MARK: - Keyboard Shortcuts
  private func setupKeyboardShortcuts() {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      // Cmd+T for Spotlight
      if event.modifierFlags.contains(.command) {
        switch event.charactersIgnoringModifiers {
        case "t":
          viewModel.toggleSpotlight()
          return nil
        case "w":
          if let tabId = viewModel.activeTabId {
            viewModel.closeTab(tabId)
          }
          return nil
        case "l":
          // Focus address bar
          return event
        case "1", "2", "3", "4", "5", "6", "7", "8", "9":
          // Switch tabs by number
          if let number = Int(event.charactersIgnoringModifiers ?? ""),
            let spaceId = viewModel.activeSpaceId
          {
            let spaceTabs = viewModel.tabsForSpace(spaceId)
            let index = number - 1
            if index < spaceTabs.count {
              viewModel.selectTab(spaceTabs[index].id)
            }
          }
          return nil
        default:
          break
        }
      }

      // Escape to close spotlight or restore page from summary
      if event.keyCode == 53 {
        if viewModel.isSpotlightVisible {
          viewModel.isSpotlightVisible = false
          return nil
        } else if viewModel.isSummarizing {
          // If summarizing, restore page (abort if still generating)
          viewModel.restorePage()
          return nil
        }
      }

      return event
    }
  }
}
