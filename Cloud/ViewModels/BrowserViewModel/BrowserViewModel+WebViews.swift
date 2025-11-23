//
//  BrowserViewModel+WebViews.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Extension handling WebView creation and management.
//

import Foundation
import WebKit

// MARK: - WebView Management
extension BrowserViewModel {

  func createWebView(for tab: BrowserTab) -> WKWebView {
    // ✓ Use enhanced stealth configuration (2025 best practices)
    let configuration = StealthWebKitConfig.createConfiguration()

    // Use CustomWKWebView for download handling
    let webView = CustomWKWebView(
      frame: NSRect(x: 0, y: 0, width: 100, height: 100), configuration: configuration)

    // ✓ Apply stealth settings (stable User-Agent matching OS, natural behavior)
    StealthWebKitConfig.setupWebView(webView)

    webViews[tab.id] = webView

    // Observe isLoading via KVO to sync with tab model
    // This ensures isLoading is updated even without navigationDelegate
    let tabId = tab.id
    loadingObservations[tabId] = webView.observe(\.isLoading, options: [.new]) {
      [weak self] webView, change in
      guard let self = self else { return }
      DispatchQueue.main.async {
        if let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
          self.tabs[index].isLoading = webView.isLoading
        }
      }
    }

    loadURL(tab.url, for: tabId)

    return webView
  }

  func getWebView(for tabId: UUID) -> WKWebView? {
    if let webView = webViews[tabId] {
      return webView
    }

    if let tab = tabs.first(where: { $0.id == tabId }) {
      return createWebView(for: tab)
    }

    return nil
  }
}
