//
//  AppColors.swift
//  Cloud
//
//  Configuration centralisée des couleurs de l'application
//

import SwiftUI

struct AppColors {
  // MARK: - Couleurs principales

  /// Couleur de fond principale de l'application
  static let defaultBackground = Color(hex: "72B4FF")

  // MARK: - Boutons de contrôle de fenêtre (Traffic Lights)

  /// Bouton rouge - Fermer
  static let windowCloseButton = Color.red

  /// Bouton jaune - Minimiser
  static let windowMinimizeButton = Color.yellow

  /// Bouton vert - Maximiser/Zoom
  static let windowMaximizeButton = Color.green

  // MARK: - Boutons de navigation

  /// Couleur des boutons de navigation actifs (Back, Forward, Reload)
  static let navigationButtonActive = Color.black.opacity(0.6)

  /// Couleur des boutons de navigation désactivés
  static let navigationButtonDisabled = Color.black.opacity(0.4)

  /// Fond des boutons de navigation
  static let navigationButtonBackground = Color.black.opacity(0.2)

  // MARK: - Barre d'adresse

  /// Fond de la barre d'adresse
  static let addressBarBackground = Color.black.opacity(0.2)

  /// Texte de la barre d'adresse
  static let addressBarText = Color.black

  /// Bordure de la barre d'adresse
  static let addressBarBorder = Color.black.opacity(0.1)

  /// Bordure de la barre d'adresse en focus
  static let addressBarBorderFocused = Color.accentColor

  /// Icône de sécurité HTTPS (cadenas vert)
  static let securityIconHTTPS = Color.green

  /// Icône de sécurité HTTP (cadenas orange)
  static let securityIconHTTP = Color.orange

  // MARK: - Tabs et Espaces

  /// Fond des tabs actifs
  static let activeTabBackground = Color.accentColor.opacity(0.2)

  /// Bordure des tabs actifs (pinned)
  static let activeTabBorder = Color.accentColor

  /// Fond des tabs au survol
  static let hoverTabBackground = Color(nsColor: .controlBackgroundColor)

  /// Fond des boutons d'espace
  static let spaceButtonBackground = Color(nsColor: .controlBackgroundColor)

  // MARK: - Boutons d'action

  /// Couleur des icônes secondaires (settings, new tab, etc.)
  static let secondaryIcon = Color.secondary

  /// Couleur de l'étoile de bookmark active
  static let bookmarkActive = Color.yellow

  /// Couleur de l'étoile de bookmark inactive
  static let bookmarkInactive = Color.secondary

  // MARK: - Sidebar

  /// Fond de la sidebar (par défaut)
  static let defaultSidebarBackground = Color(hex: "72B4FF")

  /// Fond de la sidebar basé sur un thème
  static func sidebarBackground(for theme: SpaceTheme?) -> Color {
    guard let theme = theme else {
      return defaultSidebarBackground
    }
    return theme.sidebarBackground
  }

  /// Couleur de fond dynamique basée sur un thème
  static func background(for theme: SpaceTheme?) -> Color {
    guard let theme = theme else {
      return defaultBackground
    }
    return theme.sidebarBackground
  }

  // MARK: - WebView

  /// Ombre du WebView
  static let webViewShadow = Color.black.opacity(0.15)

  // MARK: - Spotlight Overlay

  /// Overlay noir semi-transparent du Spotlight
  static let spotlightOverlay = Color.black.opacity(0.3)
}

// MARK: - Extension pour faciliter l'utilisation

extension Color {
  static let appBackground = AppColors.defaultBackground
  static let appSidebar = AppColors.defaultSidebarBackground
}
