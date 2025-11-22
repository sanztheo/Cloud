//
//  DownloadManager.swift
//  Cloud
//

import AppKit
import Combine
import Foundation
import WebKit

class DownloadManager: NSObject, ObservableObject, WKDownloadDelegate {
  @Published var downloads: [DownloadItem] = []

  private let downloadsDirectory: URL
  private var activeDownloads: [WKDownload: UUID] = [:]
  private var activeURLSessionTasks: [UUID: URLSessionDownloadTask] = [:]
  private let activeDownloadsQueue = DispatchQueue(label: "cloud.downloads.active", attributes: .concurrent)
  private let persistenceKey = "cloud_downloads"

  override init() {
    // Get the real user Downloads folder
    self.downloadsDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    NSLog("📥 Downloads directory: %@", downloadsDirectory.path)
    super.init()
    loadDownloads()
  }

  // MARK: - Download Management

  func trackDownload(_ download: WKDownload) {
    activeDownloadsQueue.sync(flags: .barrier) {
      let downloadId = UUID()
      activeDownloads[download] = downloadId
      NSLog("📥 trackDownload: Added download to activeDownloads, count: %d", activeDownloads.count)
    }
  }

  func cancelDownload(_ downloadId: UUID) {
    activeDownloadsQueue.sync(flags: .barrier) {
      // Cancel WKDownload if exists
      if let activeDownload = activeDownloads.first(where: { $0.value == downloadId }) {
        activeDownload.key.cancel()
        activeDownloads.removeValue(forKey: activeDownload.key)
      }
      // Cancel URLSession task if exists
      if let task = activeURLSessionTasks[downloadId] {
        task.cancel()
        activeURLSessionTasks.removeValue(forKey: downloadId)
      }
    }

    DispatchQueue.main.async {
      if let index = self.downloads.firstIndex(where: { $0.id == downloadId }) {
        self.downloads.remove(at: index)
        self.saveDownloads()
      }
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

  // MARK: - WKDownloadDelegate (Native WebKit Downloads)

  func download(
    _ download: WKDownload,
    decideDestinationUsing response: URLResponse,
    suggestedFilename: String,
    completionHandler: @escaping (URL?) -> Void
  ) {
    NSLog("📥 WKDownloadDelegate.decideDestinationUsing - filename: %@", suggestedFilename)

    // Generate unique filename
    let destinationURL = generateUniqueDestinationURL(for: suggestedFilename)

    // Create download item
    let sourceURL = response.url ?? URL(fileURLWithPath: "/")
    let downloadItem = DownloadItem(
      filename: destinationURL.lastPathComponent,
      url: sourceURL,
      destinationURL: destinationURL,
      fileSize: response.expectedContentLength,
      status: .inProgress
    )

    DispatchQueue.main.async {
      self.downloads.insert(downloadItem, at: 0)
      self.saveDownloads()
    }

    activeDownloadsQueue.sync(flags: .barrier) {
      activeDownloads[download] = downloadItem.id
    }

    NSLog("📥 Will download to: %@", destinationURL.path)
    completionHandler(destinationURL)
  }

  func downloadDidFinish(_ download: WKDownload) {
    NSLog("📥 WKDownloadDelegate.downloadDidFinish")
    var downloadId: UUID?
    activeDownloadsQueue.sync(flags: .barrier) {
      downloadId = activeDownloads.removeValue(forKey: download)
    }
    guard let downloadId = downloadId else {
      NSLog("⚠️ downloadDidFinish: No matching download ID found")
      return
    }

    DispatchQueue.main.async {
      if let index = self.downloads.firstIndex(where: { $0.id == downloadId }) {
        self.downloads[index].status = .completed
        self.downloads[index].endTime = Date()
        self.downloads[index].downloadedBytes = self.downloads[index].fileSize
        self.saveDownloads()
        NSLog("📥 Download completed: %@", self.downloads[index].filename)
      }
    }
  }

  func download(
    _ download: WKDownload,
    didFailWithError error: Error,
    resumeData: Data?
  ) {
    NSLog("📥 WKDownloadDelegate.didFailWithError: %@", error.localizedDescription)
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

  // MARK: - Helper Methods

  private func generateUniqueDestinationURL(for filename: String) -> URL {
    var destinationURL = downloadsDirectory.appendingPathComponent(filename)

    // If file exists, add a number suffix
    var counter = 1
    let fileManager = FileManager.default
    let nameWithoutExtension = destinationURL.deletingPathExtension().lastPathComponent
    let fileExtension = destinationURL.pathExtension

    while fileManager.fileExists(atPath: destinationURL.path) {
      let newName: String
      if fileExtension.isEmpty {
        newName = "\(nameWithoutExtension) (\(counter))"
      } else {
        newName = "\(nameWithoutExtension) (\(counter)).\(fileExtension)"
      }
      destinationURL = downloadsDirectory.appendingPathComponent(newName)
      counter += 1
    }

    return destinationURL
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

  // MARK: - Finder Integration

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
