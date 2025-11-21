//
//  SpotlightViewController+DataSource.swift
//  Cloud
//
//  NSTableViewDataSource implementation for SpotlightViewController
//

import AppKit

// MARK: - NSTableViewDataSource
extension SpotlightViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    return searchResults.count
  }
}
