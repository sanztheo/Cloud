//
//  CustomWKWebView.swift
//  Cloud
//
//  Custom WKWebView to disable rubber banding effect and handle context menu downloads
//

import AppKit
import WebKit

class CustomWKWebView: WKWebView {
  weak var downloadManager: DownloadManager?

  // Handle scroll normally - let WKWebView manage its own scrolling
  override func scrollWheel(with event: NSEvent) {
    // Let the WebView handle scrolling normally
    super.scrollWheel(with: event)
  }

  // Handle context menu items, particularly for downloads
  override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
    super.willOpenMenu(menu, with: event)

    // Fix download menu items by ensuring they trigger proper download handling
    for menuItem in menu.items {
      if let identifier = menuItem.identifier?.rawValue {
        // Standard WebKit menu item identifiers for downloads
        if identifier == "WKMenuItemIdentifierDownloadImage" ||
           identifier == "WKMenuItemIdentifierDownloadLinkedFile" {
          // Store original action and replace with our handler
          menuItem.representedObject = menuItem.action
          menuItem.target = self
          menuItem.action = #selector(handleDownloadMenuItem(_:))
        }
      }
    }
  }

  @objc private func handleDownloadMenuItem(_ sender: NSMenuItem) {
    // Trigger the original action - WebKit will create the download and call our delegate
    if let originalAction = sender.representedObject as? Selector {
      NSApp.sendAction(originalAction, to: nil, from: sender)
    }
  }
}
