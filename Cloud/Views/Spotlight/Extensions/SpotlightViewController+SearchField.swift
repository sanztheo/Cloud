//
//  SpotlightViewController+SearchField.swift
//  Cloud
//
//  NSSearchFieldDelegate implementation and search handling
//

import AppKit

// MARK: - NSSearchFieldDelegate
extension SpotlightViewController: NSSearchFieldDelegate {
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
    } else if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
      // Backspace key - exit Ask mode if field is empty
      if viewModel.isAskMode && searchField.stringValue.isEmpty {
        exitAskMode()
        return true
      }
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
