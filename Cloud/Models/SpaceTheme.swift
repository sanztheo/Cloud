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
    case auto     // Mode automatique (sun)
    case dark     // Mode sombre (moon)

    var icon: String {
      switch self {
      case .light: return "sparkles"
      case .auto: return "sun.max.fill"
      case .dark: return "moon.fill"
      }
    }

    var label: String {
      switch self {
      case .light: return "Light"
      case .auto: return "Auto"
      case .dark: return "Dark"
      }
    }
  }

  // MARK: - Propriétés
  var mode: Mode = .auto
  var baseColorHex: String = "0066FF" // Couleur de base en hex
  var hue: Double = 210 // 0-360 degrés
  var saturation: Double = 0.7 // 0-1
  var noiseIntensity: Double = 0.3 // 0-1 (texture)

  // MARK: - Couleurs calculées
  var baseColor: Color {
    Color(hex: baseColorHex)
  }

  /// Couleur de départ du gradient (plus saturée)
  var gradientStart: Color {
    adjustedColor(baseSaturation: saturation, brightnessAdjust: 0.1)
  }

  /// Couleur de fin du gradient (plus claire)
  var gradientEnd: Color {
    adjustedColor(baseSaturation: saturation * 0.6, brightnessAdjust: 0.3)
  }

  /// Couleur du pattern de points
  var patternColor: Color {
    Color.white.opacity(noiseIntensity * 0.4)
  }

  /// Couleur de fond pour la sidebar
  var sidebarBackground: Color {
    switch mode {
    case .light:
      return adjustedColor(baseSaturation: saturation * 0.4, brightnessAdjust: 0.5)
    case .auto:
      return adjustedColor(baseSaturation: saturation * 0.7, brightnessAdjust: 0)
    case .dark:
      return adjustedColor(baseSaturation: saturation * 0.9, brightnessAdjust: -0.3)
    }
  }

  // MARK: - Méthodes helper

  /// Ajuste la couleur en fonction de la saturation et de la luminosité
  private func adjustedColor(baseSaturation: Double, brightnessAdjust: Double) -> Color {
    let uiColor = NSColor(baseColor)
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0

    uiColor.usingColorSpace(.deviceRGB)?.getHue(
      &hue,
      saturation: &saturation,
      brightness: &brightness,
      alpha: &alpha
    )

    let newHue = CGFloat(self.hue) / 360.0
    let newSaturation = CGFloat(baseSaturation)
    let newBrightness = max(0, min(1, brightness + CGFloat(brightnessAdjust)))

    return Color(
      hue: newHue,
      saturation: newSaturation,
      brightness: newBrightness
    )
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
