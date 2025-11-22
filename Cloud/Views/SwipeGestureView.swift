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
  var onDragEnded: ((_ offset: CGFloat, _ didSwipe: Bool) -> Void)?
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
  var onDragEnded: ((_ offset: CGFloat, _ didSwipe: Bool) -> Void)?
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
        let didSwipe = swipePercent >= swipeThresholdPercent
        let finalOffset = totalDeltaX

        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }

          if didSwipe {
            // Reset offset FIRST (no animation needed since we're switching)
            self.onDragEnded?(finalOffset, true)

            // Then switch space
            if finalOffset < 0 {
              self.onSwipeLeft?()
            } else {
              self.onSwipeRight?()
            }
          } else {
            // Snap back with animation
            self.onDragEnded?(finalOffset, false)
          }
        }

        totalDeltaX = 0
      }
    }
  }
}
