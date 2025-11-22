//
//  SpotlightCellView.swift
//  Cloud
//
//  Custom cell view for Spotlight search results with Arc-style design
//

import AppKit

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
    iconImageView.wantsLayer = true
    iconImageView.layer?.cornerRadius = 4
    iconImageView.layer?.masksToBounds = true
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
    let iconColor: NSColor

    // 1. Use provided favicon (e.g. from Tabs)
    if let favicon = result.favicon {
      iconBackground.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
      iconImageView.image = favicon
      iconImageView.contentTintColor = nil
      iconColor = .labelColor
    }
    // 2. Or try to load from URL (for History, Bookmarks, Suggestions)
    else if let url = result.url, let host = url.host {
      // Set placeholder first (type-specific icon)
      let (bgColor, iconName, color) = iconConfig(for: result.type)
      iconBackground.layer?.backgroundColor = bgColor.cgColor
      iconImageView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
      iconImageView.contentTintColor = color
      iconColor = color

      // Load favicon asynchronously
      loadFavicon(for: host)
    }
    // 3. Fallback to system icons
    else {
      // Check for specific commands
      if result.type == .command && result.title == "Summarize Page" {
        // Custom Raycast-style AI icon
        iconBackground.layer?.backgroundColor = NSColor.clear.cgColor  // Clear background for gradient layer

        // Remove any existing gradient layer to avoid stacking
        iconBackground.layer?.sublayers?.forEach {
          if $0 is CAGradientLayer { $0.removeFromSuperlayer() }
        }

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
          NSColor(red: 0.447, green: 0.706, blue: 1.0, alpha: 1.0).cgColor,  // #72B4FF
          NSColor(red: 0.145, green: 0.545, blue: 1.0, alpha: 1.0).cgColor,  // #258BFF
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        // Use fixed size as bounds might be zero during initial layout
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        gradientLayer.cornerRadius = 10  // "Pas full" -> Rounded square
        gradientLayer.borderWidth = 2
        gradientLayer.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor

        iconBackground.layer?.insertSublayer(gradientLayer, at: 0)

        // Ensure the container also has the correct corner radius if it clips
        iconBackground.layer?.cornerRadius = 10

        iconImageView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        iconImageView.contentTintColor = .white
        iconColor = .white
      } else if result.type == .command && result.title == "Ask About WebPage" {
        // Distinct badge for Ask flow
        iconBackground.layer?.backgroundColor = NSColor.clear.cgColor

        // Remove any existing gradient layer
        iconBackground.layer?.sublayers?.forEach {
          if $0 is CAGradientLayer { $0.removeFromSuperlayer() }
        }

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
          NSColor(red: 0.447, green: 0.706, blue: 1.0, alpha: 1.0).cgColor,  // #72B4FF
          NSColor(red: 0.145, green: 0.545, blue: 1.0, alpha: 1.0).cgColor,  // #258BFF
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        gradientLayer.cornerRadius = 10
        gradientLayer.borderWidth = 2
        gradientLayer.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor

        iconBackground.layer?.insertSublayer(gradientLayer, at: 0)
        iconBackground.layer?.cornerRadius = 10

        iconImageView.image = NSImage(
          systemSymbolName: "text.bubble.fill", accessibilityDescription: nil)
        iconImageView.contentTintColor = .white
        iconColor = .white
      } else {
        // Standard icon config
        // Remove any custom gradient if present
        iconBackground.layer?.sublayers?.forEach {
          if $0 is CAGradientLayer { $0.removeFromSuperlayer() }
        }

        let (bgColor, iconName, color) = iconConfig(for: result.type)
        iconBackground.layer?.backgroundColor = bgColor.cgColor
        iconImageView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        iconImageView.contentTintColor = color
        iconColor = color
      }
    }

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

  private func loadFavicon(for host: String) {
    // Use Google's favicon service
    let faviconURLString = "https://www.google.com/s2/favicons?domain=\(host)&sz=64"
    guard let faviconURL = URL(string: faviconURLString) else { return }

    URLSession.shared.dataTask(with: faviconURL) { [weak self] data, _, _ in
      guard let self = self, let data = data, let image = NSImage(data: data) else { return }

      DispatchQueue.main.async {
        self.iconImageView.image = image
        self.iconImageView.contentTintColor = nil
        self.iconBackground.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
      }
    }.resume()
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
      return (NSColor.clear, "magnifyingglass", .secondaryLabelColor)
    case .website:
      return (NSColor.white.withAlphaComponent(0.1), "globe", .secondaryLabelColor)
    case .command:
      return (NSColor.systemPurple.withAlphaComponent(0.15), "sparkles", .systemPurple)
    }
  }
}
