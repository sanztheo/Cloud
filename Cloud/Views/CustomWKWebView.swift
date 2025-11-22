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

  // Store context menu location
  private var lastContextMenuLocation: NSPoint = .zero

  override func scrollWheel(with event: NSEvent) {
    super.scrollWheel(with: event)
  }

  override func rightMouseDown(with event: NSEvent) {
    lastContextMenuLocation = convert(event.locationInWindow, from: nil)
    super.rightMouseDown(with: event)
  }

  override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
    super.willOpenMenu(menu, with: event)

    // Override download menu items to use WKWebView.startDownload
    for menuItem in menu.items {
      let identifier = menuItem.identifier?.rawValue ?? ""

      if identifier == "WKMenuItemIdentifierDownloadImage" {
        NSLog("📥 Found Download Image menu item - overriding action")
        menuItem.target = self
        menuItem.action = #selector(handleDownloadImage(_:))
      } else if identifier == "WKMenuItemIdentifierDownloadLinkedFile" {
        NSLog("📥 Found Download Linked File menu item - overriding action")
        menuItem.target = self
        menuItem.action = #selector(handleDownloadLinkedFile(_:))
      }
    }
  }

  @objc private func handleDownloadImage(_ sender: NSMenuItem) {
    NSLog("📥 handleDownloadImage triggered")

    // Get the image URL at the context menu location using JavaScript
    let x = lastContextMenuLocation.x
    let y = bounds.height - lastContextMenuLocation.y

    let js = """
      (function() {
        var element = document.elementFromPoint(\(x), \(y));
        while (element) {
          if (element.tagName === 'IMG') {
            return element.src || element.currentSrc;
          }
          element = element.parentElement;
        }
        return null;
      })()
    """

    evaluateJavaScript(js) { [weak self] result, error in
      guard let self = self else { return }

      if let urlString = result as? String, !urlString.isEmpty, let url = URL(string: urlString) {
        NSLog("📥 Found image URL: %@", urlString)
        self.startNativeDownload(url: url)
      } else {
        NSLog("⚠️ Could not find image URL at click location")
      }
    }
  }

  @objc private func handleDownloadLinkedFile(_ sender: NSMenuItem) {
    NSLog("📥 handleDownloadLinkedFile triggered")

    let x = lastContextMenuLocation.x
    let y = bounds.height - lastContextMenuLocation.y

    let js = """
      (function() {
        var element = document.elementFromPoint(\(x), \(y));
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
      guard let self = self else { return }

      if let urlString = result as? String, !urlString.isEmpty, let url = URL(string: urlString) {
        NSLog("📥 Found link URL: %@", urlString)
        self.startNativeDownload(url: url)
      } else {
        NSLog("⚠️ Could not find link URL at click location")
      }
    }
  }

  private func startNativeDownload(url: URL) {
    NSLog("📥 Starting native WKWebView download for: %@", url.absoluteString)

    // Use WKWebView's native startDownload API
    let request = URLRequest(url: url)
    self.startDownload(using: request) { [weak self] download in
      NSLog("📥 WKDownload created successfully")
      download.delegate = self?.downloadManager
      self?.downloadManager?.trackDownload(download)
    }
  }
}
