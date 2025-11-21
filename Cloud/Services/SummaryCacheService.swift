//
//  SummaryCacheService.swift
//  Cloud
//
//  Thread-safe cache service for storing and retrieving AI-generated summaries
//  with automatic expiration, FIFO overflow handling, and file-based persistence.
//

import Foundation
import CryptoKit

// MARK: - Cache Models

struct CachedSummary: Codable {
    let url: String
    let contentHash: String
    let summary: String
    let timestamp: Date
    let model: String

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 86400 // 24 hours in seconds
    }
}

struct CacheContainer: Codable {
    var summaries: [CachedSummary] = []
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let count: Int
    let totalSize: Int
    let oldestEntry: Date?
    let newestEntry: Date?
}

// MARK: - Cache Service

actor SummaryCacheService {
    // MARK: - Constants

    private static let maxCacheEntries = 100
    private static let cacheExpirationInterval: TimeInterval = 86400 // 24 hours
    private static let cacheFileName = "summaries_cache.json"
    private static let applicationName = "Cloud"

    // MARK: - Properties

    private var cache: CacheContainer = CacheContainer()
    private let fileManager = FileManager.default
    private let cacheFileURL: URL
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    // MARK: - Initialization

    init() {
        // Setup cache directory and file URL
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent(Self.applicationName)
        self.cacheFileURL = appDirectory.appendingPathComponent(Self.cacheFileName)

        // Create directory if needed
        try? fileManager.createDirectory(at: appDirectory,
                                        withIntermediateDirectories: true,
                                        attributes: nil)

        // Configure JSON encoder/decoder
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonDecoder.dateDecodingStrategy = .iso8601

        // Load existing cache
        Task {
            await loadCache()
            await cleanExpiredEntries()
        }
    }

    // MARK: - Public Methods

    /// Retrieve cached summary if valid (not expired and content matches)
    func getCachedSummary(for url: URL, contentHash: String) -> String? {
        let urlString = url.absoluteString

        // Find matching entry
        guard let cachedEntry = cache.summaries.first(where: {
            $0.url == urlString && $0.contentHash == contentHash
        }) else {
            return nil
        }

        // Check if expired
        if cachedEntry.isExpired {
            // Remove expired entry
            cache.summaries.removeAll { $0.url == urlString && $0.contentHash == contentHash }
            Task {
                await saveCache()
            }
            return nil
        }

        return cachedEntry.summary
    }

    /// Store new summary in cache with FIFO overflow handling
    func cacheSummary(_ summary: String, for url: URL, contentHash: String) async {
        let urlString = url.absoluteString

        // Remove any existing entry for this URL
        cache.summaries.removeAll { $0.url == urlString }

        // Create new cache entry
        let newEntry = CachedSummary(
            url: urlString,
            contentHash: contentHash,
            summary: summary,
            timestamp: Date(),
            model: "gpt-5.1-nano"
        )

        // Add new entry
        cache.summaries.append(newEntry)

        // Enforce FIFO limit
        if cache.summaries.count > Self.maxCacheEntries {
            // Sort by timestamp and keep only the most recent entries
            cache.summaries.sort { $0.timestamp > $1.timestamp }
            cache.summaries = Array(cache.summaries.prefix(Self.maxCacheEntries))
        }

        // Save to disk
        await saveCache()
    }

    /// Clear all cached summaries
    func clearCache() async {
        cache.summaries.removeAll()
        await saveCache()
    }

    /// Get cache statistics
    func getCacheStats() -> CacheStatistics {
        let totalSize = calculateCacheSize()
        let oldestEntry = cache.summaries.min(by: { $0.timestamp < $1.timestamp })?.timestamp
        let newestEntry = cache.summaries.max(by: { $0.timestamp < $1.timestamp })?.timestamp

        return CacheStatistics(
            count: cache.summaries.count,
            totalSize: totalSize,
            oldestEntry: oldestEntry,
            newestEntry: newestEntry
        )
    }

    /// Clean expired entries (older than 24h)
    func cleanExpiredEntries() async {
        let originalCount = cache.summaries.count
        cache.summaries.removeAll { $0.isExpired }

        if cache.summaries.count < originalCount {
            await saveCache()
            print("Removed \(originalCount - cache.summaries.count) expired cache entries")
        }
    }

    /// Check if summary exists and is valid
    func hasCachedSummary(for url: URL, contentHash: String) -> Bool {
        let urlString = url.absoluteString
        return cache.summaries.contains {
            $0.url == urlString &&
            $0.contentHash == contentHash &&
            !$0.isExpired
        }
    }

    /// Get cache file size in bytes
    func getCacheSize() -> Int {
        calculateCacheSize()
    }

    /// Get number of cached entries
    func getCachedCount() -> Int {
        cache.summaries.count
    }

    /// Generate MD5 hash from content string
    func generateContentHash(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private Methods

    /// Load cache from disk
    private func loadCache() {
        guard fileManager.fileExists(atPath: cacheFileURL.path) else {
            print("No cache file found, starting with empty cache")
            return
        }

        do {
            let data = try Data(contentsOf: cacheFileURL)
            cache = try jsonDecoder.decode(CacheContainer.self, from: data)
            print("Loaded \(cache.summaries.count) cached summaries")
        } catch {
            print("Failed to load cache: \(error)")
            // If cache is corrupted, start fresh
            cache = CacheContainer()

            // Try to backup the corrupted file
            let backupURL = cacheFileURL.appendingPathExtension("backup")
            try? fileManager.moveItem(at: cacheFileURL, to: backupURL)
        }
    }

    /// Save cache to disk with atomic write
    private func saveCache() async {
        do {
            let data = try jsonEncoder.encode(cache)

            // Use atomic write to prevent corruption
            let tempURL = cacheFileURL.appendingPathExtension("tmp")
            try data.write(to: tempURL)

            // Replace existing file atomically
            if fileManager.fileExists(atPath: cacheFileURL.path) {
                _ = try fileManager.replaceItem(at: cacheFileURL,
                                               withItemAt: tempURL,
                                               backupItemName: nil,
                                               options: [],
                                               resultingItemURL: nil)
            } else {
                try fileManager.moveItem(at: tempURL, to: cacheFileURL)
            }

        } catch {
            print("Failed to save cache: \(error)")

            // Handle specific errors
            if let nsError = error as NSError? {
                switch nsError.code {
                case NSFileWriteOutOfSpaceError:
                    print("Disk full - clearing oldest entries")
                    await removeOldestEntries(count: 10)
                case NSFileWriteNoPermissionError:
                    print("Permission denied - check file permissions")
                default:
                    print("Unexpected file error: \(nsError)")
                }
            }
        }
    }

    /// Calculate total cache size in bytes
    private func calculateCacheSize() -> Int {
        // Calculate approximate size of cached data
        var totalSize = 0

        for summary in cache.summaries {
            totalSize += summary.url.utf8.count
            totalSize += summary.contentHash.utf8.count
            totalSize += summary.summary.utf8.count
            totalSize += summary.model.utf8.count
            totalSize += 8 // Date timestamp
        }

        return totalSize
    }

    /// Remove oldest entries when needed
    private func removeOldestEntries(count: Int) async {
        guard cache.summaries.count > count else {
            cache.summaries.removeAll()
            await saveCache()
            return
        }

        // Sort by timestamp and remove oldest
        cache.summaries.sort { $0.timestamp < $1.timestamp }
        cache.summaries.removeFirst(min(count, cache.summaries.count))
        await saveCache()
    }

    /// Validate cache integrity
    private func validateCache() -> Bool {
        // Check for duplicate URLs with same hash
        var seen = Set<String>()
        for summary in cache.summaries {
            let key = "\(summary.url)_\(summary.contentHash)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
        }
        return true
    }
}

// MARK: - Shared Instance

extension SummaryCacheService {
    static let shared = SummaryCacheService()
}

// MARK: - Convenience Extensions

extension SummaryCacheService {
    /// Get human-readable cache size
    func getFormattedCacheSize() -> String {
        let size = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    /// Get cache age information
    func getCacheAgeInfo() -> (oldest: String?, newest: String?) {
        let stats = getCacheStats()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        let oldest = stats.oldestEntry.map { formatter.localizedString(for: $0, relativeTo: Date()) }
        let newest = stats.newestEntry.map { formatter.localizedString(for: $0, relativeTo: Date()) }

        return (oldest, newest)
    }

    /// Perform maintenance tasks (cleanup expired, validate integrity)
    func performMaintenance() async {
        await cleanExpiredEntries()

        if !validateCache() {
            print("Cache integrity check failed, rebuilding cache")
            // Remove duplicates
            var seen = Set<String>()
            var uniqueSummaries: [CachedSummary] = []

            for summary in cache.summaries {
                let key = "\(summary.url)_\(summary.contentHash)"
                if !seen.contains(key) {
                    seen.insert(key)
                    uniqueSummaries.append(summary)
                }
            }

            cache.summaries = uniqueSummaries
            await saveCache()
        }
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension SummaryCacheService {
    /// Debug method to print cache contents
    func debugPrintCache() {
        print("=== Cache Debug Info ===")
        print("Total entries: \(cache.summaries.count)")
        print("Cache size: \(getFormattedCacheSize())")

        for (index, summary) in cache.summaries.enumerated() {
            print("\n[\(index)] URL: \(summary.url)")
            print("  Hash: \(summary.contentHash.prefix(10))...")
            print("  Summary length: \(summary.summary.count) chars")
            print("  Age: \(Date().timeIntervalSince(summary.timestamp) / 3600) hours")
            print("  Expired: \(summary.isExpired)")
        }
        print("=====================")
    }

    /// Debug method to add test data
    func addTestData() async {
        for i in 1...5 {
            let testSummary = "This is test summary #\(i) with some content to demonstrate caching functionality."
            let testURL = URL(string: "https://example.com/article\(i)")!
            let testHash = generateContentHash("Test content \(i)")

            await cacheSummary(testSummary, for: testURL, contentHash: testHash)
        }
        print("Added 5 test cache entries")
    }
}
#endif