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
  var aiBadgeContainer: NSView!
  var aiBadgeLabel: NSTextField!
  var aiLoadingIndicator: NSProgressIndicator!
  var searchFieldLeadingToIcon: NSLayoutConstraint!
  var searchFieldLeadingToBadge: NSLayoutConstraint!
  var searchFieldLeadingToAIBadge: NSLayoutConstraint!
  var tableView: SpotlightTableView!
  var scrollView: NSScrollView!
  var containerView: NSVisualEffectView!
  var autocompleteLabel: NSTextField!
  var searchResults: [SearchResult] = []

  var currentAutocomplete: String = "" {
    didSet {
      updateAutocompleteDisplay()
    }
  }

  // AI Search thinking animation
  var thinkingTimer: Timer?
  var thinkingDots: Int = 0

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
    updateAIBadge()

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
  private var wasInAIMode = false

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
    guard let layer = containerView.layer else { return }

    // Store original shadow properties
    let originalShadowColor = layer.shadowColor
    let originalShadowOpacity = layer.shadowOpacity
    let originalShadowRadius = layer.shadowRadius

    // Create purple glow effect on the Spotlight container
    let glowColor = NSColor.systemPurple.cgColor

    // Temporarily set to glow state
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.shadowColor = glowColor
    layer.shadowOpacity = 1.0
    layer.shadowRadius = 60
    layer.shadowOffset = .zero
    CATransaction.commit()

    // Animate back to original
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.4
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)

        CATransaction.begin()
        layer.shadowColor = originalShadowColor
        layer.shadowOpacity = originalShadowOpacity
        layer.shadowRadius = originalShadowRadius
        layer.shadowOffset = CGSize(width: 0, height: -15)
        CATransaction.commit()
      }
    }
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

  func exitAISearchMode() {
    viewModel.resetAISearch()
    searchField.stringValue = ""
    viewModel.searchQuery = ""
    updateAIBadge()
    updateIcon()
    updateResults()
  }

  func updateAIBadge() {
    guard aiBadgeContainer != nil,
          searchFieldLeadingToIcon != nil,
          searchFieldLeadingToAIBadge != nil else { return }

    // Don't show AI badge if Ask mode is active
    guard !(viewModel?.isAskMode ?? false) else {
      aiBadgeContainer.isHidden = true
      aiBadgeContainer.alphaValue = 0
      return
    }

    let shouldShowBadge = viewModel?.isAISearchMode ?? false

    // Detect transition into AI mode for glow animation
    let justEnteredAIMode = shouldShowBadge && !wasInAIMode
    wasInAIMode = shouldShowBadge

    aiBadgeContainer.isHidden = !shouldShowBadge
    aiBadgeContainer.alphaValue = shouldShowBadge ? 1 : 0

    // Update placeholder when AI mode is active
    if shouldShowBadge {
      searchField.placeholderString = "Describe what you're looking for..."
    } else if !(viewModel?.isAskMode ?? false) {
      searchField.placeholderString = "Search or enter URL..."
    }

    // Update badge label
    let resultCount = searchResults.count
    if viewModel?.isAISearchMode == true && resultCount > 0 {
      aiBadgeLabel.stringValue = "AI Search • \(resultCount)"
    } else {
      aiBadgeLabel.stringValue = "AI Search"
    }

    // Update constraints only if Ask mode is not active
    if !(viewModel?.isAskMode ?? false) {
      searchFieldLeadingToIcon.isActive = !shouldShowBadge
      searchFieldLeadingToAIBadge.isActive = shouldShowBadge
    }

    view.layoutSubtreeIfNeeded()

    // Trigger glow animation when entering AI mode
    if justEnteredAIMode {
      animateAIBadgeGlow()
    }
  }

  func animateAIBadgeGlow() {
    guard let layer = containerView.layer else { return }

    let originalShadowColor = layer.shadowColor
    let originalShadowOpacity = layer.shadowOpacity
    let originalShadowRadius = layer.shadowRadius

    // Blue glow for AI mode
    let glowColor = NSColor.systemBlue.cgColor

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.shadowColor = glowColor
    layer.shadowOpacity = 1.0
    layer.shadowRadius = 60
    layer.shadowOffset = .zero
    CATransaction.commit()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.4
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)

        CATransaction.begin()
        layer.shadowColor = originalShadowColor
        layer.shadowOpacity = originalShadowOpacity
        layer.shadowRadius = originalShadowRadius
        layer.shadowOffset = CGSize(width: 0, height: -15)
        CATransaction.commit()
      }
    }
  }

  func updateAutocompleteDisplay() {
    if currentAutocomplete.isEmpty {
      autocompleteLabel.stringValue = ""
      autocompleteLabel.isHidden = true
    } else {
      autocompleteLabel.isHidden = false

      // Create attributed string with user's text in CLEAR color (invisible spacer)
      // followed by the autocomplete suggestion in gray
      let query = searchField.stringValue
      let attributedString = NSMutableAttributedString()

      // User typed part - CLEAR color to act as invisible spacer
      let userPart = NSAttributedString(
        string: query,
        attributes: [
          .foregroundColor: NSColor.clear,
          .font: NSFont.systemFont(ofSize: 20, weight: .regular),
        ]
      )

      // Autocomplete part (gray) - this is what the user sees
      let autocompletePart = NSAttributedString(
        string: currentAutocomplete,
        attributes: [
          .foregroundColor: NSColor.tertiaryLabelColor,
          .font: NSFont.systemFont(ofSize: 20, weight: .regular),
        ]
      )

      attributedString.append(userPart)
      attributedString.append(autocompletePart)

      autocompleteLabel.attributedStringValue = attributedString
    }
  }

  func close() {
    viewModel.resetAISearch()
    viewModel.isSpotlightVisible = false
  }
}
