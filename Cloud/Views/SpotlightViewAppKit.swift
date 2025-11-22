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
    // Only sync search field if user is NOT actively typing (prevents character loss)
    let isUserTyping = nsViewController.searchField.currentEditor() != nil
    if !isUserTyping && nsViewController.searchField.stringValue != viewModel.searchQuery {
      nsViewController.searchField.stringValue = viewModel.searchQuery
    }

    nsViewController.updateIcon()
    nsViewController.updateAskBadge()

    // Update results when viewModel changes (e.g. suggestions loaded)
    nsViewController.updateResults()
  }
}
