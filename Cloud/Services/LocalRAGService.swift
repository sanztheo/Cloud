//
//  LocalRAGService.swift
//  Cloud
//
//  Local RAG (Retrieval Augmented Generation) service for semantic search
//  Stores embeddings locally and performs similarity-based retrieval
//

import CryptoKit
import Foundation

// MARK: - RAG Item Types

enum RAGItemType: String, Codable {
    case history
    case tab
    case bookmark
}

// MARK: - RAG Document

struct RAGDocument: Codable, Identifiable {
    let id: String
    let type: RAGItemType
    let url: String
    let title: String
    let content: String
    let embedding: [Float]
    let timestamp: Date
    let metadata: RAGMetadata

    var isExpired: Bool {
        let expirationDays: Double = type == .history ? 7 : 30
        return Date().timeIntervalSince(timestamp) > (expirationDays * 86400)
    }
}

struct RAGMetadata: Codable {
    var visitCount: Int?
    var lastVisited: Date?
    var spaceId: String?
    var isPinned: Bool?
}

// MARK: - RAG Search Result

struct RAGSearchResult: Identifiable {
    let id: String
    let document: RAGDocument
    let score: Float
    let matchReason: String

    var isHighRelevance: Bool { score > 0.75 }
    var isMediumRelevance: Bool { score > 0.5 && score <= 0.75 }
}

// MARK: - RAG Index Container

struct RAGIndexContainer: Codable {
    var documents: [RAGDocument] = []
    var lastUpdated: Date = Date()
    var version: Int = 1
}

// MARK: - Local RAG Service

actor LocalRAGService {
    // MARK: - Constants

    private static let maxDocuments = 1000
    private static let indexFileName = "rag_index.json"
    private static let applicationName = "Cloud"
    private static let minSimilarityThreshold: Float = 0.3

    // MARK: - Properties

    private var index: RAGIndexContainer = RAGIndexContainer()
    private let fileManager = FileManager.default
    private let indexFileURL: URL
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let embeddingService = EmbeddingService.shared

    // MARK: - Singleton

    static let shared = LocalRAGService()

    // MARK: - Initialization

    init() {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent(Self.applicationName)
        self.indexFileURL = appDirectory.appendingPathComponent(Self.indexFileName)

        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)

        jsonEncoder.outputFormatting = [.sortedKeys]
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonDecoder.dateDecodingStrategy = .iso8601

        Task {
            await loadIndex()
            await cleanExpiredDocuments()
        }
    }

    // MARK: - Public Methods

    func indexHistoryEntry(_ entry: HistoryEntry) async throws {
        let content = buildSearchableContent(title: entry.title, url: entry.url.absoluteString)
        let documentId = generateDocumentId(url: entry.url.absoluteString, type: .history)

        if let existing = index.documents.first(where: { $0.id == documentId }) {
            if existing.content == content {
                await updateDocumentTimestamp(documentId)
                return
            }
        }

        let embedding = try await embeddingService.generateEmbedding(for: content)

        let document = RAGDocument(
            id: documentId,
            type: .history,
            url: entry.url.absoluteString,
            title: entry.title,
            content: content,
            embedding: embedding,
            timestamp: entry.visitDate,
            metadata: RAGMetadata(visitCount: 1, lastVisited: entry.visitDate)
        )

        await addOrUpdateDocument(document)
    }

    func indexHistoryBatch(_ entries: [HistoryEntry]) async throws {
        guard !entries.isEmpty else { return }

        let newEntries = entries.filter { entry in
            let docId = generateDocumentId(url: entry.url.absoluteString, type: .history)
            return !index.documents.contains { $0.id == docId }
        }

        guard !newEntries.isEmpty else { return }

        let contents = newEntries.map { buildSearchableContent(title: $0.title, url: $0.url.absoluteString) }
        let embeddings = try await embeddingService.generateEmbeddings(for: contents)

        for (entry, embedding) in zip(newEntries, embeddings) {
            let documentId = generateDocumentId(url: entry.url.absoluteString, type: .history)
            let content = buildSearchableContent(title: entry.title, url: entry.url.absoluteString)

            let document = RAGDocument(
                id: documentId,
                type: .history,
                url: entry.url.absoluteString,
                title: entry.title,
                content: content,
                embedding: embedding,
                timestamp: entry.visitDate,
                metadata: RAGMetadata(visitCount: 1, lastVisited: entry.visitDate)
            )

            index.documents.removeAll { $0.id == documentId }
            index.documents.append(document)
        }

        await enforceDocumentLimit()
        await saveIndex()

        print("✅ Indexed \(newEntries.count) history entries for RAG")
    }

    func search(query: String, limit: Int = 10, types: [RAGItemType]? = nil) async throws -> [RAGSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let queryEmbedding = try await embeddingService.generateEmbedding(for: query)

        var filteredDocs = index.documents
        if let types = types {
            filteredDocs = filteredDocs.filter { types.contains($0.type) }
        }

        let results = filteredDocs.compactMap { doc -> RAGSearchResult? in
            let score = EmbeddingService.cosineSimilarity(queryEmbedding, doc.embedding)
            guard score >= Self.minSimilarityThreshold else { return nil }

            return RAGSearchResult(
                id: doc.id,
                document: doc,
                score: score,
                matchReason: generateMatchReason(query: query, document: doc, score: score)
            )
        }

        return results.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    func semanticSearch(naturalQuery: String, limit: Int = 10) async throws -> [RAGSearchResult] {
        let intent = detectQueryIntent(naturalQuery)

        var typeFilter: [RAGItemType]? = nil
        if intent.contains(.tabs) && !intent.contains(.history) && !intent.contains(.bookmarks) {
            typeFilter = [.tab]
        } else if intent.contains(.history) && !intent.contains(.tabs) && !intent.contains(.bookmarks) {
            typeFilter = [.history]
        } else if intent.contains(.bookmarks) && !intent.contains(.tabs) && !intent.contains(.history) {
            typeFilter = [.bookmark]
        }

        return try await search(query: naturalQuery, limit: limit, types: typeFilter)
    }

    func getStats() -> (total: Int, history: Int, tabs: Int, bookmarks: Int) {
        let history = index.documents.filter { $0.type == .history }.count
        let tabs = index.documents.filter { $0.type == .tab }.count
        let bookmarks = index.documents.filter { $0.type == .bookmark }.count
        return (index.documents.count, history, tabs, bookmarks)
    }

    func clearIndex() async {
        index.documents.removeAll()
        index.lastUpdated = Date()
        await saveIndex()
    }

    var isAvailable: Bool {
        embeddingService.isAvailable
    }

    func getFormattedStats() -> String {
        let stats = getStats()
        return "Total: \(stats.total) | History: \(stats.history) | Tabs: \(stats.tabs) | Bookmarks: \(stats.bookmarks)"
    }

    // MARK: - Private Methods

    private func buildSearchableContent(title: String, url: String) -> String {
        let urlComponents = URLComponents(string: url)
        let domain = urlComponents?.host ?? ""
        let pathKeywords = urlComponents?.path
            .components(separatedBy: CharacterSet(charactersIn: "/-_"))
            .filter { !$0.isEmpty && $0.count > 2 }
            .joined(separator: " ") ?? ""

        return "\(title) \(domain) \(pathKeywords)"
    }

    private func generateDocumentId(url: String, type: RAGItemType) -> String {
        let data = Data("\(type.rawValue):\(url)".utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func addOrUpdateDocument(_ document: RAGDocument) async {
        index.documents.removeAll { $0.id == document.id }
        index.documents.append(document)
        index.lastUpdated = Date()

        await enforceDocumentLimit()
        await saveIndex()
    }

    private func updateDocumentTimestamp(_ documentId: String) async {
        guard let idx = index.documents.firstIndex(where: { $0.id == documentId }) else { return }

        var doc = index.documents[idx]
        var metadata = doc.metadata
        metadata.lastVisited = Date()
        metadata.visitCount = (metadata.visitCount ?? 0) + 1

        let updated = RAGDocument(
            id: doc.id,
            type: doc.type,
            url: doc.url,
            title: doc.title,
            content: doc.content,
            embedding: doc.embedding,
            timestamp: Date(),
            metadata: metadata
        )

        index.documents[idx] = updated
        await saveIndex()
    }

    private func enforceDocumentLimit() async {
        guard index.documents.count > Self.maxDocuments else { return }

        index.documents.sort { $0.timestamp < $1.timestamp }
        let excess = index.documents.count - Self.maxDocuments
        index.documents.removeFirst(excess)

        print("Removed \(excess) old documents to enforce limit")
    }

    private func cleanExpiredDocuments() async {
        let originalCount = index.documents.count
        index.documents.removeAll { $0.isExpired }

        if index.documents.count < originalCount {
            await saveIndex()
            print("Cleaned \(originalCount - index.documents.count) expired documents")
        }
    }

    private func generateMatchReason(query: String, document: RAGDocument, score: Float) -> String {
        let queryWords = query.lowercased().components(separatedBy: .whitespaces)
        let titleWords = document.title.lowercased().components(separatedBy: .whitespaces)

        let matchingWords = queryWords.filter { qw in
            titleWords.contains { tw in tw.contains(qw) || qw.contains(tw) }
        }

        if !matchingWords.isEmpty {
            return "Matches: \(matchingWords.joined(separator: ", "))"
        }

        if score > 0.8 { return "High semantic similarity" }
        else if score > 0.6 { return "Related content" }
        else { return "Possible match" }
    }

    // MARK: - Query Intent Detection

    private enum QueryIntent {
        case tabs, history, bookmarks, temporal, topic
    }

    private func detectQueryIntent(_ query: String) -> Set<QueryIntent> {
        var intents: Set<QueryIntent> = []
        let lower = query.lowercased()

        let tabKeywords = ["tab", "onglet", "ouvert", "open", "current"]
        if tabKeywords.contains(where: { lower.contains($0) }) { intents.insert(.tabs) }

        let historyKeywords = ["lu", "visité", "visited", "read", "hier", "yesterday", "semaine", "week", "passé", "ago", "history", "historique"]
        if historyKeywords.contains(where: { lower.contains($0) }) { intents.insert(.history) }

        let bookmarkKeywords = ["bookmark", "favori", "saved", "enregistré", "sauvé"]
        if bookmarkKeywords.contains(where: { lower.contains($0) }) { intents.insert(.bookmarks) }

        if intents.isEmpty { intents.insert(.topic) }

        return intents
    }

    // MARK: - Persistence

    private func loadIndex() {
        guard fileManager.fileExists(atPath: indexFileURL.path) else {
            print("No RAG index found, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: indexFileURL)
            index = try jsonDecoder.decode(RAGIndexContainer.self, from: data)
            print("Loaded RAG index with \(index.documents.count) documents")
        } catch {
            print("Failed to load RAG index: \(error)")
            index = RAGIndexContainer()
        }
    }

    private func saveIndex() async {
        do {
            let data = try jsonEncoder.encode(index)
            let tempURL = indexFileURL.appendingPathExtension("tmp")
            try data.write(to: tempURL)

            if fileManager.fileExists(atPath: indexFileURL.path) {
                _ = try fileManager.replaceItem(at: indexFileURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
            } else {
                try fileManager.moveItem(at: tempURL, to: indexFileURL)
            }
        } catch {
            print("Failed to save RAG index: \(error)")
        }
    }
}
