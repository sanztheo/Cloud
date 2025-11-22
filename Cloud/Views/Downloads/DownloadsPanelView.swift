//
//  DownloadsPanelView.swift
//  Cloud
//

import SwiftUI

struct DownloadsPanelView: View {
  @ObservedObject var downloadManager: DownloadManager
  let theme: SpaceTheme?

  @State private var showClearConfirm = false
  @State private var hoverClearConfirm = false
  @State private var hoverClearCancel = false

  // MARK: - Colors

  private var backgroundColor: Color {
    theme?.sidebarBackground ?? AppColors.sidebarBackground
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
      if downloadManager.downloads.isEmpty {
        emptyStateView
      } else {
        downloadListView
      }
    }
    .background(backgroundColor)
  }

  // MARK: - Empty State

  private var emptyStateView: some View {
    VStack(spacing: 12) {
      Image(systemName: "arrow.down.circle")
        .font(.system(size: 32))
        .foregroundColor(secondaryTextColor)

      Text("No downloads")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(textColor)

      Text("Downloaded files will appear here")
        .font(.system(size: 12))
        .foregroundColor(secondaryTextColor)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.1))
  }

  // MARK: - Download List

  private var downloadListView: some View {
    VStack(spacing: 0) {
      downloadHeaderView
      Divider().foregroundColor(Color.black.opacity(0.15))

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(Array(downloadManager.downloads.enumerated()), id: \.element.id) { index, download in
            DownloadItemRow(
              download: download,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              accentColor: accentColor,
              isLast: index == downloadManager.downloads.count - 1,
              downloadManager: downloadManager
            )
          }
        }
        .padding(.vertical, 8)
      }
      .background(Color.black.opacity(0.1))
    }
  }

  // MARK: - Header

  private var downloadHeaderView: some View {
    HStack(spacing: 12) {
      Spacer()
      Text("Downloads")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(textColor)
      Spacer()

      if !downloadManager.downloads.isEmpty {
        clearDownloadsButton
      }

      Menu {
        Button(action: { downloadManager.openDownloadsFolder() }) {
          Label("Open Downloads Folder", systemImage: "folder")
        }

        if downloadManager.downloads.contains(where: { $0.status == .completed }) {
          Divider()
          Button(role: .destructive, action: { showClearConfirm = true }) {
            Label("Clear Completed", systemImage: "trash")
          }
        }
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(accentColor)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("More options")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private var clearDownloadsButton: some View {
    Button(action: { showClearConfirm.toggle() }) {
      Image(systemName: "trash")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(secondaryTextColor)
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Clear downloads")
    .popover(isPresented: $showClearConfirm, arrowEdge: .bottom) {
      VStack(spacing: 12) {
        Text("Clear completed downloads?")
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.primary)

        HStack(spacing: 8) {
          Button(action: { showClearConfirm = false }) {
            Text("Cancel")
              .font(.system(size: 12, weight: .medium))
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(hoverClearCancel ? Color.primary.opacity(0.1) : Color.clear)
              .cornerRadius(6)
          }
          .buttonStyle(.plain)
          .foregroundColor(.primary)
          .onHover { hoverClearCancel = $0 }

          Button(action: {
            downloadManager.clearDownloads()
            showClearConfirm = false
          }) {
            Text("Clear")
              .font(.system(size: 12, weight: .medium))
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(hoverClearConfirm ? Color.red.opacity(0.2) : Color.red.opacity(0.1))
              .cornerRadius(6)
          }
          .buttonStyle(.plain)
          .foregroundColor(.red)
          .onHover { hoverClearConfirm = $0 }
        }
      }
      .padding(12)
    }
  }
}

// MARK: - Download Item Row

struct DownloadItemRow: View {
  let download: DownloadItem
  let textColor: Color
  let secondaryTextColor: Color
  let accentColor: Color
  let isLast: Bool
  let downloadManager: DownloadManager

  @State private var isHovering = false
  @State private var showContextMenu = false
  @State private var hoverOpen = false
  @State private var hoverReveal = false
  @State private var hoverRemove = false
  @State private var hoverSpinner = false
  @State private var thumbnail: NSImage?

  private var isImageFile: Bool {
    let ext = (download.filename as NSString).pathExtension.lowercased()
    return ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "heic"].contains(ext)
  }

  var body: some View {
    VStack(spacing: 0) {
      rowContent
      if !isLast {
        Divider().foregroundColor(Color.black.opacity(0.15))
      }
    }
    .contentShape(Rectangle())
    .onHover { isHovering = $0 }
    .background(isHovering ? Color.black.opacity(0.04) : Color.clear)
    .onAppear { loadThumbnail() }
    .onChange(of: download.status) { _, _ in loadThumbnail() }
  }

  private func loadThumbnail() {
    guard isImageFile, download.status == .completed else {
      thumbnail = nil
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      if let image = NSImage(contentsOf: download.destinationURL) {
        DispatchQueue.main.async {
          self.thumbnail = image
        }
      }
    }
  }

  private var rowContent: some View {
    HStack(spacing: 10) {
      thumbnailView
      titleAndInfo
      Spacer()

      if download.status == .inProgress {
        // Always show spinner/cancel button during download
        statusIndicator
      } else if isHovering || showContextMenu {
        contextMenu
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private var thumbnailView: some View {
    if isImageFile, let thumbnail = thumbnail {
      Image(nsImage: thumbnail)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    } else {
      fileIconView
    }
  }

  private var fileIconView: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.black.opacity(0.08))
        .frame(width: 44, height: 44)

      Image(systemName: iconForFileName(download.filename))
        .font(.system(size: 18))
        .foregroundColor(secondaryTextColor)
    }
  }

  private var titleAndInfo: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(download.filename)
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(textColor)
        .lineLimit(1)

      HStack(spacing: 8) {
        Text(download.formattedDownloadedBytes + " / " + download.formattedFileSize)
          .font(.system(size: 11))
          .foregroundColor(secondaryTextColor)

        if download.status == .inProgress, let speed = download.downloadSpeed {
          Text(speed)
            .font(.system(size: 11))
            .foregroundColor(secondaryTextColor)
        }
      }

      if download.status == .inProgress {
        ProgressView(value: download.progress)
          .frame(height: 4)
          .tint(.blue)
      } else if download.status == .completed {
        HStack(spacing: 4) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 10))
            .foregroundColor(.green)
          Text("Completed")
            .font(.system(size: 10))
            .foregroundColor(.green)
        }
      } else if download.status == .failed {
        HStack(spacing: 4) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 10))
            .foregroundColor(.red)
          Text(download.error ?? "Failed")
            .font(.system(size: 10))
            .foregroundColor(.red)
            .lineLimit(1)
        }
      }
    }
  }

  private var statusIndicator: some View {
    HStack(spacing: 4) {
      Button(action: {
        downloadManager.cancelDownload(download.id)
      }) {
        ZStack {
          if hoverSpinner {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 16))
              .foregroundColor(.red)
          } else {
            ProgressView()
              .scaleEffect(0.7, anchor: .center)
          }
        }
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .onHover { hoverSpinner = $0 }

      Text("\(Int(download.progress * 100))%")
        .font(.system(size: 11))
        .foregroundColor(secondaryTextColor)
        .frame(width: 28)
    }
  }

  private var contextMenu: some View {
    Button(action: { showContextMenu.toggle() }) {
      Image(systemName: "ellipsis")
        .font(.system(size: 14))
        .foregroundColor(accentColor)
        .frame(width: 24, height: 24)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showContextMenu, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: 0) {
        if download.status == .completed {
          Button(action: {
            downloadManager.openDownload(download.id)
            showContextMenu = false
          }) {
            HStack(spacing: 8) {
              Image(systemName: "arrow.up.right")
                .frame(width: 16)
              Text("Open")
              Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(hoverOpen ? Color.primary.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .foregroundColor(.primary)
          .onHover { hoverOpen = $0 }

          Button(action: {
            downloadManager.revealInFinder(download.id)
            showContextMenu = false
          }) {
            HStack(spacing: 8) {
              Image(systemName: "folder")
                .frame(width: 16)
              Text("Show in Finder")
              Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(hoverReveal ? Color.primary.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .foregroundColor(.primary)
          .onHover { hoverReveal = $0 }

          Divider()
            .padding(.vertical, 4)
        }

        Button(action: {
          downloadManager.removeDownload(download.id)
          showContextMenu = false
        }) {
          HStack(spacing: 8) {
            Image(systemName: "trash")
              .frame(width: 16)
            Text("Remove")
            Spacer()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity)
          .background(hoverRemove ? Color.red.opacity(0.1) : Color.clear)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.red)
        .onHover { hoverRemove = $0 }
      }
      .padding(.vertical, 4)
      .frame(width: 180)
    }
  }

  private func iconForFileName(_ filename: String) -> String {
    let ext = (filename as NSString).pathExtension.lowercased()
    switch ext {
    case "pdf": return "doc.text"
    case "doc", "docx": return "doc.text"
    case "xls", "xlsx": return "table"
    case "ppt", "pptx": return "doc.richtext"
    case "zip", "rar": return "doc.zipper"
    case "mp3", "wav", "flac": return "music.note"
    case "mp4", "mov", "avi": return "play.rectangle"
    case "jpg", "jpeg", "png", "gif": return "image"
    case "txt": return "doc.plaintext"
    default: return "doc"
    }
  }
}
