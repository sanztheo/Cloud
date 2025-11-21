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

    // Check if query looks like a URL (contains dot and no spaces)
    if query.contains(".") && !query.contains(" ") {
      viewModel.navigateToAddress(query)
      close()
      return
    }

    if searchResults.isEmpty {
      viewModel.navigateToAddress(query)
      close()
    } else {
      let selectedRow = tableView.selectedRow
      if selectedRow >= 0 && selectedRow < searchResults.count {
        viewModel.selectSearchResult(searchResults[selectedRow])
      }
    }
  }
}
