//
//  DownloadManager.swift
//  Cloud
//

import Combine
import Foundation
import WebKit

class DownloadManager: NSObject, ObservableObject, WKDownloadDelegate {
  @Published var downloads: [DownloadItem] = []

  private let downloadsDirectory: URL
  private var activeDownloads: [WKDownload: UUID] = [:]
  private let activeDownloadsQueue = DispatchQueue(label: "cloud.downloads.active", attributes: .concurrent)
  private let persistenceKey = "cloud_downloads"

  override init() {
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)
    self.downloadsDirectory = urls[0]
    super.init()
    loadDownloads()
  }

  // MARK: - Download Management

  func trackDownload(_ download: WKDownload) {
    activeDownloadsQueue.sync(flags: .barrier) {
      // Generate a UUID for this download (we'll match it when we get the delegate callback)
      let downloadId = UUID()
      activeDownloads[download] = downloadId
    }
  }

  func startDownload(url: URL, suggestedFilename: String, downloadSize: Int64 = 0) {
    let destinationURL = downloadsDirectory.appendingPathComponent(suggestedFilename)
    let download = DownloadItem(
      filename: suggestedFilename,
      url: url,
      destinationURL: destinationURL,
      fileSize: downloadSize,
      status: .inProgress
    )
    downloads.insert(download, at: 0)
    saveDownloads()
  }

  func cancelDownload(_ downloadId: UUID) {
    // Cancel the active WKDownload if exists
    activeDownloadsQueue.sync(flags: .barrier) {
      if let activeDownload = activeDownloads.first(where: { $0.value == downloadId }) {
        activeDownload.key.cancel()
        activeDownloads.removeValue(forKey: activeDownload.key)
      }
    }

    if let index = downloads.firstIndex(where: { $0.id == downloadId }) {
      downloads.remove(at: index)
      saveDownloads()
    }
  }

  func removeDownload(_ downloadId: UUID) {
    if let index = downloads.firstIndex(where: { $0.id == downloadId }) {
      let download = downloads[index]
      try? FileManager.default.removeItem(at: download.destinationURL)
      downloads.remove(at: index)
      saveDownloads()
    }
  }

  func clearDownloads() {
    downloads.removeAll { $0.status == .completed }
    saveDownloads()
  }

  func clearAllDownloads() {
    for download in downloads {
      try? FileManager.default.removeItem(at: download.destinationURL)
    }
    downloads.removeAll()
    saveDownloads()
  }

  // MARK: - WKDownloadDelegate

  func download(
    _ download: WKDownload,
    decideDestinationUsing response: URLResponse,
    suggestedFilename: String,
    completionHandler: @escaping (URL?) -> Void
  ) {
    let destinationURL = downloadsDirectory.appendingPathComponent(suggestedFilename)
    let sourceURL = response.url ?? URL(fileURLWithPath: "/")
    let downloadItem = DownloadItem(
      filename: suggestedFilename,
      url: sourceURL,
      destinationURL: destinationURL,
      fileSize: response.expectedContentLength
    )

    DispatchQueue.main.async {
      self.downloads.insert(downloadItem, at: 0)
      self.activeDownloadsQueue.sync(flags: .barrier) {
        self.activeDownloads[download] = downloadItem.id
      }
      self.saveDownloads()
    }

    completionHandler(destinationURL)
  }

  func downloadDidFinish(_ download: WKDownload) {
    var downloadId: UUID?
    activeDownloadsQueue.sync(flags: .barrier) {
      downloadId = activeDownloads.removeValue(forKey: download)
    }
    guard let downloadId = downloadId else { return }

    DispatchQueue.main.async {
      if let index = self.downloads.firstIndex(where: { $0.id == downloadId }) {
        self.downloads[index].status = .completed
        self.downloads[index].endTime = Date()
        self.downloads[index].downloadedBytes = self.downloads[index].fileSize
        self.saveDownloads()
      }
    }
  }

  func download(
    _ download: WKDownload,
    didFailWithError error: Error,
    resumeData: Data?
  ) {
    var downloadId: UUID?
    activeDownloadsQueue.sync(flags: .barrier) {
      downloadId = activeDownloads.removeValue(forKey: download)
    }
    guard let downloadId = downloadId else { return }

    DispatchQueue.main.async {
      if let index = self.downloads.firstIndex(where: { $0.id == downloadId }) {
        self.downloads[index].status = .failed
        self.downloads[index].error = error.localizedDescription
        self.downloads[index].endTime = Date()
        self.saveDownloads()
      }
    }
  }

  // MARK: - Persistence

  private func saveDownloads() {
    if let encoded = try? JSONEncoder().encode(downloads) {
      UserDefaults.standard.set(encoded, forKey: persistenceKey)
    }
  }

  private func loadDownloads() {
    if let data = UserDefaults.standard.data(forKey: persistenceKey),
       let decoded = try? JSONDecoder().decode([DownloadItem].self, from: data) {
      downloads = decoded
    }
  }

  // MARK: - Helpers

  func openDownloadsFolder() {
    NSWorkspace.shared.open(downloadsDirectory)
  }

  func revealInFinder(_ downloadId: UUID) {
    guard let download = downloads.first(where: { $0.id == downloadId }) else { return }
    NSWorkspace.shared.activateFileViewerSelecting([download.destinationURL])
  }

  func openDownload(_ downloadId: UUID) {
    guard let download = downloads.first(where: { $0.id == downloadId }) else { return }
    NSWorkspace.shared.open(download.destinationURL)
  }
}
