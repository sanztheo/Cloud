//
//  BrowserViewModel+Navigation.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//
//  Extension handling web navigation (load URL, back, forward, reload).
//

import Foundation
import WebKit

// MARK: - Navigation
extension BrowserViewModel {

  func loadURL(_ url: URL, for tabId: UUID) {
    guard let webView = webViews[tabId] else { return }

    // ✓ Minimal, system-consistent headers (what Safari actually sends)
    var request = URLRequest(url: url)
    StealthWebKitConfig.configureRequest(&request)

    // Debug log for sites with strong bot protection
    if StealthWebKitConfig.hasStrongBotProtection(url: url) {
      StealthWebKitConfig.logDiagnostic(for: webView, url: url)
    }

    webView.load(request)

    if let index = tabs.firstIndex(where: { $0.id == tabId }) {
      tabs[index].url = url
      tabs[index].isLoading = true
    }
  }

  func navigateToAddress(_ address: String) {
    guard let tabId = activeTabId else { return }

    var urlString = address
    if !address.contains("://") {
      if address.contains(".") && !address.contains(" ") {
        urlString = "https://\(address)"
      } else {
        urlString =
          "https://www.google.com/search?q=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address)"
      }
    }

    if let url = URL(string: urlString) {
      loadURL(url, for: tabId)
      addToHistory(url: url, title: address)
    }
  }

  func goBack() {
    guard let tabId = activeTabId,
      let webView = webViews[tabId],
      webView.canGoBack
    else { return }
    webView.goBack()
  }

  func goForward() {
    guard let tabId = activeTabId,
      let webView = webViews[tabId],
      webView.canGoForward
    else { return }
    webView.goForward()
  }

  func reload() {
    guard let tabId = activeTabId,
      let webView = webViews[tabId]
    else { return }
    webView.reload()
  }

  func stopLoading() {
    guard let tabId = activeTabId,
      let webView = webViews[tabId]
    else { return }
    webView.stopLoading()
  }
}
