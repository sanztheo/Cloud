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

      // Hide search icon (magnifying glass)
      cell.searchButtonCell = nil
    }

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

    NSLayoutConstraint.activate([
      searchField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 20),
      searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -20),
      searchField.topAnchor.constraint(equalTo: searchContainer.topAnchor, constant: 18),
      searchField.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: -18),
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
  }

  @objc func searchFieldChanged() {
    viewModel.searchQuery = searchField.stringValue
    updateResults()
    tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
  }

  func updateResults() {
    guard let viewModel = viewModel else { return }
    searchResults = viewModel.searchResults(for: searchField.stringValue)
    tableView.reloadData()

    // Update scroll view visibility
    scrollView.isHidden = searchResults.isEmpty

    // Update container height
    let baseHeight: CGFloat = 68
    let resultsHeight: CGFloat =
      searchResults.isEmpty ? 0 : min(CGFloat(searchResults.count) * 70 + 16, 400)

    containerView.constraints.first { $0.firstAttribute == .height }?.isActive = false
    containerView.heightAnchor.constraint(equalToConstant: baseHeight + resultsHeight).isActive =
      true
  }
}
