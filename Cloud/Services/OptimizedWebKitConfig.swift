//
//  OptimizedWebKitConfig.swift
//  Cloud
//
//  Configuration WebKit optimale pour 2025
//  Approche: Cohérence maximale > Stealth agressif
//

import WebKit
import Foundation

/// Configuration WebKit optimisée pour éviter la détection tout en restant cohérent
/// Basée sur les meilleures pratiques 2025 pour WKWebView
class OptimizedWebKitConfig {

    // MARK: - User Agent

    /// User-Agent STABLE pour toute la session
    /// IMPORTANT: Ne JAMAIS faire de rotation - c'est un red flag immédiat
    static let stableUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    // MARK: - Configuration WKWebView

    /// Crée une configuration WKWebView optimale
    static func createConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        // ✓ DataStore standard (pas de mode "private" suspect)
        config.websiteDataStore = WKWebsiteDataStore.default()

        // ✓ Préférences JavaScript standard
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences

        // ✓ Media playback normal
        config.mediaTypesRequiringUserActionForPlayback = []

        // ✓ AirPlay autorisé
        config.allowsAirPlayForMediaPlayback = true

        // ✓ Pas de suppression de rendu incrémental
        config.suppressesIncrementalRendering = false

        // IMPORTANT: Pas de script d'injection ici
        // WKWebView rapporte naturellement les bonnes propriétés

        return config
    }

    // MARK: - URLRequest Configuration

    /// Configure une URLRequest avec des en-têtes cohérents et minimaux
    /// IMPORTANT: Moins d'en-têtes = plus naturel
    static func configureRequest(_ request: inout URLRequest) {
        // ✓ Accept-Language cohérent avec le système
        request.setValue("en-US,en;q=0.9,fr;q=0.8", forHTTPHeaderField: "Accept-Language")

        // ✓ Accept standard Safari
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )

        // ✓ Cookies et cache: comportement normal
        request.httpShouldHandleCookies = true
        request.cachePolicy = .useProtocolCachePolicy

        // IMPORTANT: Ne PAS ajouter ces en-têtes (WKWebView les gère):
        // - Accept-Encoding (gzip/brotli automatique)
        // - Sec-Fetch-* (métadonnées de navigation)
        // - Sec-CH-* (User-Agent Client Hints)
        // - Connection, Keep-Alive
        // - Cache-Control custom (suspect)
        // - Referer forcé (encore plus suspect)
    }

    // MARK: - WebView Setup

    /// Configure un WKWebView avec les paramètres optimaux
    static func setupWebView(_ webView: WKWebView) {
        // ✓ User-Agent STABLE
        webView.customUserAgent = stableUserAgent

        // ✓ Gestures naturels
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.allowsLinkPreview = true

        // ✓ Autoresizing
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]
    }

    // MARK: - Human-like Behavior Helpers

    /// Génère un délai aléatoire pour simuler un comportement humain
    /// Utiliser AVANT toute action automatique (click, scroll, etc.)
    static func humanDelay() -> TimeInterval {
        // Délai variable entre 0.5 et 2.5 secondes
        return Double.random(in: 0.5...2.5)
    }

    /// Génère un délai aléatoire pour la lecture (avant scroll ou click)
    static func readingDelay() -> TimeInterval {
        // Temps de "lecture" humain: 1-5 secondes
        return Double.random(in: 1.0...5.0)
    }

    // MARK: - Validation

    /// Vérifie si une URL est susceptible d'avoir une protection anti-bot forte
    static func hasStrongBotProtection(url: URL) -> Bool {
        let protectedDomains = [
            "openai.com",
            "claude.ai",
            "anthropic.com",
            "chat.openai.com"
        ]

        return protectedDomains.contains { domain in
            url.host?.contains(domain) ?? false
        }
    }

    /// Log de diagnostic (à utiliser pendant le développement)
    static func logDiagnostic(for webView: WKWebView, url: URL) {
        print("""

        🔍 WebKit Diagnostic:
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        URL: \(url.absoluteString)
        User-Agent: \(webView.customUserAgent ?? "default")
        Cookies enabled: \(webView.configuration.websiteDataStore == WKWebsiteDataStore.default())
        JavaScript enabled: \(webView.configuration.preferences.javaScriptEnabled)
        Strong protection: \(hasStrongBotProtection(url: url))
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        """)
    }
}

// MARK: - Best Practices Documentation

/*

 📚 DOCUMENTATION: Pourquoi Cette Approche Fonctionne
 ═══════════════════════════════════════════════════

 ## Problème avec l'Approche "Stealth" Agressive:

 ❌ Rotation d'User-Agent → Incohérence détectable immédiatement
 ❌ Faux en-têtes HTTP (15+) → Patterns suspects pour ML
 ❌ JavaScript masquant navigator.* → Tests de détection échouent
 ❌ Propriétés fixes (screen, WebGL) → Incohérence avec l'OS réel
 ❌ Referer forcé "google.com" → Pas naturel pour tous les sites

 ## Solution: Cohérence Maximale

 ✓ User-Agent STABLE (pas de rotation)
 ✓ En-têtes MINIMAUX (seuls les essentiels)
 ✓ Pas de masquage JavaScript (WKWebView rapporte la vérité)
 ✓ Propriétés natives (cohérentes avec macOS réel)
 ✓ Comportement avec délais variables (humain-like)

 ## Comment les Sites Détectent en 2025:

 1. TLS Fingerprinting (JA3/JA4) - Niveau transport
    → WKWebView a son empreinte native (acceptable)

 2. Machine Learning - Analyse de centaines de signaux
    → Cherche les INCOHÉRENCES, pas la perfection

 3. Analyse Comportementale - Timing, mouvements
    → Patterns trop réguliers = bot obvious

 4. Signaux de Réputation - IP, historique
    → IP résidentielle = OK

 5. Signaux Contextuels - Timezone, langue, géo
    → Cohérence système = OK

 ## Pourquoi OpenAI/Claude Peuvent Quand Même Bloquer:

 WKWebView est identifiable comme "in-app browser" au niveau TLS.
 Certains sites peuvent choisir de bloquer TOUS les in-app browsers.

 Solution ultime: API officielle (seule garantie 100%)

 ## Références:

 - Castle.io: Bot Detection 2025
 - Cloudflare: Bot Management Docs
 - WebKit: Fingerprinting Prevention
 - Mozilla: WKWebView Considerations

 */
