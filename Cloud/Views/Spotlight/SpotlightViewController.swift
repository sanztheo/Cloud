//
//  SpotlightViewController.swift
//  Cloud
//
//  AppKit-based Spotlight implementation with proper keyboard and hover handling
//

import AppKit

class SpotlightViewController: NSViewController {
  var viewModel: BrowserViewModel!

  var searchField: NSSearchField!
  var tableView: SpotlightTableView!
  var scrollView: NSScrollView!
  var containerView: NSVisualEffectView!
  var searchResults: [SearchResult] = []

  override func loadView() {
    let rootView = SpotlightRootView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    rootView.onMouseDown = { [weak self] in
      self?.close()
    }
    view = rootView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    updateResults()
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    // Auto-focus search field
    view.window?.makeFirstResponder(searchField)
  }

  func close() {
    viewModel.isSpotlightVisible = false
  }
}
