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

  // Store the last right-click location for context menu actions
  private var lastContextMenuEvent: NSEvent?

  // Handle scroll normally - let WKWebView manage its own scrolling
  override func scrollWheel(with event: NSEvent) {
    // Let the WebView handle scrolling normally
    super.scrollWheel(with: event)
  }

  // Capture right-click event for later use
  override func rightMouseDown(with event: NSEvent) {
    lastContextMenuEvent = event
    super.rightMouseDown(with: event)
  }

  // Handle context menu items, particularly for downloads
  override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
    super.willOpenMenu(menu, with: event)

    // Debug: Print all menu items to identify download items
    NSLog("📋 Context menu items:")
    for (index, menuItem) in menu.items.enumerated() {
      let identifier = menuItem.identifier?.rawValue ?? "nil"
      let title = menuItem.title
      NSLog("  [%d] id: '%@' title: '%@'", index, identifier, title)
    }

    // Look for download-related menu items and override their action
    for menuItem in menu.items {
      let identifier = menuItem.identifier?.rawValue ?? ""

      if identifier == "WKMenuItemIdentifierDownloadImage" {
        NSLog("🔽 Overriding Download Image menu item")
        menuItem.target = self
        menuItem.action = #selector(handleDownloadImage(_:))
      } else if identifier == "WKMenuItemIdentifierDownloadLinkedFile" {
        NSLog("🔽 Overriding Download Linked File menu item")
        menuItem.target = self
        menuItem.action = #selector(handleDownloadLinkedFile(_:))
      }
    }
  }

  @objc private func handleDownloadImage(_ sender: NSMenuItem) {
    NSLog("📥 handleDownloadImage triggered")

    // Get the point where user right-clicked
    guard let event = lastContextMenuEvent else {
      NSLog("⚠️ No context menu event stored")
      return
    }

    let point = convert(event.locationInWindow, from: nil)

    // Use JavaScript to get the image URL at this point
    let js = """
      (function() {
        var x = \(point.x);
        var y = \(bounds.height - point.y);
        var element = document.elementFromPoint(x, y);
        while (element) {
          if (element.tagName === 'IMG') {
            return element.src;
          }
          if (element.style && element.style.backgroundImage) {
            var match = element.style.backgroundImage.match(/url\\(['"]?([^'"\\)]+)['"]?\\)/);
            if (match) return match[1];
          }
          element = element.parentElement;
        }
        return null;
      })()
    """

    evaluateJavaScript(js) { [weak self] result, error in
      if let urlString = result as? String, let url = URL(string: urlString) {
        NSLog("📥 Found image URL: %@", urlString)
        self?.startDownload(url: url)
      } else {
        NSLog("⚠️ Could not find image URL: %@", error?.localizedDescription ?? "unknown error")
      }
    }
  }

  @objc private func handleDownloadLinkedFile(_ sender: NSMenuItem) {
    NSLog("📥 handleDownloadLinkedFile triggered")

    guard let event = lastContextMenuEvent else {
      NSLog("⚠️ No context menu event stored")
      return
    }

    let point = convert(event.locationInWindow, from: nil)

    // Use JavaScript to get the link URL at this point
    let js = """
      (function() {
        var x = \(point.x);
        var y = \(bounds.height - point.y);
        var element = document.elementFromPoint(x, y);
        while (element) {
          if (element.tagName === 'A' && element.href) {
            return element.href;
          }
          element = element.parentElement;
        }
        return null;
      })()
    """

    evaluateJavaScript(js) { [weak self] result, error in
      if let urlString = result as? String, let url = URL(string: urlString) {
        NSLog("📥 Found link URL: %@", urlString)
        self?.startDownload(url: url)
      } else {
        NSLog("⚠️ Could not find link URL: %@", error?.localizedDescription ?? "unknown error")
      }
    }
  }

  private func startDownload(url: URL) {
    NSLog("📥 Starting download for: %@", url.absoluteString)
    NSLog("📥 downloadManager is: %@", downloadManager == nil ? "nil" : "set")

    // Capture downloadManager before async call
    guard let manager = downloadManager else {
      NSLog("⚠️ downloadManager is nil before starting download!")
      return
    }

    // Use WKWebView's native download API
    if #available(macOS 11.3, *) {
      self.startDownload(using: URLRequest(url: url)) { download in
        NSLog("📥 Download started via WKWebView.startDownload")
        NSLog("📥 Setting delegate on download object")
        download.delegate = manager
        manager.trackDownload(download)
        NSLog("📥 Download delegate assigned, delegate is: %@", String(describing: download.delegate))
      }
    } else {
      // Fallback for older macOS - use URLSession
      NSLog("📥 Using URLSession fallback for download")
      manager.startDownload(url: url, suggestedFilename: url.lastPathComponent)
    }
  }
}
