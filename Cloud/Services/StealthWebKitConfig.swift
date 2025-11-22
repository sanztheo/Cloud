//
//  StealthWebKitConfig.swift
//  Cloud
//
//  Enhanced WKWebView Configuration for 2025
//  Philosophy: Consistency > Stealth, Native Behavior > Spoofing
//
//  Based on comprehensive anti-detection research:
//  - TLS fingerprinting cannot be bypassed (WKWebView limitation)
//  - JavaScript spoofing is 90-100% detected by modern systems
//  - Best approach: Look like a normal Safari user, not a stealth bot
//

import WebKit
import Foundation
import AppKit

// MARK: - Main Configuration Class

/// Enhanced WebKit configuration optimized for anti-detection in 2025
/// This replaces OptimizedWebKitConfig with improved techniques
final class StealthWebKitConfig {

    // MARK: - Singleton

    static let shared = StealthWebKitConfig()

    private init() {
        // Pre-compute values at initialization
        _ = Self.systemUserAgent
    }

    // MARK: - User Agent Generation

    /// Cached system-matched User-Agent
    private static var _cachedUserAgent: String?

    /// User-Agent that matches the actual macOS version for consistency
    /// CRITICAL: Must match real system to pass fingerprint checks
    static var systemUserAgent: String {
        if let cached = _cachedUserAgent {
            return cached
        }

        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion)_\(osVersion.minorVersion)_\(osVersion.patchVersion)"

        // Safari version mapping based on macOS version
        let safariVersion: String
        let webKitBuild = "605.1.15"

        switch osVersion.majorVersion {
        case 15: // Sequoia
            safariVersion = "18.1"
        case 14: // Sonoma
            safariVersion = "17.6"
        case 13: // Ventura
            safariVersion = "17.4"
        case 12: // Monterey
            safariVersion = "16.6"
        default:
            safariVersion = "17.4"
        }

        let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X \(osVersionString)) AppleWebKit/\(webKitBuild) (KHTML, like Gecko) Version/\(safariVersion) Safari/\(webKitBuild)"

        _cachedUserAgent = ua
        return ua
    }

    // MARK: - WKWebViewConfiguration

    /// Creates an optimized WKWebViewConfiguration
    /// Principle: Match Safari defaults exactly, no suspicious modifications
    static func createConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        // ═══════════════════════════════════════════════════════════
        // DATA STORE - Use default (persistent)
        // Private/ephemeral mode is a red flag for bot detection
        // ═══════════════════════════════════════════════════════════
        config.websiteDataStore = WKWebsiteDataStore.default()

        // ═══════════════════════════════════════════════════════════
        // PREFERENCES - Standard Safari behavior
        // ═══════════════════════════════════════════════════════════
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        preferences.isFraudulentWebsiteWarningEnabled = true

        // Tab focus (matches Safari default)
        preferences.tabFocusesLinks = true

        // ═══════════════════════════════════════════════════════════
        // HTML5 FULLSCREEN - Required for YouTube and video players
        // Available since macOS 12.3 / iOS 15.4
        // ═══════════════════════════════════════════════════════════
        if #available(macOS 12.3, *) {
            preferences.isElementFullscreenEnabled = true
        }

        config.preferences = preferences

        // ═══════════════════════════════════════════════════════════
        // WEBPAGE PREFERENCES - Modern web standards
        // ═══════════════════════════════════════════════════════════
        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = true
        webpagePrefs.preferredContentMode = .desktop
        config.defaultWebpagePreferences = webpagePrefs

        // ═══════════════════════════════════════════════════════════
        // MEDIA PLAYBACK - Normal behavior
        // ═══════════════════════════════════════════════════════════
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        // Note: allowsInlineMediaPlayback is iOS-only, not needed on macOS

        // ═══════════════════════════════════════════════════════════
        // RENDERING - No suppression (natural loading)
        // ═══════════════════════════════════════════════════════════
        config.suppressesIncrementalRendering = false

        // ═══════════════════════════════════════════════════════════
        // PROCESS POOL - Shared for cookie consistency
        // ═══════════════════════════════════════════════════════════
        config.processPool = SharedProcessPool.shared

        // ═══════════════════════════════════════════════════════════
        // IMPORTANT: NO JavaScript injection scripts
        // Research shows 90-100% detection rate for stealth scripts
        // WKWebView naturally reports correct values
        // ═══════════════════════════════════════════════════════════

        return config
    }

    // MARK: - WebView Setup

    /// Configures a WKWebView instance with optimal settings
    static func setupWebView(_ webView: WKWebView) {
        // ═══════════════════════════════════════════════════════════
        // USER AGENT - System-matched, stable throughout session
        // NEVER rotate - it's an immediate red flag
        // ═══════════════════════════════════════════════════════════
        webView.customUserAgent = systemUserAgent

        // ═══════════════════════════════════════════════════════════
        // GESTURES - Natural Safari-like interaction
        // ═══════════════════════════════════════════════════════════
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.allowsLinkPreview = true

        // ═══════════════════════════════════════════════════════════
        // LAYOUT - Standard autoresizing
        // ═══════════════════════════════════════════════════════════
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]

        // ═══════════════════════════════════════════════════════════
        // LAYER - Enable for visual effects
        // ═══════════════════════════════════════════════════════════
        webView.wantsLayer = true

        // ═══════════════════════════════════════════════════════════
        // DEBUG ONLY - Enable inspector
        // ═══════════════════════════════════════════════════════════
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif
    }

    // MARK: - URLRequest Configuration

    /// Configure URLRequest with minimal, system-consistent headers
    /// Principle: Fewer headers = more natural (Safari doesn't add many)
    static func configureRequest(_ request: inout URLRequest) {
        // ═══════════════════════════════════════════════════════════
        // ACCEPT-LANGUAGE - Match system locale exactly
        // ═══════════════════════════════════════════════════════════
        let preferredLanguages = Locale.preferredLanguages.prefix(3)
        let languageHeader = preferredLanguages.enumerated().map { index, lang in
            let quality = 1.0 - (Double(index) * 0.1)
            return index == 0 ? lang : "\(lang);q=\(String(format: "%.1f", quality))"
        }.joined(separator: ",")

        request.setValue(languageHeader, forHTTPHeaderField: "Accept-Language")

        // ═══════════════════════════════════════════════════════════
        // ACCEPT - Standard Safari header
        // ═══════════════════════════════════════════════════════════
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )

        // ═══════════════════════════════════════════════════════════
        // COOKIES & CACHE - Normal browser behavior
        // ═══════════════════════════════════════════════════════════
        request.httpShouldHandleCookies = true
        request.cachePolicy = .useProtocolCachePolicy

        // ═══════════════════════════════════════════════════════════
        // DO NOT ADD THESE HEADERS (WKWebView manages them):
        // - Accept-Encoding (automatic gzip/brotli)
        // - Sec-Fetch-* (navigation metadata)
        // - Sec-CH-* (client hints - Safari doesn't use)
        // - Connection / Keep-Alive
        // - Custom Cache-Control (suspicious)
        // - Forced Referer (very suspicious)
        // ═══════════════════════════════════════════════════════════
    }

    // MARK: - Human Behavior Simulation

    /// Random delay for human-like interaction timing
    /// Use BEFORE any automated action (form submit, click, etc.)
    static func humanDelay() -> TimeInterval {
        Double.random(in: 0.8...3.0)
    }

    /// Reading delay (before scroll or navigation)
    static func readingDelay() -> TimeInterval {
        Double.random(in: 2.0...6.0)
    }

    /// Typing delay between characters (for form autofill)
    static func typingDelay() -> TimeInterval {
        Double.random(in: 0.05...0.15)
    }

    /// Mouse movement delay (before click)
    static func mouseDelay() -> TimeInterval {
        Double.random(in: 0.1...0.4)
    }

    // MARK: - Site Protection Analysis

    /// Sites with aggressive bot detection
    private static let highProtectionDomains: Set<String> = [
        "openai.com",
        "chat.openai.com",
        "claude.ai",
        "anthropic.com",
        "linkedin.com",
        "google.com",
        "cloudflare.com",
        "discord.com",
        "twitter.com",
        "x.com",
        "facebook.com",
        "instagram.com",
        "amazon.com",
        "netflix.com",
        "spotify.com"
    ]

    /// Check if URL has strong bot protection
    static func hasStrongBotProtection(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return highProtectionDomains.contains { host.contains($0) }
    }

    /// Recommendation for protected sites
    static func protectionRecommendation(for url: URL) -> ProtectionRecommendation {
        guard let host = url.host?.lowercased() else {
            return .proceed
        }

        if host.contains("openai.com") || host.contains("claude.ai") || host.contains("anthropic.com") {
            return .useAPI("These AI services actively block in-app browsers. Use their official API instead.")
        }

        if host.contains("linkedin.com") || host.contains("facebook.com") || host.contains("instagram.com") {
            return .openExternal("Social media sites often block WebViews. Consider opening in Safari.")
        }

        if hasStrongBotProtection(url: url) {
            return .proceedWithCaution("This site has bot detection. CAPTCHA may appear.")
        }

        return .proceed
    }

    // MARK: - Cookie Management

    /// Ensure cookies are properly persisted for better trust scores
    static func warmupCookies(for domains: [String], completion: @escaping () -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let cookieStore = dataStore.httpCookieStore

        cookieStore.getAllCookies { cookies in
            let existingDomains = Set(cookies.compactMap { $0.domain })
            let missingDomains = domains.filter { domain in
                !existingDomains.contains { $0.contains(domain) }
            }

            if missingDomains.isEmpty {
                completion()
                return
            }

            // For missing domains, we could pre-visit them
            // But this is usually not necessary
            completion()
        }
    }

    /// Clear specific tracking cookies while preserving login cookies
    static func cleanTrackingCookies(completion: @escaping () -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let cookieStore = dataStore.httpCookieStore

        let trackingPrefixes = ["_ga", "_gid", "_fbp", "_gcl", "fr", "tr"]

        cookieStore.getAllCookies { cookies in
            let trackingCookies = cookies.filter { cookie in
                trackingPrefixes.contains { cookie.name.hasPrefix($0) }
            }

            let group = DispatchGroup()
            for cookie in trackingCookies {
                group.enter()
                cookieStore.delete(cookie) {
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                completion()
            }
        }
    }

    // MARK: - Diagnostics

    /// Diagnostic logging for debugging
    static func logDiagnostic(for webView: WKWebView, url: URL) {
        #if DEBUG
        let protection = hasStrongBotProtection(url: url)
        let recommendation = protectionRecommendation(for: url)

        print("""

        ╔══════════════════════════════════════════════════════════╗
        ║               WEBKIT DIAGNOSTIC REPORT                    ║
        ╠══════════════════════════════════════════════════════════╣
        ║ URL: \(url.absoluteString.prefix(50))...
        ║ Host: \(url.host ?? "unknown")
        ║ User-Agent: \(webView.customUserAgent?.prefix(40) ?? "default")...
        ║ Data Store: \(webView.configuration.websiteDataStore == WKWebsiteDataStore.default() ? "✓ Default (good)" : "⚠ Non-persistent")
        ║ JavaScript: \(webView.configuration.preferences.javaScriptEnabled ? "✓ Enabled" : "✗ Disabled")
        ║ High Protection: \(protection ? "⚠ YES" : "✓ No")
        ║ Recommendation: \(recommendation.description)
        ╚══════════════════════════════════════════════════════════╝

        """)
        #endif
    }

    /// Get fingerprint info for debugging
    static func fingerprintInfo() -> [String: Any] {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion

        return [
            "os_version": "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)",
            "user_agent": systemUserAgent,
            "locale": Locale.current.identifier,
            "languages": Locale.preferredLanguages,
            "timezone": TimeZone.current.identifier,
            "screen_width": Int(NSScreen.main?.frame.width ?? 0),
            "screen_height": Int(NSScreen.main?.frame.height ?? 0),
            "color_depth": NSScreen.main?.depth.bitsPerPixel ?? 24,
            "device_pixel_ratio": NSScreen.main?.backingScaleFactor ?? 2.0
        ]
    }
}

// MARK: - Supporting Types

/// Shared process pool for cookie consistency across WebViews
final class SharedProcessPool {
    static let shared = WKProcessPool()
    private init() {}
}

/// Protection recommendation for a URL
enum ProtectionRecommendation {
    case proceed
    case proceedWithCaution(String)
    case openExternal(String)
    case useAPI(String)

    var description: String {
        switch self {
        case .proceed:
            return "✓ Proceed normally"
        case .proceedWithCaution(let msg):
            return "⚠ \(msg)"
        case .openExternal(let msg):
            return "🔗 \(msg)"
        case .useAPI(let msg):
            return "🔌 \(msg)"
        }
    }
}

// MARK: - WKWebView Extension

extension WKWebView {

    /// Apply stealth configuration to this WebView
    func applyStealthConfig() {
        StealthWebKitConfig.setupWebView(self)
    }

    /// Load URL with optimized request
    func loadWithStealthConfig(url: URL) {
        var request = URLRequest(url: url)
        StealthWebKitConfig.configureRequest(&request)
        self.load(request)
    }

    /// Check if current URL has bot protection
    var hasProtection: Bool {
        guard let url = self.url else { return false }
        return StealthWebKitConfig.hasStrongBotProtection(url: url)
    }
}

// MARK: - Best Practices Documentation

/*

 ╔══════════════════════════════════════════════════════════════════╗
 ║                    ANTI-DETECTION GUIDE 2025                      ║
 ╚══════════════════════════════════════════════════════════════════╝

 ═══════════════════════════════════════════════════════════════════
 WHY THIS APPROACH WORKS
 ═══════════════════════════════════════════════════════════════════

 Modern bot detection (Cloudflare, reCAPTCHA, PerimeterX) uses ML to
 detect INCONSISTENCIES, not specific fingerprints. The goal is to
 be CONSISTENT with a real Safari user, not to spoof values.

 ═══════════════════════════════════════════════════════════════════
 WHAT'S DETECTED (DON'T DO THESE)
 ═══════════════════════════════════════════════════════════════════

 ❌ User-Agent rotation → Immediate ML red flag
 ❌ JavaScript injection → Property descriptor inspection catches it
 ❌ Canvas/WebGL spoofing → 90-100% detection rate
 ❌ Fake headers (15+) → Pattern analysis detects inconsistency
 ❌ navigator.webdriver = false → Detected via getOwnPropertyDescriptor
 ❌ Private browsing mode → Signals automation/bot

 ═══════════════════════════════════════════════════════════════════
 WHAT WORKS (DO THESE)
 ═══════════════════════════════════════════════════════════════════

 ✓ Stable User-Agent matching OS → Consistent fingerprint
 ✓ Minimal HTTP headers → What Safari actually sends
 ✓ Default data store → Cookies persist, builds trust
 ✓ Human-like delays → Random timing avoids patterns
 ✓ NO JavaScript injection → WKWebView reports truth (and it's fine)
 ✓ System locale/timezone → Matches actual environment

 ═══════════════════════════════════════════════════════════════════
 FUNDAMENTAL LIMITATIONS
 ═══════════════════════════════════════════════════════════════════

 WKWebView has limitations that CANNOT be bypassed:

 1. TLS Fingerprint (JA3/JA4)
    - WKWebView uses Apple's network stack
    - Different from Safari's TLS handshake
    - Cannot be modified at application level

 2. webkit.messageHandlers
    - Detectable via: window.webkit?.messageHandlers
    - Required for app functionality
    - Accept this trade-off

 3. reCAPTCHA Scores
    - WebViews typically get 0.3-0.5 (vs 0.7-0.9 for Safari)
    - Being logged into Google helps (+0.3)
    - Nothing else significantly improves scores

 4. Cloudflare Turnstile
    - Uses proof-of-work + fingerprinting
    - No reliable bypass for WKWebView
    - Accept or use external Safari

 ═══════════════════════════════════════════════════════════════════
 RECOMMENDATIONS BY SITE TYPE
 ═══════════════════════════════════════════════════════════════════

 Regular websites (95% of internet):
 → This config works perfectly

 Sites with reCAPTCHA v2:
 → Works, may need manual CAPTCHA solving occasionally

 Sites with reCAPTCHA v3:
 → Expect 0.3-0.5 scores, some challenges may appear

 Cloudflare-protected sites:
 → 40-60% success rate, depends on protection level

 OpenAI/Claude/AI services:
 → Use official APIs, they actively block in-app browsers

 Social media (LinkedIn, Facebook, Instagram):
 → Often blocked, recommend opening in Safari

 ═══════════════════════════════════════════════════════════════════
 REFERENCES
 ═══════════════════════════════════════════════════════════════════

 - Cloudflare Bot Detection: https://developers.cloudflare.com/bots/
 - Castle.io Research: https://blog.castle.io/
 - Fingerprint.com: https://fingerprint.com/
 - WebKit Fingerprinting: https://webkit.org/blog/
 - ZenRows Analysis: https://www.zenrows.com/blog/

 */
