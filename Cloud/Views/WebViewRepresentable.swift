//
//  WebViewRepresentable.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import SwiftUI
import WebKit

struct WebViewRepresentable: NSViewRepresentable {
  let tabId: UUID
  @ObservedObject var viewModel: BrowserViewModel

  func makeNSView(context: Context) -> WKWebView {
    NSLog("🔧 makeNSView called for tabId: %@", tabId.uuidString)
    let webView = viewModel.getWebView(for: tabId) ?? createFallbackWebView()

    NSLog("🔧 Setting navigationDelegate and uiDelegate")
    webView.navigationDelegate = context.coordinator
    webView.uiDelegate = context.coordinator

    // Set download manager if this is CustomWKWebView
    if let customWebView = webView as? CustomWKWebView {
      customWebView.downloadManager = viewModel.downloadManager
      NSLog("🔧 downloadManager assigned to CustomWKWebView")
    } else {
      NSLog("⚠️ WebView is NOT a CustomWKWebView!")
    }

    // Critical: Enable autoresizing to fill available space
    webView.autoresizingMask = [.width, .height]

    // Enable layer for corner radius
    webView.wantsLayer = true
    webView.layer?.cornerRadius = 12
    webView.layer?.masksToBounds = true

    // ✓ Pas d'injection JavaScript agressive (détectée par les systèmes anti-bot)

    return webView
  }

  func updateNSView(_ nsView: WKWebView, context: Context) {
    // CRITICAL: Always ensure delegates are set - they may have been lost
    if nsView.navigationDelegate == nil {
      print("⚠️ navigationDelegate was nil, reassigning...")
      nsView.navigationDelegate = context.coordinator
    }
    if nsView.uiDelegate == nil {
      print("⚠️ uiDelegate was nil, reassigning...")
      nsView.uiDelegate = context.coordinator
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  private func createFallbackWebView() -> WKWebView {
    // ✓ Utiliser la configuration optimisée (cohérence > stealth)
    let configuration = OptimizedWebKitConfig.createConfiguration()

    // Use CustomWKWebView to disable rubber banding
    let webView = CustomWKWebView(frame: .zero, configuration: configuration)
    webView.downloadManager = viewModel.downloadManager

    // ✓ Setup avec User-Agent STABLE
    OptimizedWebKitConfig.setupWebView(webView)

    return webView
  }

  // SUPPRIMÉ: injectAdditionalStealthMeasures, reinjectStealthScripts
  // Les modifications JavaScript agressives sont DÉTECTÉES par OpenAI/Claude
  // WKWebView rapporte naturellement les bonnes propriétés (cohérentes avec macOS)

  class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var parent: WebViewRepresentable

    init(_ parent: WebViewRepresentable) {
      self.parent = parent
    }

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      parent.viewModel.updateTabState(tabId: parent.tabId, isLoading: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      parent.viewModel.updateTabState(
        tabId: parent.tabId,
        title: webView.title ?? "Untitled",
        url: webView.url,
        isLoading: false,
        canGoBack: webView.canGoBack,
        canGoForward: webView.canGoForward
      )

      // Add to history
      if let url = webView.url, let title = webView.title {
        parent.viewModel.addToHistory(url: url, title: title)
      }

      // ✓ Pas de détection CAPTCHA ni de ré-injection JavaScript
      // Ces opérations sont contre-productives et détectées par les systèmes anti-bot
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      parent.viewModel.updateTabState(tabId: parent.tabId, isLoading: false)
      handleNavigationError(error, in: webView)
    }

    func webView(
      _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      parent.viewModel.updateTabState(tabId: parent.tabId, isLoading: false)
      handleNavigationError(error, in: webView)
    }

    // MARK: - Download Handling
    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationResponse: WKNavigationResponse,
      decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
      let mimeType = navigationResponse.response.mimeType ?? "unknown"
      let canShow = navigationResponse.canShowMIMEType

      print("📥 decidePolicyFor navigationResponse - MIME: \(mimeType), canShow: \(canShow)")

      // Check if the response can be displayed in the web view
      if !canShow {
        // Non-displayable MIME type - let WKDownload handle it with progress monitoring
        print("📥 → Can't show MIME type, triggering WKDownload with progress monitoring")
        decisionHandler(.download)
      } else {
        // Normal content, display it
        decisionHandler(.allow)
      }
    }

    func webView(
      _ webView: WKWebView,
      navigationAction: WKNavigationAction,
      didBecome download: WKDownload
    ) {
      // This is a fallback - downloads should be intercepted at decidePolicyFor level
      print("📥 navigationAction didBecome download (fallback) - URL: \(download.originalRequest?.url?.absoluteString ?? "unknown")")

      // Use WKDownloadDelegate as fallback (no progress, but still works)
      download.delegate = parent.viewModel.downloadManager
      parent.viewModel.downloadManager.trackDownload(download)
    }

    func webView(
      _ webView: WKWebView,
      navigationResponse: WKNavigationResponse,
      didBecome download: WKDownload
    ) {
      // This is a fallback - downloads should be intercepted at decidePolicyFor level
      print("📥 navigationResponse didBecome download (fallback) - URL: \(download.originalRequest?.url?.absoluteString ?? "unknown")")

      // Use WKDownloadDelegate as fallback (no progress, but still works)
      download.delegate = parent.viewModel.downloadManager
      parent.viewModel.downloadManager.trackDownload(download)
    }

    // MARK: - Helper Methods
    // SUPPRIMÉ: detectCaptcha, reinjectStealthScripts
    // Ces méthodes sont contre-productives et détectées par les systèmes anti-bot

    private func handleNavigationError(_ error: Error, in webView: WKWebView) {
      let nsError = error as NSError

      // Handle specific error codes
      switch nsError.code {
      case NSURLErrorCancelled:
        // Navigation was cancelled, usually not an error
        break
      case NSURLErrorTimedOut:
        print("Navigation timed out for: \(webView.url?.absoluteString ?? "unknown URL")")
      case NSURLErrorNotConnectedToInternet:
        print("No internet connection")
      default:
        print("Navigation error (\(nsError.code)): \(nsError.localizedDescription)")
      }
    }

    func webView(
      _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
      preferences: WKWebpagePreferences,
      decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
      let urlString = navigationAction.request.url?.absoluteString ?? "unknown"
      print("📥 decidePolicyFor navigationAction - URL: \(urlString), shouldPerformDownload: \(navigationAction.shouldPerformDownload)")

      // Check if this is a download action (e.g., from context menu "Download Image")
      if navigationAction.shouldPerformDownload {
        print("📥 → shouldPerformDownload is true, triggering WKDownload with progress monitoring")
        decisionHandler(.download, preferences)
        return
      }

      // Handle special URLs
      if let url = navigationAction.request.url {
        // Open external apps for specific URL schemes
        if url.scheme == "mailto" || url.scheme == "tel" {
          NSWorkspace.shared.open(url)
          decisionHandler(.cancel, preferences)
          return
        }

        // Handle new window requests as new tabs
        if navigationAction.targetFrame == nil {
          parent.viewModel.createNewTab(url: url)
          decisionHandler(.cancel, preferences)
          return
        }
      }

      decisionHandler(.allow, preferences)
    }

    // MARK: - WKUIDelegate
    func webView(
      _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
      for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
      // Handle popups by opening in new tab
      if let url = navigationAction.request.url {
        parent.viewModel.createNewTab(url: url)
      }
      return nil
    }

    func webView(
      _ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
      initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void
    ) {
      let alert = NSAlert()
      alert.messageText = "Alert"
      alert.informativeText = message
      alert.addButton(withTitle: "OK")
      alert.runModal()
      completionHandler()
    }

    func webView(
      _ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
      initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void
    ) {
      let alert = NSAlert()
      alert.messageText = "Confirm"
      alert.informativeText = message
      alert.addButton(withTitle: "OK")
      alert.addButton(withTitle: "Cancel")
      let response = alert.runModal()
      completionHandler(response == .alertFirstButtonReturn)
    }

    func webView(
      _ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
      defaultText: String?, initiatedByFrame frame: WKFrameInfo,
      completionHandler: @escaping (String?) -> Void
    ) {
      let alert = NSAlert()
      alert.messageText = prompt
      alert.addButton(withTitle: "OK")
      alert.addButton(withTitle: "Cancel")

      let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
      textField.stringValue = defaultText ?? ""
      alert.accessoryView = textField

      let response = alert.runModal()
      if response == .alertFirstButtonReturn {
        completionHandler(textField.stringValue)
      } else {
        completionHandler(nil)
      }
    }
  }
}
