//
//  SpotlightViewController+UI.swift
//  Cloud
//
//  UI setup and layout for SpotlightViewController
//

import AppKit

extension SpotlightViewController {
  func setupUI() {
    // Container with visual effect
    containerView = ClickBlockingVisualEffectView()
    containerView.material = .hudWindow
    containerView.blendingMode = .behindWindow
    containerView.state = .active
    containerView.wantsLayer = true
    containerView.layer?.cornerRadius = 16
    containerView.layer?.shadowColor = NSColor.black.cgColor
    containerView.layer?.shadowOpacity = 0.4
    containerView.layer?.shadowRadius = 30
    containerView.layer?.shadowOffset = CGSize(width: 0, height: -15)

    // Search field - Arc style (completely transparent)
    searchField = NSSearchField()
    searchField.placeholderString = "Search or enter URL..."
    searchField.font = .systemFont(ofSize: 20, weight: .regular)
    searchField.focusRingType = .none
    searchField.delegate = self
    searchField.target = self
    searchField.action = #selector(searchFieldChanged)

    // Complete transparency like Arc
    searchField.isBordered = false
    searchField.isBezeled = false
    searchField.drawsBackground = false
    searchField.wantsLayer = true
    searchField.layer?.backgroundColor = NSColor.clear.cgColor

    if let cell = searchField.cell as? NSSearchFieldCell {
      cell.backgroundColor = .clear
      cell.drawsBackground = false
      cell.isBordered = false
      cell.isBezeled = false
      cell.focusRingType = .none
      cell.isScrollable = true  // Enable horizontal text scrolling

      // Hide search icon (magnifying glass)
      cell.searchButtonCell = nil
    }

    // Autocomplete hint label (overlay for gray text)
    autocompleteLabel = NSTextField()
    autocompleteLabel.isEditable = false
    autocompleteLabel.isBordered = false
    autocompleteLabel.drawsBackground = false
    autocompleteLabel.font = .systemFont(ofSize: 20, weight: .regular)
    autocompleteLabel.textColor = .tertiaryLabelColor
    autocompleteLabel.translatesAutoresizingMaskIntoConstraints = false

    // Table view
    tableView = SpotlightTableView()
    tableView.delegate = self
    tableView.dataSource = self
    tableView.headerView = nil
    tableView.backgroundColor = .clear
    tableView.selectionHighlightStyle = .none
    tableView.intercellSpacing = NSSize(width: 0, height: 4)
    tableView.rowHeight = 66
    tableView.spotlightDelegate = self

    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
    column.width = 660
    tableView.addTableColumn(column)

    // Scroll view
    scrollView = NSScrollView()
    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.backgroundColor = .clear
    scrollView.drawsBackground = false

    // Layout
    let stackView = NSStackView()
    stackView.orientation = .vertical
    stackView.spacing = 0
    stackView.translatesAutoresizingMaskIntoConstraints = false

    let searchContainer = NSView()
    searchContainer.translatesAutoresizingMaskIntoConstraints = false
    searchField.translatesAutoresizingMaskIntoConstraints = false
    searchContainer.addSubview(searchField)
    searchContainer.addSubview(autocompleteLabel)

    // Icon Image View
    iconImageView = NSImageView()
    iconImageView.image = NSImage(
      systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
    iconImageView.contentTintColor = .secondaryLabelColor
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    searchContainer.addSubview(iconImageView)

    // Ask badge (appears in Ask About WebPage mode)
    askBadgeContainer = NSView()
    askBadgeContainer.wantsLayer = true
    askBadgeContainer.layer?.cornerRadius = 10
    askBadgeContainer.layer?.backgroundColor = NSColor.systemPurple.withAlphaComponent(0.18).cgColor
    askBadgeContainer.translatesAutoresizingMaskIntoConstraints = false
    askBadgeContainer.isHidden = true
    askBadgeContainer.alphaValue = 0
    searchContainer.addSubview(askBadgeContainer)

    askBadgeLabel = NSTextField(labelWithString: "Ask About Webpage")
    askBadgeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    askBadgeLabel.textColor = NSColor.systemPurple
    askBadgeLabel.alignment = .center
    askBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
    askBadgeContainer.addSubview(askBadgeLabel)

    searchFieldLeadingToIcon = searchField.leadingAnchor.constraint(
      equalTo: iconImageView.trailingAnchor, constant: 12)
    searchFieldLeadingToBadge = searchField.leadingAnchor.constraint(
      equalTo: askBadgeContainer.trailingAnchor, constant: 12)
    searchFieldLeadingToIcon.isActive = true
    searchFieldLeadingToBadge.isActive = false

    NSLayoutConstraint.activate([
      iconImageView.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 20),
      iconImageView.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
      iconImageView.widthAnchor.constraint(equalToConstant: 24),
      iconImageView.heightAnchor.constraint(equalToConstant: 24),

      askBadgeContainer.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
      askBadgeContainer.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

      askBadgeLabel.leadingAnchor.constraint(equalTo: askBadgeContainer.leadingAnchor, constant: 10),
      askBadgeLabel.trailingAnchor.constraint(equalTo: askBadgeContainer.trailingAnchor, constant: -10),
      askBadgeLabel.topAnchor.constraint(equalTo: askBadgeContainer.topAnchor, constant: 5),
      askBadgeLabel.bottomAnchor.constraint(equalTo: askBadgeContainer.bottomAnchor, constant: -5),

      searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -20),
      searchField.firstBaselineAnchor.constraint(equalTo: askBadgeLabel.firstBaselineAnchor),
      searchField.heightAnchor.constraint(equalToConstant: 32),

      // Autocomplete label positioned right after search field
      autocompleteLabel.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
      autocompleteLabel.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
      autocompleteLabel.heightAnchor.constraint(equalToConstant: 32),

      searchContainer.heightAnchor.constraint(equalToConstant: 68),
    ])

    scrollView.translatesAutoresizingMaskIntoConstraints = false

    stackView.addArrangedSubview(searchContainer)
    stackView.addArrangedSubview(scrollView)

    containerView.addSubview(stackView)
    view.addSubview(containerView)

    containerView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 80),
      containerView.widthAnchor.constraint(equalToConstant: 680),

      stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
      stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

      scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: 360),
    ])

    updateAskBadge()
  }

  @objc func searchFieldChanged() {
    // This is now handled by controlTextDidChange for instant updates
    // Kept as fallback for programmatic changes
    updateResults()
    updateIcon()
    updateAskBadge()
  }

  func updateResults() {
    guard let viewModel = viewModel else { return }
    searchResults = viewModel.searchResults(for: searchField.stringValue)
    tableView.reloadData()

    // Update scroll view visibility
    scrollView.isHidden = searchResults.isEmpty

    // Always select first row when there are results (Arc/Spotlight behavior)
    if !searchResults.isEmpty {
      tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }

    // Update container height
    let baseHeight: CGFloat = 68
    let resultsHeight: CGFloat =
      searchResults.isEmpty ? 0 : min(CGFloat(searchResults.count) * 70 + 16, 400)

    containerView.constraints.first { $0.firstAttribute == .height }?.isActive = false
    containerView.heightAnchor.constraint(equalToConstant: baseHeight + resultsHeight).isActive =
      true
  }
}
