//
//  SpotlightTableViewDelegate.swift
//  Cloud
//
//  Protocol for handling keyboard events in SpotlightTableView
//

import Foundation

// MARK: - SpotlightTableViewDelegate
protocol SpotlightTableViewDelegate: AnyObject {
  func tableViewDidPressEscape(_ tableView: SpotlightTableView)
  func tableViewDidPressEnter(_ tableView: SpotlightTableView)
}
