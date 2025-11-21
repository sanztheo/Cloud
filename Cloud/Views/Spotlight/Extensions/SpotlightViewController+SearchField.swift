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

    // Always create a new tab when opening from Spotlight (Arc-style)
    if searchResults.isEmpty || (query.contains(".") && !query.contains(" ")) {
      // Create synthetic result to ensure new tab creation
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
          type: .website,
          title: query,
          subtitle: "Open website",
          url: url
        )
        viewModel.selectSearchResult(syntheticResult)
      }
      close()
    } else {
      let selectedRow = tableView.selectedRow
      if selectedRow >= 0 && selectedRow < searchResults.count {
        viewModel.selectSearchResult(searchResults[selectedRow])
      }
    }
  }
}
