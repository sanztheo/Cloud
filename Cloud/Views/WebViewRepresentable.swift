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

        // Inject additional stealth measures after webView creation
        injectAdditionalStealthMeasures(into: webView)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // WebView updates are handled through the view model
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func createFallbackWebView() -> WKWebView {
        // Create enhanced configuration for fallback
        let configuration = createEnhancedConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)

        // Use a random user agent from the pool
        let userAgents = [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15"
        ]
        webView.customUserAgent = userAgents.randomElement() ?? userAgents[0]

        return webView
    }

    private func createEnhancedConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let preferences = WKPreferences()

        // Enable JavaScript
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences

        // Allow inline media playback
        configuration.mediaTypesRequiringUserActionForPlayback = []

        return configuration
    }

    private func injectAdditionalStealthMeasures(into webView: WKWebView) {
        // Additional runtime JavaScript injection for enhanced stealth
        let additionalScript = """
        (function() {
            // Override WebGL vendor and renderer to appear more natural
            const getParameter = WebGLRenderingContext.prototype.getParameter;
            WebGLRenderingContext.prototype.getParameter = function(parameter) {
                if (parameter === 37445) {
                    return 'Intel Inc.';
                }
                if (parameter === 37446) {
                    return 'Intel Iris OpenGL Engine';
                }
                return getParameter.apply(this, arguments);
            };

            // Add battery API
            if (!navigator.getBattery) {
                navigator.getBattery = function() {
                    return Promise.resolve({
                        charging: true,
                        chargingTime: 0,
                        dischargingTime: Infinity,
                        level: 1.0,
                        onchargingchange: null,
                        onchargingtimechange: null,
                        ondischargingtimechange: null,
                        onlevelchange: null
                    });
                };
            }

            // Override screen properties to match common resolutions
            Object.defineProperty(screen, 'availWidth', {
                get: () => 1920,
                configurable: true
            });
            Object.defineProperty(screen, 'availHeight', {
                get: () => 1080,
                configurable: true
            });
            Object.defineProperty(screen, 'width', {
                get: () => 1920,
                configurable: true
            });
            Object.defineProperty(screen, 'height', {
                get: () => 1080,
                configurable: true
            });

            // Add touch support false flag
            Object.defineProperty(navigator, 'maxTouchPoints', {
                get: () => 0,
                configurable: true
            });
        })();
        """

        webView.evaluateJavaScript(additionalScript) { _, error in
            if let error = error {
                print("Failed to inject additional stealth script: \(error)")
            }
        }
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

            // Check for CAPTCHA presence and log for debugging
            detectCaptcha(in: webView)

            // Re-inject stealth scripts after navigation to ensure they persist
            reinjectStealthScripts(into: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.viewModel.updateTabState(tabId: parent.tabId, isLoading: false)
            handleNavigationError(error, in: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.viewModel.updateTabState(tabId: parent.tabId, isLoading: false)
            handleNavigationError(error, in: webView)
        }

        // MARK: - Helper Methods

        private func detectCaptcha(in webView: WKWebView) {
            // JavaScript to detect common CAPTCHA implementations
            let captchaDetectionScript = """
            (function() {
                // Check for reCAPTCHA
                const hasRecaptcha = document.querySelector('.g-recaptcha') !== null ||
                                   document.querySelector('[data-sitekey]') !== null ||
                                   window.grecaptcha !== undefined;

                // Check for hCaptcha
                const hasHcaptcha = document.querySelector('.h-captcha') !== null ||
                                  window.hcaptcha !== undefined;

                // Check for Google's "I'm not a robot" checkbox
                const hasRobotCheck = document.body.innerHTML.includes("I'm not a robot") ||
                                    document.body.innerHTML.includes("I am not a robot");

                // Check for unusual verification pages
                const hasVerification = document.title.toLowerCase().includes('verify') ||
                                      document.title.toLowerCase().includes('captcha') ||
                                      document.body.innerHTML.toLowerCase().includes('unusual traffic');

                return {
                    detected: hasRecaptcha || hasHcaptcha || hasRobotCheck || hasVerification,
                    type: hasRecaptcha ? 'recaptcha' : hasHcaptcha ? 'hcaptcha' : hasRobotCheck ? 'robot' : hasVerification ? 'verification' : 'none'
                };
            })();
            """

            webView.evaluateJavaScript(captchaDetectionScript) { result, error in
                if let result = result as? [String: Any],
                   let detected = result["detected"] as? Bool,
                   detected {
                    let captchaType = result["type"] as? String ?? "unknown"
                    print("⚠️ CAPTCHA detected: \(captchaType) on \(webView.url?.absoluteString ?? "unknown URL")")
                    // Log this for debugging but continue operation
                    // The stealth measures should help avoid triggering CAPTCHAs
                }
            }
        }

        private func reinjectStealthScripts(into webView: WKWebView) {
            // Re-inject critical stealth measures that might be lost during navigation
            let persistenceScript = """
            (function() {
                // Ensure webdriver property stays masked
                if (navigator.webdriver !== undefined) {
                    Object.defineProperty(navigator, 'webdriver', {
                        get: () => undefined,
                        configurable: true
                    });
                }

                // Ensure chrome object exists
                if (!window.chrome || !window.chrome.runtime) {
                    window.chrome = window.chrome || {};
                    window.chrome.runtime = window.chrome.runtime || {};
                }
            })();
            """

            webView.evaluateJavaScript(persistenceScript) { _, _ in
                // Silent injection, no need to handle response
            }
        }

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
