//
//  SpotlightViewController.swift
//  Cloud
//
//  AppKit-based Spotlight implementation with proper keyboard and hover handling
//

import AppKit

class SpotlightViewController: NSViewController {
  var viewModel: BrowserViewModel!

  private var searchField: NSSearchField!
  private var tableView: SpotlightTableView!
  private var scrollView: NSScrollView!
  private var containerView: NSVisualEffectView!
  private var searchResults: [SearchResult] = []

  override func loadView() {
    view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
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

  private func setupUI() {
    // Container with visual effect
    containerView = NSVisualEffectView()
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

  @objc private func searchFieldChanged() {
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

  func close() {
    viewModel.isSpotlightVisible = false
  }
}

// MARK: - NSTableViewDataSource
extension SpotlightViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    return searchResults.count
  }
}

// MARK: - NSTableViewDelegate
extension SpotlightViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    let identifier = NSUserInterfaceItemIdentifier("SpotlightCell")

    var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? SpotlightCellView
    if cellView == nil {
      cellView = SpotlightCellView()
      cellView?.identifier = identifier
    }

    let result = searchResults[row]
    let isSelected = tableView.selectedRow == row
    cellView?.configure(with: result, isSelected: isSelected)

    return cellView
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    // Reload visible cells to update selection state
    let visibleRows = tableView.rows(in: tableView.visibleRect)
    tableView.reloadData(
      forRowIndexes: IndexSet(integersIn: visibleRows.lowerBound..<visibleRows.upperBound),
      columnIndexes: IndexSet(integer: 0))
  }
}

// MARK: - NSSearchFieldDelegate
extension SpotlightViewController: NSSearchFieldDelegate {
  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
    -> Bool
  {
    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      // Enter key
      handleEnter()
      return true
    } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
      // Escape key
      close()
      return true
    } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
      // Down arrow - move to table view
      if !searchResults.isEmpty {
        view.window?.makeFirstResponder(tableView)
        if tableView.selectedRow < 0 {
          tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        tableView.scrollRowToVisible(tableView.selectedRow)
      }
      return true
    } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
      // Up arrow - move to table view (select last item)
      if !searchResults.isEmpty {
        view.window?.makeFirstResponder(tableView)
        let lastRow = searchResults.count - 1
        if tableView.selectedRow < 0 {
          tableView.selectRowIndexes(IndexSet(integer: lastRow), byExtendingSelection: false)
        }
        tableView.scrollRowToVisible(tableView.selectedRow)
      }
      return true
    }
    return false
  }

  private func handleEnter() {
    guard let viewModel = viewModel else { return }

    if searchResults.isEmpty {
      viewModel.navigateToAddress(searchField.stringValue)
      close()
    } else {
      let selectedRow = tableView.selectedRow
      if selectedRow >= 0 && selectedRow < searchResults.count {
        viewModel.selectSearchResult(searchResults[selectedRow])
      }
    }
  }
}

// MARK: - SpotlightTableViewDelegate
extension SpotlightViewController: SpotlightTableViewDelegate {
  func tableViewDidPressEscape(_ tableView: SpotlightTableView) {
    close()
  }

  func tableViewDidPressEnter(_ tableView: SpotlightTableView) {
    handleEnter()
  }
}

// MARK: - SpotlightTableView
protocol SpotlightTableViewDelegate: AnyObject {
  func tableViewDidPressEscape(_ tableView: SpotlightTableView)
  func tableViewDidPressEnter(_ tableView: SpotlightTableView)
}

class SpotlightTableView: NSTableView {
  enum Edge {
    case top, bottom
  }

  weak var spotlightDelegate: SpotlightTableViewDelegate?
  private var trackingArea: NSTrackingArea?

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let existing = trackingArea {
      removeTrackingArea(existing)
    }

    trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
      owner: self,
      userInfo: nil
    )

    if let trackingArea = trackingArea {
      addTrackingArea(trackingArea)
    }
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)

    let point = convert(event.locationInWindow, from: nil)

    // Update hover on row
    let row = self.row(at: point)
    if row >= 0 {
      selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let row = self.row(at: point)

    if row >= 0 {
      // Select the row
      selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
      // Trigger navigation immediately
      spotlightDelegate?.tableViewDidPressEnter(self)
    } else {
      super.mouseDown(with: event)
    }
  }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 126:  // Up arrow
      if selectedRow > 0 {
        selectRowIndexes(IndexSet(integer: selectedRow - 1), byExtendingSelection: false)
        scrollRowToVisible(selectedRow)
      }
    case 125:  // Down arrow
      if selectedRow < numberOfRows - 1 {
        selectRowIndexes(IndexSet(integer: selectedRow + 1), byExtendingSelection: false)
        scrollRowToVisible(selectedRow)
      }
    case 53:  // Escape
      spotlightDelegate?.tableViewDidPressEscape(self)
    case 36:  // Enter
      spotlightDelegate?.tableViewDidPressEnter(self)
    default:
      super.keyDown(with: event)
    }
  }
}

// MARK: - SpotlightCellView
class SpotlightCellView: NSTableCellView {
  private var iconBackground: NSView!
  private var iconImageView: NSImageView!
  private var titleLabel: NSTextField!
  private var subtitleLabel: NSTextField!
  private var badgeContainer: NSView!
  private var badgeLabel: NSTextField!
  private var backgroundLayer: CALayer!

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupUI()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupUI()
  }

  private func setupUI() {
    wantsLayer = true

    // Background layer for selection
    backgroundLayer = CALayer()
    backgroundLayer.cornerRadius = 12
    layer?.addSublayer(backgroundLayer)

    // Icon background (larger circle)
    iconBackground = NSView()
    iconBackground.wantsLayer = true
    iconBackground.layer?.cornerRadius = 18
    iconBackground.translatesAutoresizingMaskIntoConstraints = false
    addSubview(iconBackground)

    // Icon
    iconImageView = NSImageView()
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    iconBackground.addSubview(iconImageView)

    // Title (larger font)
    titleLabel = NSTextField(labelWithString: "")
    titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
    titleLabel.lineBreakMode = .byTruncatingTail
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(titleLabel)

    // Subtitle (larger font)
    subtitleLabel = NSTextField(labelWithString: "")
    subtitleLabel.font = .systemFont(ofSize: 13)
    subtitleLabel.textColor = .secondaryLabelColor
    subtitleLabel.lineBreakMode = .byTruncatingTail
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(subtitleLabel)

    // Badge container for "Switch to Tab" style
    badgeContainer = NSView()
    badgeContainer.wantsLayer = true
    badgeContainer.layer?.cornerRadius = 8
    badgeContainer.translatesAutoresizingMaskIntoConstraints = false
    addSubview(badgeContainer)

    // Badge label
    badgeLabel = NSTextField(labelWithString: "")
    badgeLabel.font = .systemFont(ofSize: 11, weight: .medium)
    badgeLabel.alignment = .center
    badgeLabel.translatesAutoresizingMaskIntoConstraints = false
    badgeContainer.addSubview(badgeLabel)

    NSLayoutConstraint.activate([
      // Larger icon circle
      iconBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      iconBackground.centerYAnchor.constraint(equalTo: centerYAnchor),
      iconBackground.widthAnchor.constraint(equalToConstant: 36),
      iconBackground.heightAnchor.constraint(equalToConstant: 36),

      iconImageView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
      iconImageView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
      iconImageView.widthAnchor.constraint(equalToConstant: 18),
      iconImageView.heightAnchor.constraint(equalToConstant: 18),

      // More spacing between icon and text
      titleLabel.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 16),
      titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 15),
      titleLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: badgeContainer.leadingAnchor, constant: -12),

      subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
      subtitleLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: badgeContainer.leadingAnchor, constant: -12),

      // Badge container
      badgeContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      badgeContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
      badgeContainer.heightAnchor.constraint(equalToConstant: 24),

      // Badge label inside container
      badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 10),
      badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -10),
      badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 4),
      badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -4),
    ])
  }

  override func layout() {
    super.layout()
    backgroundLayer.frame = bounds.insetBy(dx: 10, dy: 2)
  }

  func configure(with result: SearchResult, isSelected: Bool) {
    titleLabel.stringValue = result.title
    subtitleLabel.stringValue = result.subtitle

    // Configure icon
    let (bgColor, iconName, iconColor) = iconConfig(for: result.type)
    iconBackground.layer?.backgroundColor = bgColor.cgColor
    iconImageView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
    iconImageView.contentTintColor = iconColor

    // Arc-style blue/teal selection background
    let arcBlue = NSColor(red: 74 / 255.0, green: 124 / 255.0, blue: 142 / 255.0, alpha: 1.0)

    // Configure badge - show "Switch to Tab" for existing tabs only
    if result.type == .tab {
      badgeContainer.isHidden = false
      badgeLabel.stringValue = "Switch to Tab"

      if isSelected {
        badgeContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        badgeLabel.textColor = .white
      } else {
        badgeContainer.layer?.backgroundColor = arcBlue.withAlphaComponent(0.2).cgColor
        badgeLabel.textColor = arcBlue
      }
    } else {
      badgeContainer.isHidden = true
    }

    // Arc-style selection highlight
    if isSelected {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.15
        backgroundLayer.backgroundColor = arcBlue.cgColor
        titleLabel.textColor = .white
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        iconImageView.contentTintColor = .white
      }
    } else {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.15
        backgroundLayer.backgroundColor = NSColor.clear.cgColor
        titleLabel.textColor = .labelColor
        subtitleLabel.textColor = .secondaryLabelColor
        iconImageView.contentTintColor = iconColor
      }
    }
  }

  private func iconConfig(for type: SearchResultType) -> (NSColor, String, NSColor) {
    switch type {
    case .tab:
      return (NSColor.systemBlue.withAlphaComponent(0.15), "square.on.square", .systemBlue)
    case .bookmark:
      return (NSColor.systemYellow.withAlphaComponent(0.15), "star.fill", .systemYellow)
    case .history:
      return (NSColor.systemGray.withAlphaComponent(0.15), "clock.fill", .secondaryLabelColor)
    case .suggestion:
      return (NSColor.systemPurple.withAlphaComponent(0.15), "globe", .systemPurple)
    }
  }
}
