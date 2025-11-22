//
//  HistoryPanelView.swift
//  Cloud
//
//  History panel view with search and date-grouped display
//

import SwiftUI

struct HistoryPanelView: View {
  @ObservedObject var viewModel: BrowserViewModel
  let theme: SpaceTheme?
  @Binding var isPresented: Bool
  @State private var searchText = ""
  @State private var selectedFilter: HistoryFilter = .all

  enum HistoryFilter: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case week = "This Week"
    case month = "This Month"

    var label: String { rawValue }
  }

  // MARK: - Colors

  private var backgroundColor: Color {
    theme?.sidebarBackground ?? AppColors.sidebarBackground
  }

  private var textColor: Color {
    theme?.mode == .dark ? .white : Color.black.opacity(0.8)
  }

  private var secondaryTextColor: Color {
    theme?.mode == .dark ? .white.opacity(0.6) : Color.black.opacity(0.5)
  }

  private var accentColor: Color {
    theme?.baseColor ?? Color.blue
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 0) {
      headerView
      searchFieldView
      historyListView
    }
    .background(backgroundColor)
  }

  // MARK: - Header

  private var headerView: some View {
    VStack(spacing: 0) {
      // Spacer pour éviter les boutons Apple (close, minimize, maximize)
      Spacer()
        .frame(height: 36)

      HStack(spacing: 12) {
        backButton
        Spacer()
        Text("History")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(textColor)
        Spacer()
        filterMenu
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

      Divider().foregroundColor(Color.black.opacity(0.15))
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

  private var filterMenu: some View {
    Menu {
      ForEach(HistoryFilter.allCases, id: \.self) { filter in
        Button(action: { selectedFilter = filter }) {
          HStack {
            Text(filter.label)
            if selectedFilter == filter {
              Image(systemName: "checkmark")
            }
          }
        }
      }
    } label: {
      Image(systemName: "line.3.horizontal.decrease.circle")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(accentColor)
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
    .help("Filter history")
  }

  // MARK: - Search Field

  private var searchFieldView: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(secondaryTextColor)

        TextField("Search history", text: $searchText)
          .textFieldStyle(.plain)
          .font(.system(size: 14))
          .foregroundColor(textColor)

        if !searchText.isEmpty {
          Button(action: { searchText = "" }) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 14))
              .foregroundColor(secondaryTextColor)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.black.opacity(0.04))
      .cornerRadius(6)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)

      Divider().foregroundColor(Color.black.opacity(0.15))
    }
  }

  // MARK: - History List

  @ViewBuilder
  private var historyListView: some View {
    let groups = computeGroupedHistory()
    if groups.isEmpty {
      emptyStateView
    } else {
      historyScrollView(groups: groups)
    }
  }

  private var emptyStateView: some View {
    VStack(spacing: 12) {
      Image(systemName: "clock.badge.xmark")
        .font(.system(size: 32))
        .foregroundColor(secondaryTextColor)

      Text(searchText.isEmpty ? "No history" : "No results found")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(textColor)

      if !searchText.isEmpty {
        Text("Try a different search term")
          .font(.system(size: 12))
          .foregroundColor(secondaryTextColor)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.1))
  }

  private func historyScrollView(groups: [(date: String, entries: [HistoryEntry])]) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(groups.indices, id: \.self) { index in
          let group = groups[index]
          historyGroupView(group: group, isLast: index == groups.count - 1)
        }
      }
      .padding(.vertical, 8)
    }
    .background(Color.black.opacity(0.1))
  }

  private func historyGroupView(group: (date: String, entries: [HistoryEntry]), isLast: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(group.date)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(secondaryTextColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

      ForEach(Array(group.entries.enumerated()), id: \.element.id) { entryIndex, entry in
        HistoryItemRow(
          entry: entry,
          textColor: textColor,
          secondaryTextColor: secondaryTextColor,
          accentColor: accentColor,
          isLast: entryIndex == group.entries.count - 1,
          onTap: {
            if let tabId = viewModel.activeTabId {
              viewModel.loadURL(entry.url, for: tabId)
            }
            isPresented = false
          },
          onRemove: {
            viewModel.removeFromHistory(entry.id)
          }
        )
      }

      if !isLast {
        Divider()
          .foregroundColor(Color.black.opacity(0.15))
          .padding(.vertical, 4)
      }
    }
  }

  // MARK: - Compute Grouped History

  private func computeGroupedHistory() -> [(date: String, entries: [HistoryEntry])] {
    let filtered = filterHistory()
    let sorted = filtered.sorted { $0.visitDate > $1.visitDate }
    return groupByDate(sorted)
  }

  private func filterHistory() -> [HistoryEntry] {
    let calendar = Calendar.current
    let now = Date()

    return viewModel.history.filter { entry in
      let matchesSearch = searchText.isEmpty ||
        entry.title.localizedCaseInsensitiveContains(searchText) ||
        entry.url.absoluteString.localizedCaseInsensitiveContains(searchText)

      guard matchesSearch else { return false }

      switch selectedFilter {
      case .all: return true
      case .today: return calendar.isDateInToday(entry.visitDate)
      case .week:
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        return entry.visitDate >= weekAgo
      case .month:
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        return entry.visitDate >= monthAgo
      }
    }
  }

  private func groupByDate(_ entries: [HistoryEntry]) -> [(date: String, entries: [HistoryEntry])] {
    var groups: [String: [HistoryEntry]] = [:]
    let calendar = Calendar.current
    let now = Date()

    for entry in entries {
      let dateKey = dateKeyFor(entry.visitDate, calendar: calendar, now: now)
      groups[dateKey, default: []].append(entry)
    }

    let dateOrder = ["Today", "Yesterday"]
    let sortedKeys = groups.keys.sorted { a, b in
      if let aIdx = dateOrder.firstIndex(of: a), let bIdx = dateOrder.firstIndex(of: b) {
        return aIdx < bIdx
      }
      if dateOrder.contains(a) { return true }
      if dateOrder.contains(b) { return false }
      return a < b
    }

    return sortedKeys.map { (date: $0, entries: groups[$0] ?? []) }
  }

  private func dateKeyFor(_ date: Date, calendar: Calendar, now: Date) -> String {
    if calendar.isDateInToday(date) { return "Today" }
    if calendar.isDateInYesterday(date) { return "Yesterday" }

    let components = calendar.dateComponents([.day, .year], from: date, to: now)
    let dayDiff = components.day ?? 0

    if dayDiff < 7 { return "\(dayDiff) days ago" }
    if dayDiff < 30 {
      let weeks = dayDiff / 7
      return "\(weeks) week\(weeks > 1 ? "s" : "") ago"
    }
    if dayDiff < 365 {
      let months = dayDiff / 30
      return "\(months) month\(months > 1 ? "s" : "") ago"
    }

    let years = max(1, components.year ?? 1)
    return "\(years) year\(years > 1 ? "s" : "") ago"
  }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
  let entry: HistoryEntry
  let textColor: Color
  let secondaryTextColor: Color
  let accentColor: Color
  let isLast: Bool
  var onTap: (() -> Void)?
  var onRemove: (() -> Void)?

  @State private var isHovering = false
  @State private var favicon: NSImage?

  var body: some View {
    VStack(spacing: 0) {
      rowContent
      if !isLast {
        Divider().foregroundColor(Color.black.opacity(0.15))
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { onTap?() }
    .onHover { isHovering = $0 }
    .background(isHovering ? Color.black.opacity(0.04) : Color.clear)
  }

  private var rowContent: some View {
    HStack(spacing: 10) {
      faviconView
      titleAndUrl
      Spacer()
      timeLabel
      if isHovering { contextMenu }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private var faviconView: some View {
    Group {
      if let favicon = favicon {
        Image(nsImage: favicon)
          .resizable()
          .scaledToFit()
          .frame(width: 16, height: 16)
          .cornerRadius(2)
      } else {
        Image(systemName: "clock.fill")
          .font(.system(size: 14))
          .foregroundColor(secondaryTextColor)
          .frame(width: 16, height: 16)
          .onAppear { loadFavicon() }
      }
    }
  }

  private var titleAndUrl: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(entry.title)
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(textColor)
        .lineLimit(1)

      Text(entry.url.host ?? entry.url.absoluteString)
        .font(.system(size: 11))
        .foregroundColor(secondaryTextColor)
        .lineLimit(1)
    }
  }

  private var timeLabel: some View {
    Text(entry.visitDate.formatted(date: .omitted, time: .shortened))
      .font(.system(size: 11))
      .foregroundColor(secondaryTextColor)
  }

  private var contextMenu: some View {
    Menu {
      Button(action: copyLink) {
        Label("Copy Link", systemImage: "doc.on.doc")
      }
      Button(action: openInNewWindow) {
        Label("Open in New Window", systemImage: "arrow.up.right")
      }
      Divider()
      Button(role: .destructive, action: { onRemove?() }) {
        Label("Remove", systemImage: "trash")
      }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 14))
        .foregroundColor(accentColor)
        .frame(width: 24, height: 24)
    }
  }

  private func copyLink() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(entry.url.absoluteString, forType: .string)
  }

  private func openInNewWindow() {
    NSWorkspace.shared.open(entry.url)
  }

  private func loadFavicon() {
    guard let host = entry.url.host,
          let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    else { return }

    URLSession.shared.dataTask(with: faviconURL) { data, _, _ in
      guard let data = data, let image = NSImage(data: data) else { return }
      DispatchQueue.main.async { self.favicon = image }
    }.resume()
  }
}
