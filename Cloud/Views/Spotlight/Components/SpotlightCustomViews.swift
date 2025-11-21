//
//  SpotlightCustomViews.swift
//  Cloud
//
//  Custom views for event handling in Spotlight
//

import AppKit

// MARK: - Custom Views for Event Handling

class SpotlightRootView: NSView {
  var onMouseDown: (() -> Void)?

  override func mouseDown(with event: NSEvent) {
    onMouseDown?()
  }
}

class ClickBlockingVisualEffectView: NSVisualEffectView {
  override func mouseDown(with event: NSEvent) {
    // Consume event, do not propagate to root view
  }
}
