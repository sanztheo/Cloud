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
        let webView = viewModel.getWebView(for: tabId) ?? createFallbackWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Critical: Enable autoresizing to fill available space
        webView.autoresizingMask = [.width, .height]

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // WebView updates are handled through the view model
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func createFallbackWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = BrowserViewModel.chromeUserAgent
        return webView
    }

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
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.viewModel.updateTabState(tabId: parent.tabId, isLoading: false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.viewModel.updateTabState(tabId: parent.tabId, isLoading: false)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Handle special URLs
            if let url = navigationAction.request.url {
                // Open external apps for specific URL schemes
                if url.scheme == "mailto" || url.scheme == "tel" {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }

                // Handle new window requests as new tabs
                if navigationAction.targetFrame == nil {
                    parent.viewModel.createNewTab(url: url)
                    decisionHandler(.cancel)
                    return
                }
            }

            decisionHandler(.allow)
        }

        // MARK: - WKUIDelegate
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle popups by opening in new tab
            if let url = navigationAction.request.url {
                parent.viewModel.createNewTab(url: url)
            }
            return nil
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = "Alert"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = NSAlert()
            alert.messageText = "Confirm"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
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
