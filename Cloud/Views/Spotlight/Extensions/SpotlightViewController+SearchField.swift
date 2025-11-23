//
//  SpotlightViewController+SearchField.swift
//  Cloud
//
//  NSSearchFieldDelegate implementation and search handling
//

import AppKit

// MARK: - NSSearchFieldDelegate
extension SpotlightViewController: NSSearchFieldDelegate {
  // Called on every keystroke - instant updates
  func controlTextDidChange(_ obj: Notification) {
    // Clear old suggestions immediately
    viewModel.suggestions = []

    viewModel.searchQuery = searchField.stringValue
    if viewModel.isAskMode {
      viewModel.askQuestion = searchField.stringValue
    }

    // In AI mode: clear results when query becomes empty (allows new search)
    if viewModel.isAISearchMode {
      if searchField.stringValue.isEmpty {
        viewModel.clearAIResults()
        updateResults()
      }
    } else {
      updateResults()
    }

    updateIcon()
    updateAskBadge()

    // Update inline autocomplete (not in AI mode)
    if !viewModel.isAISearchMode {
      updateInlineAutocomplete()
    }
  }

  func updateInlineAutocomplete() {
    let query = searchField.stringValue.lowercased()
    currentAutocomplete = ""

    guard !query.isEmpty && !viewModel.isAskMode else {
      return
    }

    // Don't autocomplete if query has spaces (it's a search, not URL)
    guard !query.contains(" ") else {
      return
    }

    // Check if we have results
    guard !searchResults.isEmpty else {
      return
    }

    // Find first history/tab/bookmark result (skip commands and search suggestions)
    let urlResult = searchResults.first { result in
      result.type == .history || result.type == .tab || result.type == .bookmark || result.type == .website
    }

    guard let firstResult = urlResult, let resultURL = firstResult.url else {
      return
    }

    let resultHost = resultURL.host?.lowercased() ?? ""

    // Check if domain starts with user's query (e.g., "linke" -> "linkedin.com")
    if resultHost.hasPrefix(query) && resultHost != query {
      let remainder = String(resultHost.dropFirst(query.count))
      if !remainder.isEmpty {
        currentAutocomplete = remainder
      }
    }
  }

  func applyAutocomplete() {
    guard !currentAutocomplete.isEmpty else {
      return
    }

    let currentQuery = searchField.stringValue
    searchField.stringValue = currentQuery + currentAutocomplete

    if let editor = searchField.currentEditor() as? NSTextView {
      editor.setSelectedRange(NSRange(location: searchField.stringValue.count, length: 0))
    }

    viewModel.searchQuery = searchField.stringValue
    updateResults()
    updateIcon()
    currentAutocomplete = ""
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
    -> Bool
  {
    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      handleEnter()
      return true
    } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
      // Escape - if in AI mode with results, clear results first
      if viewModel.isAISearchMode && !searchResults.isEmpty {
        viewModel.clearAIResults()
        updateResults()
        return true
      }
      close()
      return true
    } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
      if !currentAutocomplete.isEmpty {
        applyAutocomplete()
        return true
      }
      return false
    } else if commandSelector == #selector(NSResponder.moveRight(_:)) {
      let query = searchField.stringValue
      if !currentAutocomplete.isEmpty {
        let selectedRange = textView.selectedRange()
        if selectedRange.location == query.count {
          applyAutocomplete()
          return true
        }
      }
      return false
    } else if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
      // Backspace - exit Ask mode if field is empty
      if viewModel.isAskMode && searchField.stringValue.isEmpty {
        exitAskMode()
        return true
      }
      // Backspace - exit AI Search mode if field is empty
      if viewModel.isAISearchMode && searchField.stringValue.isEmpty {
        exitAISearchMode()
        return true
      }
      currentAutocomplete = ""
      return false
    } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
      if !searchResults.isEmpty {
        let currentRow = tableView.selectedRow
        let nextRow: Int

        if currentRow < 0 {
          nextRow = 0
        } else if currentRow < searchResults.count - 1 {
          nextRow = currentRow + 1
        } else {
          nextRow = currentRow
        }

        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
      }
      return true
    } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
      if !searchResults.isEmpty {
        let currentRow = tableView.selectedRow
        let previousRow: Int

        if currentRow < 0 {
          previousRow = searchResults.count - 1
        } else if currentRow > 0 {
          previousRow = currentRow - 1
        } else {
          previousRow = currentRow
        }

        tableView.selectRowIndexes(IndexSet(integer: previousRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(previousRow)
      }
      return true
    }
    return false
  }

  func handleEnter() {
    guard let viewModel = viewModel else { return }

    let query = searchField.stringValue

    // Ask mode - send question to AI
    if viewModel.isAskMode {
      let question = query.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !question.isEmpty else { return }

      viewModel.askQuestion = question
      viewModel.beginAskAboutPage(with: question)
      close()
      return
    }

    // AI Search mode - perform search or select result
    if viewModel.isAISearchMode {
      // Ignore Enter while search is in progress (thinking animation running)
      if thinkingTimer != nil {
        return
      }

      // If we have results and one is selected, navigate to it
      if !searchResults.isEmpty {
        let selectedRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        if let url = searchResults[selectedRow].url {
          viewModel.createNewTab(url: url)
          close()
          return
        }
      }

      // Otherwise, perform the AI search
      let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmedQuery.isEmpty {
        performAISearch(query: trimmedQuery)
      }
      return
    }

    // Normal mode
    let selectedRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0

    if !searchResults.isEmpty && selectedRow < searchResults.count {
      let selectedResult = searchResults[selectedRow]

      // Special handling: "Ask About WebPage"
      if selectedResult.type == .command && selectedResult.title == "Ask About WebPage" {
        viewModel.selectSearchResult(selectedResult)
        searchField.stringValue = ""
        viewModel.searchQuery = ""
        viewModel.askQuestion = ""
        updateResults()
        updateAskBadge()
        updateIcon()
        view.window?.makeFirstResponder(searchField)
        return
      }

      // Special handling: "Search History with AI"
      if selectedResult.type == .command && selectedResult.title == "Search History with AI" {
        viewModel.selectSearchResult(selectedResult)
        searchField.stringValue = ""
        viewModel.searchQuery = ""
        updateResults()
        updateAIBadge()
        updateIcon()
        view.window?.makeFirstResponder(searchField)
        return
      }

      viewModel.selectSearchResult(selectedResult)
      close()
      return
    }

    // Fallback: create synthetic result for direct navigation/search
    if !query.isEmpty {
      var urlString = query
      if !urlString.contains("://") {
        if urlString.contains(".") && !urlString.contains(" ") {
          urlString = "https://\(urlString)"
        } else {
          urlString =
            "https://www.google.com/search?q=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)"
        }
      }

      if let url = URL(string: urlString) {
        let syntheticResult = SearchResult(
          type: urlString.contains("google.com/search") ? .suggestion : .website,
          title: query,
          subtitle: urlString.contains("google.com/search") ? "Search Google" : "Open website",
          url: url
        )
        viewModel.selectSearchResult(syntheticResult)
      }
    }
    close()
  }

  // MARK: - AI Search

  func performAISearch(query: String) {
    // Show thinking indicator
    startThinkingAnimation()

    Task { @MainActor in
      do {
        let results = try await LocalRAGService.shared.semanticSearch(
          naturalQuery: query,
          limit: 10
        )

        // Stop thinking animation
        stopThinkingAnimation()

        // Check if we found any results
        if results.isEmpty {
          viewModel.setAIResults([
            SearchResult(
              type: .command,
              title: "Aucun résultat",
              subtitle: "Je n'ai trouvé aucun lien correspondant dans votre historique",
              url: nil
            )
          ])
        } else {
          // Convert to SearchResult and update
          viewModel.setAIResults(results.map { ragResult in
            SearchResult(
              type: .history,
              title: ragResult.document.title,
              subtitle: ragResult.document.url,
              url: URL(string: ragResult.document.url),
              matchScore: Int(ragResult.score * 100)
            )
          })
        }

        updateResults()

      } catch {
        stopThinkingAnimation()
        viewModel.setAIResults([
          SearchResult(
            type: .command,
            title: "Erreur",
            subtitle: "Une erreur s'est produite lors de la recherche",
            url: nil
          )
        ])
        updateResults()
        print("AI Search error: \(error)")
      }
    }
  }

  func startThinkingAnimation() {
    thinkingDots = 0
    updateThinkingDisplay()

    thinkingTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.thinkingDots = (self.thinkingDots + 1) % 4
      self.updateThinkingDisplay()
    }
  }

  func stopThinkingAnimation() {
    thinkingTimer?.invalidate()
    thinkingTimer = nil
  }

  func updateThinkingDisplay() {
    let dots = String(repeating: ".", count: thinkingDots)
    let spaces = String(repeating: " ", count: 3 - thinkingDots)

    viewModel.setAIResults([
      SearchResult(
        type: .command,
        title: "Searching\(dots)\(spaces)",
        subtitle: "Looking through your history...",
        url: nil
      )
    ])
    updateResults()
  }
}
