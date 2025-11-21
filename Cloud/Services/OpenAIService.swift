import Foundation

// MARK: - OpenAI Error Types
enum OpenAIError: LocalizedError {
  case missingAPIKey
  case networkError(Error)
  case invalidResponse(String)
  case rateLimitExceeded
  case tokenLimitExceeded
  case streamingError(String)
  case invalidJSON(Error)

  var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      return "OpenAI API key not found. Please add your API key in Settings."
    case .networkError(let error):
      return
        "Network error: \(error.localizedDescription). Please check your connection and try again."
    case .invalidResponse(let details):
      return "Invalid response from OpenAI: \(details)"
    case .rateLimitExceeded:
      return "Rate limit exceeded. Please wait a moment before trying again."
    case .tokenLimitExceeded:
      return "Token limit exceeded. The content has been truncated."
    case .streamingError(let details):
      return "Streaming error: \(details)"
    case .invalidJSON(let error):
      return "Failed to parse response: \(error.localizedDescription)"
    }
  }
}

// MARK: - OpenAI Service
class OpenAIService {
  // MARK: - Constants
  private let endpoint = "https://api.openai.com/v1/chat/completions"
  private let model = "gpt-5-nano"
  private let maxInputLength = 100_000
  private let maxCompletionTokens = 4000
  private let reasoningEffort = "low"  // "low" | "medium" | "high"
  private let apiKeyUserDefaultsKey = "openai_api_key"

  // MARK: - Public Methods

  /// Stream a summary of the provided text using OpenAI's GPT-5-nano model
  /// - Parameter text: The text content to summarize
  /// - Returns: An async stream that yields summary text chunks progressively
  func streamSummary(for text: String) async throws -> AsyncThrowingStream<String, Error> {
    let request = try buildRequest(for: text)

    return AsyncThrowingStream { continuation in
      Task {
        do {
          let (bytes, response) = try await URLSession.shared.bytes(for: request)

          // Check HTTP response
          guard let httpResponse = response as? HTTPURLResponse else {
            continuation.finish(throwing: OpenAIError.invalidResponse("No HTTP response"))
            return
          }

          // Handle HTTP errors
          switch httpResponse.statusCode {
          case 200:
            break  // Success, continue processing
          case 401:
            continuation.finish(throwing: OpenAIError.missingAPIKey)
            return
          case 429:
            continuation.finish(throwing: OpenAIError.rateLimitExceeded)
            return
          case 400...499:
            continuation.finish(
              throwing: OpenAIError.invalidResponse("Client error: \(httpResponse.statusCode)"))
            return
          case 500...599:
            continuation.finish(
              throwing: OpenAIError.networkError(
                NSError(
                  domain: "OpenAI", code: httpResponse.statusCode,
                  userInfo: [NSLocalizedDescriptionKey: "Server error"])))
            return
          default:
            continuation.finish(
              throwing: OpenAIError.invalidResponse(
                "Unexpected status code: \(httpResponse.statusCode)"))
            return
          }

          // Process streaming response
          var buffer = ""

          for try await line in bytes.lines {
            // Handle SSE format
            if line.hasPrefix("data: ") {
              let data = String(line.dropFirst(6))

              // Check for stream termination
              if data == "[DONE]" {
                continuation.finish()
                return
              }

              // Parse JSON chunk
              if let content = try self.parseStreamLine(data) {
                continuation.yield(content)
              }
            }
            // Handle potential buffered data
            else if !line.isEmpty && !line.hasPrefix(":") {
              buffer += line
              if buffer.hasPrefix("data: ") {
                let data = String(buffer.dropFirst(6))
                if let content = try self.parseStreamLine(data) {
                  continuation.yield(content)
                }
                buffer = ""
              }
            }
          }

          continuation.finish()

        } catch {
          // Handle errors during streaming
          if error is OpenAIError {
            continuation.finish(throwing: error)
          } else {
            continuation.finish(throwing: OpenAIError.networkError(error))
          }
        }
      }
    }
  }

  // MARK: - Private Methods

  /// Retrieve the API key from UserDefaults
  private func getAPIKey() throws -> String {
    guard let apiKey = UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey),
      !apiKey.isEmpty
    else {
      throw OpenAIError.missingAPIKey
    }
    return apiKey
  }

  /// Build the URLRequest for the OpenAI API
  private func buildRequest(for text: String) throws -> URLRequest {
    let apiKey = try getAPIKey()

    // Prepare text (truncate if necessary)
    let processedText: String
    var truncationNote = ""

    if text.count > maxInputLength {
      processedText = String(text.prefix(maxInputLength))
      truncationNote = "\n\nNote: Content was truncated to \(maxInputLength) characters."
    } else {
      processedText = text
    }

    // Build request body
    let requestBody: [String: Any] = [
      "model": model,
      "messages": [
        [
          "role": "system",
          "content":
            "You are a helpful assistant that summarizes web page content concisely. Focus on the key points and main ideas.",
        ],
        [
          "role": "user",
          "content":
            "Please summarize the following web page content:\n\n\(processedText)\(truncationNote)",
        ],
      ],
      "stream": true,
      "max_completion_tokens": maxCompletionTokens,
      "reasoning_effort": reasoningEffort,
    ]

    // Create request
    guard let url = URL(string: endpoint) else {
      throw OpenAIError.invalidResponse("Invalid endpoint URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Serialize JSON body
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw OpenAIError.invalidJSON(error)
    }

    return request
  }

  /// Parse a single line from the SSE stream
  /// - Parameter line: The JSON string from the stream
  /// - Returns: The content text if available, nil otherwise
  private func parseStreamLine(_ line: String) throws -> String? {
    guard let data = line.data(using: .utf8) else {
      return nil
    }

    do {
      if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let choices = json["choices"] as? [[String: Any]],
        let firstChoice = choices.first,
        let delta = firstChoice["delta"] as? [String: Any],
        let content = delta["content"] as? String
      {
        return content
      }

      // Check for error message in response
      if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let error = json["error"] as? [String: Any],
        let message = error["message"] as? String
      {

        // Check for specific error types
        if let type = error["type"] as? String {
          switch type {
          case "insufficient_quota":
            throw OpenAIError.rateLimitExceeded
          case "tokens_exceeded":
            throw OpenAIError.tokenLimitExceeded
          default:
            throw OpenAIError.streamingError(message)
          }
        } else {
          throw OpenAIError.streamingError(message)
        }
      }

      return nil

    } catch let error as OpenAIError {
      throw error
    } catch {
      // Only throw parsing errors for non-empty, non-whitespace lines
      if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw OpenAIError.invalidJSON(error)
      }
      return nil
    }
  }
}

// MARK: - Convenience Extensions
extension OpenAIService {
  /// Check if the API key is configured
  var isAPIKeyConfigured: Bool {
    guard let apiKey = UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey) else {
      return false
    }
    return !apiKey.isEmpty
  }

  /// Validate the API key format (basic check)
  func validateAPIKey(_ key: String) -> Bool {
    // OpenAI API keys typically start with "sk-" and have a specific length
    // This is a basic validation - actual validation happens when making API calls
    return key.hasPrefix("sk-") && key.count > 20
  }

  /// Save API key to UserDefaults
  func saveAPIKey(_ key: String) {
    UserDefaults.standard.set(key, forKey: apiKeyUserDefaultsKey)
  }

  /// Remove API key from UserDefaults
  func removeAPIKey() {
    UserDefaults.standard.removeObject(forKey: apiKeyUserDefaultsKey)
  }
}
