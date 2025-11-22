//
//  Color+Hex.swift
//  Cloud
//
//  Created by Sanz on 21/11/2025.
//

import SwiftUI
import AppKit

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3:  // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:  // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8:  // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }

    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }

  /// Convert Color to hex string
  /// - Returns: Hex string representation (e.g., "#0066FF")
  func toHex() -> String? {
    guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else {
      return nil
    }

    let red = Int(nsColor.redComponent * 255.0)
    let green = Int(nsColor.greenComponent * 255.0)
    let blue = Int(nsColor.blueComponent * 255.0)

    return String(format: "#%02X%02X%02X", red, green, blue)
  }

  /// Interpolate between two colors
  /// - Parameters:
  ///   - other: The target color to interpolate towards
  ///   - progress: The interpolation progress (0.0 = self, 1.0 = other)
  /// - Returns: A new Color interpolated between self and other
  func interpolate(to other: Color, progress: CGFloat) -> Color {
    let clampedProgress = max(0, min(1, progress))

    let fromNS = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
    let toNS = NSColor(other).usingColorSpace(.sRGB) ?? NSColor(other)

    let fromRed = fromNS.redComponent
    let fromGreen = fromNS.greenComponent
    let fromBlue = fromNS.blueComponent
    let fromAlpha = fromNS.alphaComponent

    let toRed = toNS.redComponent
    let toGreen = toNS.greenComponent
    let toBlue = toNS.blueComponent
    let toAlpha = toNS.alphaComponent

    return Color(
      red: Double(fromRed + (toRed - fromRed) * clampedProgress),
      green: Double(fromGreen + (toGreen - fromGreen) * clampedProgress),
      blue: Double(fromBlue + (toBlue - fromBlue) * clampedProgress),
      opacity: Double(fromAlpha + (toAlpha - fromAlpha) * clampedProgress)
    )
  }

  /// Adjust the brightness of a color
  /// - Parameter amount: The amount to adjust (-1.0 to 1.0). Negative values darken, positive values brighten.
  /// - Returns: A new Color with adjusted brightness
  func adjustedBrightness(by amount: Double) -> Color {
    // Convert SwiftUI Color to NSColor
    let nsColor = NSColor(self)

    // Get HSB components
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0

    nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

    // Adjust brightness (clamp between 0 and 1)
    let newBrightness = max(0, min(1, brightness + CGFloat(amount)))

    // Create new color with adjusted brightness
    return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(newBrightness), opacity: Double(alpha))
  }
}
