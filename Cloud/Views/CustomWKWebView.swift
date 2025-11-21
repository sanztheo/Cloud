//
//  CustomWKWebView.swift
//  Cloud
//
//  Custom WKWebView to disable rubber banding effect
//

import WebKit

class CustomWKWebView: WKWebView {
  // Handle scroll normally - let WKWebView manage its own scrolling
  override func scrollWheel(with event: NSEvent) {
    // Let the WebView handle scrolling normally
    super.scrollWheel(with: event)
  }
}
