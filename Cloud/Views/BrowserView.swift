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

  var body: some View {
    ZStack {
      // Main content
      HStack(spacing: 0) {
        // Sidebar
        if !viewModel.isSidebarCollapsed {
          SidebarView(viewModel: viewModel)
            .transition(.move(edge: .leading))
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
    .frame(minWidth: 800, minHeight: 600)
    .background(AppColors.background(for: viewModel.activeSpace?.theme))
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
    if viewModel.isSummarizing {
      // Summary Mode: Shrink WebView and show summary below
      VStack(spacing: 24) {
        // Shrunk WebView (centered, 600x400)
        if let tabId = viewModel.activeTabId {
          WebViewRepresentable(tabId: tabId, viewModel: viewModel)
            .frame(width: 600, height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
            .id(tabId)
        }

        // Summary View below
        SummaryView(viewModel: viewModel)
          .frame(maxWidth: 800)
          .transition(.opacity.combined(with: .move(edge: .bottom)))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.vertical, 40)
      .transition(.scale(scale: 0.95).combined(with: .opacity))
    } else {
      // Normal Mode: Full WebView
      if let tabId = viewModel.activeTabId {
        WebViewRepresentable(tabId: tabId, viewModel: viewModel)
          .id(tabId)  // Force recreation when tab changes
      } else {
        emptyState
      }
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

      // Escape to close spotlight
      if event.keyCode == 53 && viewModel.isSpotlightVisible {
        viewModel.isSpotlightVisible = false
        return nil
      }

      return event
    }
  }
}
