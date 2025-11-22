//
//  SpotlightViewController+Delegate.swift
//  Cloud
//
//  Delegate implementations for SpotlightViewController
//

import AppKit
import SwiftUI

// MARK: - NSTableViewDelegate
extension SpotlightViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    let identifier = NSUserInterfaceItemIdentifier("SpotlightCell")

    var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? SpotlightCellView
    if cellView == nil {
      cellView = SpotlightCellView()
      cellView?.identifier = identifier
    }

    let result = searchResults[row]
    let isSelected = tableView.selectedRow == row

    // Get theme color from active space
    let themeColor: NSColor? = {
      guard let space = viewModel.activeSpace else { return nil }
      return NSColor(space.color)
    }()

    cellView?.configure(with: result, isSelected: isSelected, themeColor: themeColor)

    return cellView
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    // Reload visible cells to update selection state
    let visibleRows = tableView.rows(in: tableView.visibleRect)
    tableView.reloadData(
      forRowIndexes: IndexSet(integersIn: visibleRows.lowerBound..<visibleRows.upperBound),
      columnIndexes: IndexSet(integer: 0))
  }
}

// MARK: - SpotlightTableViewDelegate
extension SpotlightViewController: SpotlightTableViewDelegate {
  func tableViewDidPressEscape(_ tableView: SpotlightTableView) {
    close()
  }

  func tableViewDidPressEnter(_ tableView: SpotlightTableView) {
    handleEnter()
  }
}
