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
  var iconImageView: NSImageView!
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

    // Sync text from viewModel
    searchField.stringValue = viewModel.searchQuery

    // Update icon based on context
    updateIcon()

    // Auto-focus search field and select all text
    view.window?.makeFirstResponder(searchField)

    // Force selection with a slight delay to ensure focus is ready
    DispatchQueue.main.async { [weak self] in
      self?.searchField.currentEditor()?.selectAll(nil)
    }
  }

  func updateIcon() {
    if let activeTab = viewModel.activeTab,
      !viewModel.searchQuery.isEmpty,
      viewModel.searchQuery == activeTab.url.absoluteString
    {

      // We are editing the current URL -> Show Tab Favicon
      if let favicon = activeTab.favicon {
        iconImageView.image = favicon
        iconImageView.contentTintColor = nil
      } else {
        iconImageView.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        iconImageView.contentTintColor = .secondaryLabelColor
      }
    } else {
      // Regular search -> Show Magnifying Glass
      iconImageView.image = NSImage(
        systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
      iconImageView.contentTintColor = .secondaryLabelColor
    }
  }

  func close() {
    viewModel.isSpotlightVisible = false
  }
}
