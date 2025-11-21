//
//  ThemeComponents.swift
//  Cloud
//
//  Composants pour la sélection de thème
//

import SwiftUI

// MARK: - Theme Preview
struct ThemePreview: View {
  let theme: SpaceTheme

  var body: some View {
    ZStack {
      // Background avec gradient
      LinearGradient(
        colors: [theme.gradientStart, theme.gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      // Pattern de points
      DotPattern(
        color: theme.patternColor,
        spacing: 12,
        size: 2,
        opacity: theme.noiseIntensity
      )

      // Mini UI preview
      HStack(spacing: 12) {
        // Mini sidebar
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.white.opacity(0.15))
          .frame(width: 48)

        // Mini browser view
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.white.opacity(0.08))
      }
      .padding(16)
    }
    .frame(height: 140)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
  }
}

// MARK: - Color Palette
struct ColorPalette: View {
  @Binding var hue: Double
  @Binding var saturation: Double
  var mode: SpaceTheme.Mode

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Color")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.6))

      ColorPickerGrid(hue: $hue, saturation: $saturation, mode: mode)
    }
  }
}

// MARK: - Theme Mode Button
struct ThemeModeButton: View {
  let icon: String
  let label: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 20))
          .foregroundColor(isSelected ? .primary : .secondary)
          .frame(height: 24)

        Text(label)
          .font(.system(size: 11))
          .foregroundColor(isSelected ? .primary : .secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(
        isSelected
          ? Color.accentColor.opacity(0.15) : Color.black.opacity(0.05)
      )
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Theme Sliders
struct ThemeSliders: View {
  @Binding var hue: Double
  @Binding var saturation: Double
  @Binding var noise: Double

  var body: some View {
    VStack(spacing: 20) {
      // Hue slider avec gradient
      SliderRow(
        label: "Hue",
        value: $hue,
        range: 0...360,
        gradientColors: [
          .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red
        ]
      )

      // Saturation slider
      SliderRow(
        label: "Saturation",
        value: $saturation,
        range: 0...1,
        gradientColors: [.gray, Color(hex: "0066FF")]
      )

      // Noise slider
      SliderRow(
        label: "Texture",
        value: $noise,
        range: 0...1,
        gradientColors: [.gray.opacity(0.3), .gray]
      )
    }
  }
}

struct SliderRow: View {
  let label: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let gradientColors: [Color]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(label)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.secondary)

        Spacer()

        Text(formatValue())
          .font(.system(size: 11))
          .foregroundColor(.secondary.opacity(0.7))
      }

      ZStack(alignment: .leading) {
        // Background gradient
        Capsule()
          .fill(
            LinearGradient(
              colors: gradientColors,
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(height: 6)

        // Slider
        Slider(value: $value, in: range)
          .accentColor(.clear)
      }
    }
  }

  private func formatValue() -> String {
    if range.upperBound > 10 {
      return "\(Int(value))°"
    } else {
      return "\(Int(value * 100))%"
    }
  }
}
