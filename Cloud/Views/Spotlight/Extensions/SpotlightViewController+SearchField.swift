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
      // Down arrow - move to table view
      if !searchResults.isEmpty {
        view.window?.makeFirstResponder(tableView)
        if tableView.selectedRow < 0 {
          tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        tableView.scrollRowToVisible(tableView.selectedRow)
      }
      return true
    } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
      // Up arrow - move to table view (select last item)
      if !searchResults.isEmpty {
        view.window?.makeFirstResponder(tableView)
        let lastRow = searchResults.count - 1
        if tableView.selectedRow < 0 {
          tableView.selectRowIndexes(IndexSet(integer: lastRow), byExtendingSelection: false)
        }
        tableView.scrollRowToVisible(tableView.selectedRow)
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
