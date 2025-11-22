//
//  SpotlightViewAppKit.swift
//  Cloud
//
//  SwiftUI wrapper for AppKit-based Spotlight
//

import SwiftUI

struct SpotlightViewAppKit: NSViewControllerRepresentable {
  @ObservedObject var viewModel: BrowserViewModel

  func makeNSViewController(context: Context) -> SpotlightViewController {
    let controller = SpotlightViewController()
    controller.viewModel = viewModel
    return controller
  }

  func updateNSViewController(_ nsViewController: SpotlightViewController, context: Context) {
    // Sync search field with viewModel (fixes stale query bug when reopening)
    nsViewController.searchField.stringValue = viewModel.searchQuery
    nsViewController.updateIcon()

    // Update results when viewModel changes (e.g. suggestions loaded)
    nsViewController.updateResults()
  }
}
