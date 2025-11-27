//
//  TabCategorizationService.swift
//  Cloud
//
//  Service for AI-powered tab categorization using OpenAI.
//

import Foundation

// MARK: - Tab Categorization Error Types
enum TabCategorizationError: LocalizedError {
  case missingAPIKey
  case networkError(Error)
  case invalidResponse(String)
  case noTabsToCategories
  case invalidJSON(Error)

  var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      return "OpenAI API key not found. Please add your API key in Settings."
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    case .invalidResponse(let details):
      return "Invalid response from OpenAI: \(details)"
    case .noTabsToCategories:
      return "No tabs to categorize."
    case .invalidJSON(let error):
      return "Failed to parse response: \(error.localizedDescription)"
    }
  }
}

// MARK: - Response Models
struct TabCategoryResponse: Codable {
  let categories: [TabCategoryItem]
}

struct TabCategoryItem: Codable {
  let id: String
  let category: String
}

// MARK: - Tab Categorization Service
class TabCategorizationService {
  // MARK: - Constants
  private let endpoint = "https://api.openai.com/v1/chat/completions"
  private let model = "gpt-4o-mini"
  private let apiKeyUserDefaultsKey = "openai_api_key"

  // Valid categories
  static let validCategories = ["Email", "Social", "Shopping", "Work", "Entertainment", "News", "Other"]

  // MARK: - Public Methods

  /// Categorize tabs using AI
  /// - Parameter tabs: Array of BrowserTab to categorize
  /// - Returns: Dictionary mapping tab UUID to category string
  func categorizeTabsWithAI(tabs: [BrowserTab]) async throws -> [UUID: String] {
    guard !tabs.isEmpty else {
      throw TabCategorizationError.noTabsToCategories
    }

    let request = try buildRequest(for: tabs)
    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw TabCategorizationError.invalidResponse("No HTTP response")
    }

    switch httpResponse.statusCode {
    case 200:
      break
    case 401:
      throw TabCategorizationError.missingAPIKey
    case 400...499:
      throw TabCategorizationError.invalidResponse("Client error: \(httpResponse.statusCode)")
    case 500...599:
      throw TabCategorizationError.networkError(
        NSError(
          domain: "OpenAI",
          code: httpResponse.statusCode,
          userInfo: [NSLocalizedDescriptionKey: "Server error"]
        )
      )
    default:
      throw TabCategorizationError.invalidResponse("Unexpected status code: \(httpResponse.statusCode)")
    }

    return try parseResponse(data)
  }

  // MARK: - Private Methods

  /// Retrieve the API key from UserDefaults
  private func getAPIKey() throws -> String {
    guard let apiKey = UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey),
          !apiKey.isEmpty
    else {
      throw TabCategorizationError.missingAPIKey
    }
    return apiKey
  }

  /// Build the URLRequest for the OpenAI API
  private func buildRequest(for tabs: [BrowserTab]) throws -> URLRequest {
    let apiKey = try getAPIKey()

    // Build tab list for the prompt
    let tabsList = tabs.map { tab in
      ["id": tab.id.uuidString, "title": tab.title, "url": tab.url.absoluteString]
    }

    let tabsJSON = try JSONSerialization.data(withJSONObject: tabsList)
    let tabsString = String(data: tabsJSON, encoding: .utf8) ?? "[]"

    // Build request body with response_format for guaranteed JSON
    let requestBody: [String: Any] = [
      "model": model,
      "response_format": ["type": "json_object"],
      "messages": [
        [
          "role": "system",
          "content": """
            Tu es un assistant qui catégorise des onglets de navigateur. Réponds UNIQUEMENT en JSON valide avec le format: {"categories": [{"id": "uuid", "category": "CategoryName"}]}

            Les catégories valides sont: Email, Social, Shopping, Work, Entertainment, News, Other.

            Règles de catégorisation:
            - Email: Gmail, Outlook, Yahoo Mail, ProtonMail, etc.
            - Social: Facebook, Twitter/X, Instagram, LinkedIn, Reddit, TikTok, etc.
            - Shopping: Amazon, eBay, Etsy, boutiques en ligne, etc.
            - Work: Slack, Notion, Trello, Jira, Google Docs, outils professionnels, etc.
            - Entertainment: YouTube, Netflix, Spotify, Twitch, jeux, etc.
            - News: Journaux, sites d'actualités, blogs d'information, etc.
            - Other: Tout ce qui ne correspond pas aux autres catégories
            """
        ],
        [
          "role": "user",
          "content": "Catégorise ces onglets: \(tabsString)"
        ]
      ]
    ]

    guard let url = URL(string: endpoint) else {
      throw TabCategorizationError.invalidResponse("Invalid endpoint URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw TabCategorizationError.invalidJSON(error)
    }

    return request
  }

  /// Parse the OpenAI response and extract categories
  private func parseResponse(_ data: Data) throws -> [UUID: String] {
    // First, parse the OpenAI response wrapper
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let choices = json["choices"] as? [[String: Any]],
          let firstChoice = choices.first,
          let message = firstChoice["message"] as? [String: Any],
          let content = message["content"] as? String
    else {
      throw TabCategorizationError.invalidResponse("Could not parse OpenAI response structure")
    }

    // Parse the content JSON
    guard let contentData = content.data(using: .utf8) else {
      throw TabCategorizationError.invalidResponse("Could not convert content to data")
    }

    let categoryResponse: TabCategoryResponse
    do {
      categoryResponse = try JSONDecoder().decode(TabCategoryResponse.self, from: contentData)
    } catch {
      throw TabCategorizationError.invalidJSON(error)
    }

    // Convert to dictionary
    var result: [UUID: String] = [:]
    for item in categoryResponse.categories {
      if let uuid = UUID(uuidString: item.id) {
        // Validate category is in the allowed list
        let category = Self.validCategories.contains(item.category) ? item.category : "Other"
        result[uuid] = category
      }
    }

    return result
  }
}
