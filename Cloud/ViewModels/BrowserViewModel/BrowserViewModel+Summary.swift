//
//  BrowserViewModel+Summary.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Extension handling AI page summarization and "Ask About Page" functionality.
//

import Foundation
import SwiftUI

// MARK: - Summary Methods
extension BrowserViewModel {

  @MainActor
  func summarizePage() async {
    guard let activeTab = tabs.first(where: { $0.id == activeTabId }),
      let webView = getWebView(for: activeTab.id)
    else {
      summaryError = "No active page to summarize"
      return
    }

    isAskMode = false
    askQuestion = ""

    // Reset cancellation flag
    isSummaryCancelled = false

    // Reset state
    isSummarizing = true
    summaryText = ""
    isSummaryComplete = false
    summaryError = nil
    summarizingStatus = "Extracting page content..."

    do {
      // Check for cancellation
      guard !isSummaryCancelled else { return }

      // Extract page content using JavaScript
      let pageContent =
        try await webView.evaluateJavaScript("document.body.innerText") as? String ?? ""

      guard !isSummaryCancelled else { return }

      guard !pageContent.isEmpty else {
        throw NSError(
          domain: "BrowserViewModel", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Page has no text content"])
      }

      // Clean content (remove excessive whitespace)
      let cleanedContent =
        pageContent
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")

      // Check for cancellation
      guard !isSummaryCancelled else { return }

      // Generate content hash for caching
      let contentHash = await cacheService.generateContentHash(cleanedContent)

      // Check cache first
      if let cachedSummary = await cacheService.getCachedSummary(
        for: activeTab.url, contentHash: contentHash)
      {
        guard !isSummaryCancelled else { return }
        summarizingStatus = "Loading cached summary..."
        summaryText = cachedSummary
        isSummaryComplete = true
        return
      }

      // Generate summary via API
      summarizingStatus = "Generating AI summary..."
      let stream = try await openAIService.streamSummary(for: cleanedContent)

      // Process streaming response with cancellation checks
      for try await chunk in stream {
        guard !isSummaryCancelled else { return }
        summaryText += chunk
      }

      // Check for cancellation before caching
      guard !isSummaryCancelled else { return }

      // Cache the generated summary
      await cacheService.cacheSummary(summaryText, for: activeTab.url, contentHash: contentHash)

      isSummaryComplete = true

    } catch let error as OpenAIError {
      if !isSummaryCancelled {
        summaryError = error.localizedDescription
        isSummarizing = false
      }
    } catch {
      if !isSummaryCancelled {
        summaryError = "Failed to generate summary: \(error.localizedDescription)"
        isSummarizing = false
      }
    }
  }

  @MainActor
  func askAboutPage(question: String) async {
    let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedQuestion.isEmpty else {
      summaryError = "Please enter a question about the page."
      return
    }

    guard let activeTab = tabs.first(where: { $0.id == activeTabId }),
      let webView = getWebView(for: activeTab.id)
    else {
      summaryError = "No active page to analyze"
      return
    }

    // Exit ask mode once the request starts (prevents stale badge)
    isAskMode = false
    askQuestion = trimmedQuestion

    // Reset cancellation flag
    isSummaryCancelled = false

    // Reset state
    isSummarizing = true
    summaryText = ""
    isSummaryComplete = false
    summaryError = nil
    summarizingStatus = "Extracting page content..."

    do {
      // Check for cancellation
      guard !isSummaryCancelled else { return }

      // Extract page content using JavaScript
      let pageContent =
        try await webView.evaluateJavaScript("document.body.innerText") as? String ?? ""

      guard !isSummaryCancelled else { return }

      guard !pageContent.isEmpty else {
        throw NSError(
          domain: "BrowserViewModel", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Page has no text content"])
      }

      // Clean content (remove excessive whitespace)
      let cleanedContent =
        pageContent
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")

      // Check for cancellation
      guard !isSummaryCancelled else { return }

      // Generate answer via API
      summarizingStatus = "Answering your question..."
      let stream = try await openAIService.streamAskAboutPage(
        content: cleanedContent, question: trimmedQuestion)

      // Process streaming response with cancellation checks
      for try await chunk in stream {
        guard !isSummaryCancelled else { return }
        summaryText += chunk
      }

      // Check for cancellation
      guard !isSummaryCancelled else { return }

      isSummaryComplete = true

    } catch let error as OpenAIError {
      if !isSummaryCancelled {
        summaryError = error.localizedDescription
        isSummarizing = false
      }
    } catch {
      if !isSummaryCancelled {
        summaryError = "Failed to generate answer: \(error.localizedDescription)"
        isSummarizing = false
      }
    }
  }

  func beginAskAboutPage(with question: String) {
    summaryTask = Task { [weak self] in
      guard let self = self else { return }
      await self.askAboutPage(question: question)
    }
  }

  @MainActor
  func restorePage() {
    // Set cancellation flag to stop any ongoing summary generation
    isSummaryCancelled = true
    summaryTask?.cancel()
    summaryTask = nil
    askQuestion = ""

    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
      isSummarizing = false
      summaryText = ""
      isSummaryComplete = false
      summaryError = nil
      summarizingStatus = ""
    }
  }
}
