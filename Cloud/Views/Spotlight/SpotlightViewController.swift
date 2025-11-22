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
  var askBadgeContainer: NSView!
  var askBadgeLabel: NSTextField!
  var searchFieldLeadingToIcon: NSLayoutConstraint!
  var searchFieldLeadingToBadge: NSLayoutConstraint!
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
    updateAskBadge()

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

  private var wasInAskMode = false

  func updateAskBadge() {
    guard askBadgeContainer != nil,
      searchFieldLeadingToIcon != nil,
      searchFieldLeadingToBadge != nil else { return }

    let shouldShowBadge = viewModel?.isAskMode ?? false

    // Detect transition into Ask mode for glow animation
    let justEnteredAskMode = shouldShowBadge && !wasInAskMode
    wasInAskMode = shouldShowBadge

    askBadgeContainer.isHidden = !shouldShowBadge
    askBadgeContainer.alphaValue = shouldShowBadge ? 1 : 0
    searchField.placeholderString =
      shouldShowBadge ? "Ask something about this page..." : "Search or enter URL..."

    searchFieldLeadingToIcon.isActive = !shouldShowBadge
    searchFieldLeadingToBadge.isActive = shouldShowBadge

    view.layoutSubtreeIfNeeded()

    // Trigger glow animation when entering Ask mode
    if justEnteredAskMode {
      animateAskBadgeGlow()
    }
  }

  func animateAskBadgeGlow() {
    guard let layer = askBadgeContainer.layer else { return }

    // Create glow effect
    let glowColor = NSColor.systemPurple.withAlphaComponent(0.8).cgColor

    // Shadow glow animation
    let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
    shadowAnimation.fromValue = 0
    shadowAnimation.toValue = 1
    shadowAnimation.duration = 0.2
    shadowAnimation.autoreverses = true
    shadowAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

    let shadowRadiusAnimation = CABasicAnimation(keyPath: "shadowRadius")
    shadowRadiusAnimation.fromValue = 0
    shadowRadiusAnimation.toValue = 15
    shadowRadiusAnimation.duration = 0.2
    shadowRadiusAnimation.autoreverses = true
    shadowRadiusAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

    // Apply shadow properties
    layer.shadowColor = glowColor
    layer.shadowOffset = .zero
    layer.shadowOpacity = 0

    // Run animations
    layer.add(shadowAnimation, forKey: "glowOpacity")
    layer.add(shadowRadiusAnimation, forKey: "glowRadius")
  }

  func exitAskMode() {
    viewModel.isAskMode = false
    viewModel.askQuestion = ""
    searchField.stringValue = ""
    viewModel.searchQuery = ""
    updateAskBadge()
    updateIcon()
    updateResults()
  }

  func close() {
    viewModel.isSpotlightVisible = false
  }
}
