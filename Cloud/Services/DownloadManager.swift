//
//  DownloadManager.swift
//  Cloud
//

import AppKit
import Combine
import Foundation
import WebKit

class DownloadManager: NSObject, ObservableObject, WKDownloadDelegate, URLSessionDownloadDelegate {
  @Published var downloads: [DownloadItem] = []

  private let downloadsDirectory: URL
  private var activeDownloads: [WKDownload: UUID] = [:]
  private var activeURLSessionTasks: [URLSessionDownloadTask: UUID] = [:]
  private var downloadDestinations: [UUID: URL] = [:]
  private let activeDownloadsQueue = DispatchQueue(label: "cloud.downloads.active", attributes: .concurrent)
  private let persistenceKey = "cloud_downloads"

  // Progress monitoring for WKDownload (which doesn't have progress callbacks)
  private var progressMonitorTimers: [UUID: Timer] = [:]
  private var monitoredDownloadPaths: [UUID: URL] = [:]

  private lazy var urlSession: URLSession = {
    let config = URLSessionConfiguration.default
    return URLSession(configuration: config, delegate: self, delegateQueue: .main)
  }()

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
    // Stop progress monitoring
    stopProgressMonitoring(for: downloadId)

    activeDownloadsQueue.sync(flags: .barrier) {
      // Cancel WKDownload if exists
      if let activeDownload = activeDownloads.first(where: { $0.value == downloadId }) {
        activeDownload.key.cancel()
        activeDownloads.removeValue(forKey: activeDownload.key)
      }
      // Cancel URLSession task if exists
      if let taskEntry = activeURLSessionTasks.first(where: { $0.value == downloadId }) {
        taskEntry.key.cancel()
        activeURLSessionTasks.removeValue(forKey: taskEntry.key)
      }
    }

    downloadDestinations.removeValue(forKey: downloadId)

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

  // MARK: - Progress Monitoring for WKDownload

  private func startProgressMonitoring(for downloadId: UUID, destinationURL: URL, expectedSize: Int64) {
    // Store the path to monitor
    monitoredDownloadPaths[downloadId] = destinationURL

    // Create a timer that polls the file size every 0.5 seconds
    let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      self?.updateProgressFromFile(downloadId: downloadId, destinationURL: destinationURL, expectedSize: expectedSize)
    }
    progressMonitorTimers[downloadId] = timer
    NSLog("📥 Started progress monitoring for: %@", destinationURL.lastPathComponent)
  }

  private func stopProgressMonitoring(for downloadId: UUID) {
    progressMonitorTimers[downloadId]?.invalidate()
    progressMonitorTimers.removeValue(forKey: downloadId)
    monitoredDownloadPaths.removeValue(forKey: downloadId)
  }

  private func updateProgressFromFile(downloadId: UUID, destinationURL: URL, expectedSize: Int64) {
    let fileManager = FileManager.default

    // Check if the file exists and get its size
    guard fileManager.fileExists(atPath: destinationURL.path),
          let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
          let fileSize = attributes[.size] as? Int64 else {
      return
    }

    DispatchQueue.main.async {
      if let index = self.downloads.firstIndex(where: { $0.id == downloadId }) {
        self.downloads[index].downloadedBytes = fileSize
        if expectedSize > 0 {
          self.downloads[index].fileSize = expectedSize
        }
      }
    }
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
    let expectedSize = response.expectedContentLength
    let downloadItem = DownloadItem(
      filename: destinationURL.lastPathComponent,
      url: sourceURL,
      destinationURL: destinationURL,
      fileSize: expectedSize,
      status: .inProgress
    )

    DispatchQueue.main.async {
      self.downloads.insert(downloadItem, at: 0)
      self.saveDownloads()

      // Start progress monitoring
      self.startProgressMonitoring(for: downloadItem.id, destinationURL: destinationURL, expectedSize: expectedSize)
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

    // Stop progress monitoring
    stopProgressMonitoring(for: downloadId)

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

    // Stop progress monitoring
    stopProgressMonitoring(for: downloadId)

    DispatchQueue.main.async {
      if let index = self.downloads.firstIndex(where: { $0.id == downloadId }) {
        self.downloads[index].status = .failed
        self.downloads[index].error = error.localizedDescription
        self.downloads[index].endTime = Date()
        self.saveDownloads()
      }
    }
  }

  // MARK: - URLSession Download with Progress

  func startURLSessionDownload(url: URL, suggestedFilename: String) {
    NSLog("📥 Starting URLSession download with progress for: %@", url.absoluteString)

    let destinationURL = generateUniqueDestinationURL(for: suggestedFilename)

    let downloadItem = DownloadItem(
      filename: destinationURL.lastPathComponent,
      url: url,
      destinationURL: destinationURL,
      fileSize: 0,
      status: .inProgress
    )

    downloads.insert(downloadItem, at: 0)
    downloadDestinations[downloadItem.id] = destinationURL
    saveDownloads()

    let task = urlSession.downloadTask(with: url)
    activeURLSessionTasks[task] = downloadItem.id
    task.resume()
  }

  // MARK: - URLSessionDownloadDelegate (Progress Tracking)

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    guard let downloadId = activeURLSessionTasks[downloadTask] else { return }

    DispatchQueue.main.async {
      if let index = self.downloads.firstIndex(where: { $0.id == downloadId }) {
        self.downloads[index].downloadedBytes = totalBytesWritten
        if totalBytesExpectedToWrite > 0 {
          self.downloads[index].fileSize = totalBytesExpectedToWrite
        }
      }
    }
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let downloadId = activeURLSessionTasks.removeValue(forKey: downloadTask),
          let destinationURL = downloadDestinations.removeValue(forKey: downloadId) else {
      NSLog("⚠️ URLSession download finished but no matching ID found")
      return
    }

    NSLog("📥 URLSession download finished, moving to: %@", destinationURL.path)

    do {
      let fileManager = FileManager.default

      // Create directory if needed
      let destinationDir = destinationURL.deletingLastPathComponent()
      if !fileManager.fileExists(atPath: destinationDir.path) {
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
      }

      // Remove existing file if exists
      if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
      }

      // Move temp file to destination
      try fileManager.moveItem(at: location, to: destinationURL)

      NSLog("📥 Download completed: %@", destinationURL.path)

      DispatchQueue.main.async {
        if let index = self.downloads.firstIndex(where: { $0.id == downloadId }) {
          self.downloads[index].status = .completed
          self.downloads[index].endTime = Date()
          self.downloads[index].downloadedBytes = self.downloads[index].fileSize
          self.saveDownloads()
        }
      }
    } catch {
      NSLog("📥 Failed to move downloaded file: %@", error.localizedDescription)
      DispatchQueue.main.async {
        if let index = self.downloads.firstIndex(where: { $0.id == downloadId }) {
          self.downloads[index].status = .failed
          self.downloads[index].error = error.localizedDescription
          self.downloads[index].endTime = Date()
          self.saveDownloads()
        }
      }
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let downloadTask = task as? URLSessionDownloadTask,
          let error = error,
          let downloadId = activeURLSessionTasks.removeValue(forKey: downloadTask) else { return }

    downloadDestinations.removeValue(forKey: downloadId)

    NSLog("📥 URLSession download failed: %@", error.localizedDescription)

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
