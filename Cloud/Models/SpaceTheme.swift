//
//  SpaceTheme.swift
//  Cloud
//
//  Modèle pour les thèmes d'espaces (inspiré d'Arc Browser)
//

import SwiftUI

struct SpaceTheme: Equatable, Codable {
  // MARK: - Mode d'affichage
  enum Mode: String, CaseIterable, Codable {
    case light    // Mode clair (sparkle)
    case dark     // Mode sombre (moon)

    var icon: String {
      switch self {
      case .light: return "sparkles"
      case .dark: return "moon.fill"
      }
    }

    var label: String {
      switch self {
      case .light: return "Light"
      case .dark: return "Dark"
      }
    }
  }

  // MARK: - Propriétés
  var mode: Mode = .light
  var baseColorHex: String = "0066FF" // Couleur de base en hex (legacy)
  var hue: Double = 0.583 // 0-1 (210° / 360 = 0.583)
  var saturation: Double = 0.7 // 0-1
  var noiseIntensity: Double = 0.3 // 0-1 (texture)

  // MARK: - Couleurs calculées

  /// Brightness selon le mode
  private var modeBrightness: Double {
    switch mode {
    case .light:
      return 0.95 // Très lumineux
    case .dark:
      return 0.65 // Plus sombre
    }
  }

  var baseColor: Color {
    Color(hue: hue, saturation: saturation, brightness: modeBrightness)
  }

  /// Couleur de départ du gradient (plus saturée)
  var gradientStart: Color {
    Color(hue: hue, saturation: saturation, brightness: modeBrightness + 0.05)
  }

  /// Couleur de fin du gradient (plus claire)
  var gradientEnd: Color {
    Color(hue: hue, saturation: saturation * 0.6, brightness: min(1.0, modeBrightness + 0.13))
  }

  /// Couleur du pattern de points
  var patternColor: Color {
    Color.white.opacity(noiseIntensity * 0.4)
  }

  /// Couleur de fond pour la sidebar
  var sidebarBackground: Color {
    switch mode {
    case .light:
      return Color(hue: hue, saturation: saturation * 0.4, brightness: 0.95)
    case .dark:
      return Color(hue: hue, saturation: saturation * 0.9, brightness: 0.65)
    }
  }

  // MARK: - Couleurs prédéfinies (Arc-style)
  static let presetColors: [(name: String, hex: String)] = [
    ("Blue", "0066FF"),
    ("Purple", "8B5CF6"),
    ("Pink", "EC4899"),
    ("Red", "EF4444"),
    ("Orange", "F97316"),
    ("Yellow", "EAB308"),
    ("Green", "10B981"),
    ("Mint", "14B8A6"),
    ("Cyan", "06B6D4"),
    ("Indigo", "6366F1")
  ]

  static func preset(hex: String) -> SpaceTheme {
    SpaceTheme(baseColorHex: hex)
  }
}
