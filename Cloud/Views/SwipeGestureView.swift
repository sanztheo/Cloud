//
//  SwipeGestureView.swift
//  Cloud
//
//  Created by Sanz on 21/11/2025.
//

import AppKit
import SwiftUI

struct SwipeGestureView: NSViewRepresentable {
  var onSwipeLeft: () -> Void
  var onSwipeRight: () -> Void

  func makeNSView(context: Context) -> SwipeListeningView {
    let view = SwipeListeningView()
    view.onSwipeLeft = onSwipeLeft
    view.onSwipeRight = onSwipeRight
    return view
  }

  func updateNSView(_ nsView: SwipeListeningView, context: Context) {
    nsView.onSwipeLeft = onSwipeLeft
    nsView.onSwipeRight = onSwipeRight
  }
}

class SwipeListeningView: NSView {
  var onSwipeLeft: (() -> Void)?
  var onSwipeRight: (() -> Void)?

  private var monitor: Any?
  private var totalDeltaX: CGFloat = 0
  private var hasTriggered: Bool = false
  private let threshold: CGFloat = 30.0

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    setupMonitor()
  }

  deinit {
    removeMonitor()
  }

  private func setupMonitor() {
    removeMonitor()

    // Monitor local events to catch scrollWheel before they are consumed by subviews (like ScrollView)
    monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
      self?.handleScrollEvent(event)
      return event
    }
  }

  private func removeMonitor() {
    if let monitor = monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
  }

  private func handleScrollEvent(_ event: NSEvent) {
    // Ensure event is for this window
    guard let eventWindow = event.window, eventWindow == self.window else { return }

    // Check if the mouse is over this view
    let locationInWindow = event.locationInWindow
    let locationInView = self.convert(locationInWindow, from: nil)

    guard self.bounds.contains(locationInView) else { return }

    if event.phase == .began {
      totalDeltaX = 0
      hasTriggered = false
    } else if event.phase == .changed {
      totalDeltaX += event.scrollingDeltaX

      if !hasTriggered {
        // Invert logic:
        // Swipe Left (fingers move Right to Left) -> deltaX is Negative -> Go Next Space
        // Swipe Right (fingers move Left to Right) -> deltaX is Positive -> Go Previous Space

        if totalDeltaX < -threshold {
          // Negative delta -> Swipe Left -> Next Space
          onSwipeLeft?()
          hasTriggered = true
        } else if totalDeltaX > threshold {
          // Positive delta -> Swipe Right -> Previous Space
          onSwipeRight?()
          hasTriggered = true
        }
      }
    } else if event.phase == .ended || event.phase == .cancelled {
      totalDeltaX = 0
      hasTriggered = false
    }
  }
}
