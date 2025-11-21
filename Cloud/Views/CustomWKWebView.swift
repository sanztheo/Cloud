//
//  CustomWKWebView.swift
//  Cloud
//
//  Custom WKWebView to disable rubber banding effect
//

import WebKit

class CustomWKWebView: WKWebView {
  // Disable rubber banding by preventing scroll wheel events
  override func scrollWheel(with event: NSEvent) {
    // Don't pass scroll events when at bounds to prevent rubber banding
    nextResponder?.scrollWheel(with: event)
  }
}
