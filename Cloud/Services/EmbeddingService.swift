//
//  EmbeddingService.swift
//  Cloud
//
//  Service for generating text embeddings via OpenAI API
//  Used for semantic search in history, tabs, and bookmarks
//

import Foundation

// MARK: - Embedding Models

struct EmbeddingResponse: Codable {
    let object: String
    let data: [EmbeddingData]
    let model: String
    let usage: EmbeddingUsage
}

struct EmbeddingData: Codable {
    let object: String
    let index: Int
    let embedding: [Float]
}

struct EmbeddingUsage: Codable {
    let promptTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Embedding Error

enum EmbeddingError: LocalizedError {
    case missingAPIKey
    case networkError(Error)
    case invalidResponse(String)
    case rateLimitExceeded
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not found. Please add your API key in Settings."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let details):
            return "Invalid response: \(details)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait before trying again."
        case .emptyInput:
            return "Cannot generate embedding for empty text."
        }
    }
}

// MARK: - Embedding Service

class EmbeddingService {
    // MARK: - Constants

    private let endpoint = "https://api.openai.com/v1/embeddings"
    private let model = "text-embedding-3-small"
    private let dimensions = 512
    private let apiKeyUserDefaultsKey = "openai_api_key"
    private let maxInputLength = 8000

    // MARK: - Singleton

    static let shared = EmbeddingService()

    private init() {}

    // MARK: - Public Methods

    func generateEmbedding(for text: String) async throws -> [Float] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingError.emptyInput
        }

        let embeddings = try await generateEmbeddings(for: [text])
        guard let first = embeddings.first else {
            throw EmbeddingError.invalidResponse("No embedding returned")
        }
        return first
    }

    func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else {
            return []
        }

        let apiKey = try getAPIKey()

        let processedTexts = texts.map { text in
            if text.count > maxInputLength {
                return String(text.prefix(maxInputLength))
            }
            return text
        }

        let requestBody: [String: Any] = [
            "model": model,
            "input": processedTexts,
            "dimensions": dimensions
        ]

        guard let url = URL(string: endpoint) else {
            throw EmbeddingError.invalidResponse("Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw EmbeddingError.invalidResponse("Failed to serialize request")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmbeddingError.invalidResponse("No HTTP response")
            }

            switch httpResponse.statusCode {
            case 200:
                break
            case 401:
                throw EmbeddingError.missingAPIKey
            case 429:
                throw EmbeddingError.rateLimitExceeded
            default:
                throw EmbeddingError.invalidResponse("Status code: \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            let embeddingResponse = try decoder.decode(EmbeddingResponse.self, from: data)

            let sortedData = embeddingResponse.data.sorted { $0.index < $1.index }
            return sortedData.map { $0.embedding }

        } catch let error as EmbeddingError {
            throw error
        } catch {
            throw EmbeddingError.networkError(error)
        }
    }

    var isAvailable: Bool {
        guard let apiKey = UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey) else {
            return false
        }
        return !apiKey.isEmpty
    }

    // MARK: - Private Methods

    private func getAPIKey() throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey),
              !apiKey.isEmpty else {
            throw EmbeddingError.missingAPIKey
        }
        return apiKey
    }
}

// MARK: - Vector Math Extensions

extension EmbeddingService {
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    static func findTopK<T>(
        query: [Float],
        items: [(item: T, embedding: [Float])],
        k: Int
    ) -> [(item: T, score: Float)] {
        let scored = items.map { item in
            (item: item.item, score: cosineSimilarity(query, item.embedding))
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(k)
            .map { $0 }
    }
}
