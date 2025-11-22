//
//  HistoryCellView.swift
//  Cloud
//
//  History cell view with favicon, title, URL, and hover effects
//

import SwiftUI

struct HistoryCellView: View {
  let entry: HistoryEntry
  let theme: SpaceTheme?
  let onTap: () -> Void

  @State private var isHovered = false
  @State private var favicon: NSImage?
  @State private var isLoadingFavicon = false

  var body: some View {
    HStack(spacing: 12) {
      // Favicon
      Image(nsImage: favicon ?? NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage())
        .resizable()
        .scaledToFit()
        .frame(width: 32, height: 32)
        .background(Color.black.opacity(0.08))
        .cornerRadius(6)

      // Title and URL Stack
      VStack(alignment: .leading, spacing: 3) {
        Text(entry.title)
          .font(.system(size: 14, weight: .medium))
          .lineLimit(1)
          .truncationMode(.tail)
          .foregroundColor(theme?.mode == .dark ? .white : Color.black.opacity(0.8))

        Text(entry.url.host ?? entry.url.absoluteString)
          .font(.system(size: 12, weight: .regular))
          .lineLimit(1)
          .truncationMode(.tail)
          .foregroundColor(.gray)
      }

      Spacer()
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: onTap)
    .onHover { hovering in
      isHovered = hovering
    }
    .background(
      isHovered
        ? Color.black.opacity(0.06)
        : Color.clear
    )
    .cornerRadius(8)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .onAppear {
      loadFavicon()
    }
  }

  private func loadFavicon() {
    guard !isLoadingFavicon else { return }
    guard let host = entry.url.host else { return }

    isLoadingFavicon = true
    let faviconURLString = "https://www.google.com/s2/favicons?domain=\(host)&sz=64"
    guard let faviconURL = URL(string: faviconURLString) else { return }

    URLSession.shared.dataTask(with: faviconURL) { data, _, _ in
      guard let data = data, let image = NSImage(data: data) else {
        DispatchQueue.main.async {
          isLoadingFavicon = false
        }
        return
      }

      DispatchQueue.main.async {
        self.favicon = image
        isLoadingFavicon = false
      }
    }.resume()
  }
}

#Preview {
  let entry = HistoryEntry(
    url: URL(string: "https://www.apple.com")!,
    title: "Apple",
    visitDate: Date()
  )

  return HistoryCellView(entry: entry, theme: .init()) {
    print("Tapped")
  }
  .frame(height: 50)
}
