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
    // Clear old suggestions immediately so "Search Google" appears instantly
    viewModel.suggestions = []

    viewModel.searchQuery = searchField.stringValue
    if viewModel.isAskMode {
      viewModel.askQuestion = searchField.stringValue
    }
    updateResults()
    updateIcon()
    updateAskBadge()

    // Update inline autocomplete
    updateInlineAutocomplete()
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
      // Extract the remainder after what user typed
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

    // Move cursor to end
    if let editor = searchField.currentEditor() as? NSTextView {
      editor.setSelectedRange(NSRange(location: searchField.stringValue.count, length: 0))
    }

    // Update everything
    viewModel.searchQuery = searchField.stringValue
    updateResults()
    updateIcon()
    currentAutocomplete = ""
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
    -> Bool
  {
    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      // Enter key
      handleEnter()
      return true
    } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
      // Escape key
      close()
      return true
    } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
      // Tab key - accept autocomplete
      if !currentAutocomplete.isEmpty {
        applyAutocomplete()
        return true
      }
      return false
    } else if commandSelector == #selector(NSResponder.moveRight(_:)) {
      // Right arrow - accept autocomplete if at end of text
      let query = searchField.stringValue
      if let editor = textView as? NSTextView, !currentAutocomplete.isEmpty {
        let selectedRange = editor.selectedRange
        if selectedRange.location == query.count {
          // Cursor is at end, accept autocomplete
          applyAutocomplete()
          return true
        }
      }
      return false
    } else if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
      // Backspace key - exit Ask mode if field is empty
      if viewModel.isAskMode && searchField.stringValue.isEmpty {
        exitAskMode()
        return true
      }
      // Clear autocomplete on backspace
      currentAutocomplete = ""
      return false
    } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
      // Down arrow - navigate table while keeping focus in search field (Arc-style)
      if !searchResults.isEmpty {
        let currentRow = tableView.selectedRow
        let nextRow: Int

        if currentRow < 0 {
          // No selection yet, select first row
          nextRow = 0
        } else if currentRow < searchResults.count - 1 {
          // Move to next row
          nextRow = currentRow + 1
        } else {
          // Already at last row, stay there
          nextRow = currentRow
        }

        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
        // Focus stays in searchField automatically
      }
      return true
    } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
      // Up arrow - navigate table while keeping focus in search field (Arc-style)
      if !searchResults.isEmpty {
        let currentRow = tableView.selectedRow
        let previousRow: Int

        if currentRow < 0 {
          // No selection yet, select last row
          previousRow = searchResults.count - 1
        } else if currentRow > 0 {
          // Move to previous row
          previousRow = currentRow - 1
        } else {
          // Already at first row, stay there
          previousRow = currentRow
        }

        tableView.selectRowIndexes(IndexSet(integer: previousRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(previousRow)
        // Focus stays in searchField automatically
      }
      return true
    }
    return false
  }

  func handleEnter() {
    guard let viewModel = viewModel else { return }

    let query = searchField.stringValue

    // If Ask mode is active, bypass normal navigation and send question to OpenAI
    if viewModel.isAskMode {
      let question = query.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !question.isEmpty else { return }

      viewModel.askQuestion = question
      viewModel.beginAskAboutPage(with: question)
      close()
      return
    }

    // Get selected row, default to first row (0) if nothing selected
    let selectedRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0

    // If we have results, use the selected one
    if !searchResults.isEmpty && selectedRow < searchResults.count {
      let selectedResult = searchResults[selectedRow]

      // Special handling: "Ask About WebPage" should keep Spotlight open to capture the question
      if selectedResult.type == .command && selectedResult.title == "Ask About WebPage" {
        viewModel.selectSearchResult(selectedResult)
        searchField.stringValue = ""
        viewModel.searchQuery = ""
        viewModel.askQuestion = ""
        updateResults()
        updateAskBadge()
        updateIcon()
        view.window?.makeFirstResponder(searchField)
        searchField.currentEditor()?.selectAll(nil)
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
}
