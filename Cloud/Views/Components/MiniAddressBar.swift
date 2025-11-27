//
//  MiniAddressBar.swift
//  Cloud
//
//  Arc-style mini address bar popup for quick navigation.
//

import SwiftUI

struct MiniAddressBar: View {
  @ObservedObject var viewModel: BrowserViewModel
  @Binding var isPresented: Bool
  @State private var searchText: String = ""
  @State private var hoveredResultId: UUID?
  @FocusState private var isSearchFocused: Bool

  private var textColor: Color {
    guard let theme = viewModel.activeSpace?.theme else {
      return .white
    }
    return theme.mode == .dark ? .white : Color.black.opacity(0.9)
  }

  private var secondaryTextColor: Color {
    guard let theme = viewModel.activeSpace?.theme else {
      return .white.opacity(0.6)
    }
    return theme.mode == .dark ? .white.opacity(0.6) : Color.black.opacity(0.5)
  }

  private var backgroundColor: Color {
    guard let theme = viewModel.activeSpace?.theme else {
      return Color(nsColor: NSColor.windowBackgroundColor).opacity(0.95)
    }
    return theme.mode == .dark
      ? Color.black.opacity(0.85)
      : Color.white.opacity(0.95)
  }

  // Quick results: current space tabs + recent history (no AI features)
  private var quickResults: [QuickResult] {
    var results: [QuickResult] = []
    let query = searchText.lowercased()

    // Current space tabs
    let spaceTabs = viewModel.tabs.filter { $0.spaceId == viewModel.activeSpaceId }

    if query.isEmpty {
      // Show all tabs when empty
      for tab in spaceTabs.prefix(6) {
        results.append(QuickResult(
          id: tab.id,
          title: tab.title,
          subtitle: tab.url.host ?? tab.url.absoluteString,
          favicon: tab.favicon,
          url: tab.url,
          isTab: true
        ))
      }
    } else {
      // Filter tabs by query
      for tab in spaceTabs where tab.title.localizedCaseInsensitiveContains(query) || tab.url.absoluteString.localizedCaseInsensitiveContains(query) {
        results.append(QuickResult(
          id: tab.id,
          title: tab.title,
          subtitle: tab.url.host ?? tab.url.absoluteString,
          favicon: tab.favicon,
          url: tab.url,
          isTab: true
        ))
      }

      // Add matching history
      for entry in viewModel.history.prefix(20) where entry.title.localizedCaseInsensitiveContains(query) || entry.url.absoluteString.localizedCaseInsensitiveContains(query) {
        // Avoid duplicates
        if !results.contains(where: { $0.url.host == entry.url.host && $0.title == entry.title }) {
          results.append(QuickResult(
            id: UUID(),
            title: entry.title,
            subtitle: entry.url.host ?? entry.url.absoluteString,
            favicon: nil,
            url: entry.url,
            isTab: false
          ))
        }
      }
    }

    return Array(results.prefix(6))
  }

  var body: some View {
    VStack(spacing: 0) {
      // Search field with current URL
      HStack(spacing: 8) {
        // Favicon or search icon
        if let favicon = viewModel.activeTab?.favicon, searchText.isEmpty {
          Image(nsImage: favicon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 12))
            .foregroundColor(secondaryTextColor)
        }

        TextField("Search or enter URL...", text: $searchText)
          .textFieldStyle(.plain)
          .font(.system(size: 13))
          .foregroundColor(textColor)
          .focused($isSearchFocused)
          .onSubmit {
            handleSubmit()
          }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)

      // Results list
      if !quickResults.isEmpty {
        Divider()
          .padding(.horizontal, 8)

        ScrollView(.vertical, showsIndicators: false) {
          VStack(spacing: 2) {
            ForEach(quickResults) { result in
              resultRow(result)
            }
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 6)
        }
        .frame(maxHeight: 280)
      }
    }
    .background(backgroundColor)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    .frame(width: 320)
    .onAppear {
      // Pre-fill with current URL
      if let url = viewModel.activeTab?.url {
        searchText = url.absoluteString
      }
      isSearchFocused = true

      // Select all text after a tiny delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NSApp.keyWindow?.fieldEditor(true, for: nil)?.selectAll(nil)
      }
    }
    .onExitCommand {
      isPresented = false
    }
  }

  @ViewBuilder
  private func resultRow(_ result: QuickResult) -> some View {
    Button(action: {
      selectResult(result)
    }) {
      HStack(spacing: 10) {
        // Favicon
        if let favicon = result.favicon {
          Image(nsImage: favicon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
          Image(systemName: result.isTab ? "square.on.square" : "clock")
            .font(.system(size: 12))
            .foregroundColor(secondaryTextColor)
            .frame(width: 20, height: 20)
        }

        // Title and subtitle
        VStack(alignment: .leading, spacing: 2) {
          Text(result.title)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(textColor)
            .lineLimit(1)

          Text(result.subtitle)
            .font(.system(size: 10))
            .foregroundColor(secondaryTextColor)
            .lineLimit(1)
        }

        Spacer()

        // Badge for tabs
        if result.isTab {
          Text("Tab")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(secondaryTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(hoveredResultId == result.id ? Color.white.opacity(0.1) : Color.clear)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      hoveredResultId = hovering ? result.id : nil
    }
  }

  private func handleSubmit() {
    let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }

    // Use navigateToAddress which handles URL detection and search
    viewModel.navigateToAddress(text)
    isPresented = false
  }

  private func selectResult(_ result: QuickResult) {
    if result.isTab {
      // Switch to existing tab
      viewModel.selectTab(result.id)
    } else {
      // Navigate to URL in current tab
      viewModel.navigateToAddress(result.url.absoluteString)
    }
    isPresented = false
  }
}

// MARK: - Quick Result Model
struct QuickResult: Identifiable {
  let id: UUID
  let title: String
  let subtitle: String
  let favicon: NSImage?
  let url: URL
  let isTab: Bool
}
