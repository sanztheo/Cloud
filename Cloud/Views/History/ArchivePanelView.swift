//
//  ArchivePanelView.swift
//  Cloud
//
//  Tabbed panel combining History and Downloads

import SwiftUI

struct ArchivePanelView: View {
  @ObservedObject var viewModel: BrowserViewModel
  @ObservedObject var downloadManager: DownloadManager
  let theme: SpaceTheme?
  @Binding var isPresented: Bool

  @State private var selectedTab: ArchiveTab = .history

  enum ArchiveTab: String, CaseIterable {
    case history = "Archived Tabs"
    case downloads = "Downloads"

    var icon: String {
      switch self {
      case .history: return "archivebox"
      case .downloads: return "arrow.down.circle"
      }
    }
  }

  // MARK: - Colors

  private var backgroundColor: Color {
    theme?.sidebarBackground ?? AppColors.defaultSidebarBackground
  }

  private var textColor: Color {
    guard let theme = theme else {
      return Color.black.opacity(0.8)
    }
    return theme.mode == .dark ? .white : Color.black.opacity(0.8)
  }

  private var secondaryTextColor: Color {
    guard let theme = theme else {
      return Color.black.opacity(0.5)
    }
    return theme.mode == .dark ? .white.opacity(0.6) : Color.black.opacity(0.5)
  }

  private var accentColor: Color {
    guard let theme = theme else {
      return Color.black.opacity(0.6)
    }
    return theme.mode == .dark ? .white.opacity(0.8) : Color.black.opacity(0.6)
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 0) {
      headerView
      tabSelectorView
      tabContentView
    }
    .background(backgroundColor)
  }

  // MARK: - Header

  private var headerView: some View {
    VStack(spacing: 0) {
      Spacer()
        .frame(height: 36)

      HStack(spacing: 12) {
        backButton
        Spacer()
        if selectedTab == .history {
          Text("Archived Tabs")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(textColor)
        } else {
          Text("Downloads")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(textColor)
        }
        Spacer()
        Spacer()
          .frame(width: 32)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }

  private var backButton: some View {
    Button(action: { isPresented = false }) {
      Image(systemName: "chevron.left")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(accentColor)
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Back")
  }

  // MARK: - Tab Selector

  private var tabSelectorView: some View {
    VStack(spacing: 0) {
      HStack(spacing: 16) {
        ForEach(ArchiveTab.allCases, id: \.self) { tab in
          VStack(spacing: 4) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } }) {
              HStack(spacing: 6) {
                Image(systemName: tab.icon)
                  .font(.system(size: 12, weight: .semibold))
                Text(tab.rawValue)
                  .font(.system(size: 13, weight: .medium))
              }
              .foregroundColor(selectedTab == tab ? textColor : secondaryTextColor)
            }
            .buttonStyle(.plain)

            if selectedTab == tab {
              Capsule()
                .fill(textColor)
                .frame(height: 2)
                .transition(.scale.combined(with: .opacity))
            }
          }
          Spacer()
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      Divider().foregroundColor(Color.black.opacity(0.15))
    }
  }

  // MARK: - Tab Content

  @ViewBuilder
  private var tabContentView: some View {
    if selectedTab == .history {
      HistoryPanelView(
        viewModel: viewModel,
        theme: theme,
        isPresented: $isPresented,
        showsHeader: false
      )
      .transition(.opacity)
    } else {
      DownloadsPanelView(
        downloadManager: downloadManager,
        theme: theme
      )
      .transition(.opacity)
    }
  }
}
