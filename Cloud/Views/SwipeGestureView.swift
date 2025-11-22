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
  var onDragOffsetChanged: ((CGFloat) -> Void)?
  var onDragEnded: ((CGFloat) -> Void)?
  var sidebarWidth: CGFloat = 240

  func makeNSView(context: Context) -> SwipeListeningView {
    let view = SwipeListeningView()
    view.onSwipeLeft = onSwipeLeft
    view.onSwipeRight = onSwipeRight
    view.onDragOffsetChanged = onDragOffsetChanged
    view.onDragEnded = onDragEnded
    view.sidebarWidth = sidebarWidth
    return view
  }

  func updateNSView(_ nsView: SwipeListeningView, context: Context) {
    nsView.onSwipeLeft = onSwipeLeft
    nsView.onSwipeRight = onSwipeRight
    nsView.onDragOffsetChanged = onDragOffsetChanged
    nsView.onDragEnded = onDragEnded
    nsView.sidebarWidth = sidebarWidth
  }
}

class SwipeListeningView: NSView {
  var onSwipeLeft: (() -> Void)?
  var onSwipeRight: (() -> Void)?
  var onDragOffsetChanged: ((CGFloat) -> Void)?
  var onDragEnded: ((CGFloat) -> Void)?
  var sidebarWidth: CGFloat = 240

  private var monitor: Any?
  private var totalDeltaX: CGFloat = 0
  private var isDragging: Bool = false
  private let swipeThresholdPercent: CGFloat = 0.5 // 50% threshold

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    setupMonitor()
  }

  deinit {
    removeMonitor()
  }

  private func setupMonitor() {
    removeMonitor()

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
    guard let eventWindow = event.window, eventWindow == self.window else { return }

    let locationInWindow = event.locationInWindow
    let locationInView = self.convert(locationInWindow, from: nil)

    guard self.bounds.contains(locationInView) else { return }

    if event.phase == .began {
      totalDeltaX = 0
      isDragging = true
    } else if event.phase == .changed && isDragging {
      totalDeltaX += event.scrollingDeltaX

      // Apply damping to make it feel more natural (resistance)
      let dampedOffset = totalDeltaX * 0.8

      // Clamp the offset to prevent over-scrolling
      let clampedOffset = max(-sidebarWidth, min(sidebarWidth, dampedOffset))

      // Update the visual offset in real-time
      DispatchQueue.main.async { [weak self] in
        self?.onDragOffsetChanged?(clampedOffset)
      }
    } else if event.phase == .ended || event.phase == .cancelled {
      if isDragging {
        isDragging = false

        // Calculate the percentage of swipe
        let swipePercent = abs(totalDeltaX) / sidebarWidth

        if swipePercent >= swipeThresholdPercent {
          // Exceeded threshold - switch space
          if totalDeltaX < 0 {
            // Swiped left -> next space
            onSwipeLeft?()
          } else {
            // Swiped right -> previous space
            onSwipeRight?()
          }
        }

        // Always notify that drag ended (for snap-back animation)
        DispatchQueue.main.async { [weak self] in
          self?.onDragEnded?(self?.totalDeltaX ?? 0)
        }

        totalDeltaX = 0
      }
    }
  }
}
