//
//  SpotlightTableView.swift
//  Cloud
//
//  Custom table view with keyboard navigation and hover tracking
//

import AppKit

// MARK: - SpotlightTableView
class SpotlightTableView: NSTableView {
  enum Edge {
    case top, bottom
  }

  weak var spotlightDelegate: SpotlightTableViewDelegate?
  private var trackingArea: NSTrackingArea?

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let existing = trackingArea {
      removeTrackingArea(existing)
    }

    trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
      owner: self,
      userInfo: nil
    )

    if let trackingArea = trackingArea {
      addTrackingArea(trackingArea)
    }
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)

    let point = convert(event.locationInWindow, from: nil)

    // Update hover on row
    let row = self.row(at: point)
    if row >= 0 {
      selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let row = self.row(at: point)

    if row >= 0 {
      // Select the row
      selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
      // Trigger navigation immediately
      spotlightDelegate?.tableViewDidPressEnter(self)
    } else {
      super.mouseDown(with: event)
    }
  }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 126:  // Up arrow
      if selectedRow > 0 {
        selectRowIndexes(IndexSet(integer: selectedRow - 1), byExtendingSelection: false)
        scrollRowToVisible(selectedRow)
      }
    case 125:  // Down arrow
      if selectedRow < numberOfRows - 1 {
        selectRowIndexes(IndexSet(integer: selectedRow + 1), byExtendingSelection: false)
        scrollRowToVisible(selectedRow)
      }
    case 53:  // Escape
      spotlightDelegate?.tableViewDidPressEscape(self)
    case 36:  // Enter
      spotlightDelegate?.tableViewDidPressEnter(self)
    default:
      super.keyDown(with: event)
    }
  }
}
