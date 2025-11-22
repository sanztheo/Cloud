//
//  DownloadItem.swift
//  Cloud
//

import Foundation

enum DownloadStatus: String, Codable {
  case inProgress = "inProgress"
  case completed = "completed"
  case failed = "failed"
  case paused = "paused"
}

struct DownloadItem: Identifiable, Codable {
  let id: UUID
  let filename: String
  let url: URL
  var destinationURL: URL
  let fileSize: Int64
  var downloadedBytes: Int64
  var status: DownloadStatus
  let startTime: Date
  var endTime: Date?
  var error: String?

  init(
    id: UUID = UUID(),
    filename: String,
    url: URL,
    destinationURL: URL,
    fileSize: Int64 = 0,
    downloadedBytes: Int64 = 0,
    status: DownloadStatus = .inProgress,
    startTime: Date = Date(),
    endTime: Date? = nil,
    error: String? = nil
  ) {
    self.id = id
    self.filename = filename
    self.url = url
    self.destinationURL = destinationURL
    self.fileSize = fileSize
    self.downloadedBytes = downloadedBytes
    self.status = status
    self.startTime = startTime
    self.endTime = endTime
    self.error = error
  }

  var progress: Double {
    guard fileSize > 0 else { return 0 }
    return Double(downloadedBytes) / Double(fileSize)
  }

  var formattedFileSize: String {
    formatBytes(fileSize)
  }

  var formattedDownloadedBytes: String {
    formatBytes(downloadedBytes)
  }

  private static let byteFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter
  }()

  private func formatBytes(_ bytes: Int64) -> String {
    Self.byteFormatter.string(fromByteCount: bytes)
  }

  var duration: TimeInterval? {
    guard let endTime = endTime else { return nil }
    return endTime.timeIntervalSince(startTime)
  }

  var downloadSpeed: String? {
    guard let duration = duration, duration > 0 else { return nil }
    let speed = Double(downloadedBytes) / duration
    return formatBytes(Int64(speed)) + "/s"
  }
}
