//
//  ThemeSelector.swift
//  Cloud
//
//  Section complète de sélection de thème
//

import SwiftUI

struct ThemeSelector: View {
  @Binding var theme: SpaceTheme

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Choose a Theme")
        .font(.system(size: 16, weight: .semibold))

      // Prévisualisation
      ThemePreview(theme: theme)

      // Modes (clair/normal/sombre)
      themeModes

      // Palette de couleurs
      ColorPalette(selectedColorHex: $theme.baseColorHex)

      // Sliders
      ThemeSliders(
        hue: $theme.hue,
        saturation: $theme.saturation,
        noise: $theme.noiseIntensity
      )
    }
  }

  private var themeModes: some View {
    HStack(spacing: 8) {
      ThemeModeButton(
        icon: SpaceTheme.Mode.light.icon,
        label: SpaceTheme.Mode.light.label,
        isSelected: theme.mode == .light,
        action: { theme.mode = .light }
      )

      ThemeModeButton(
        icon: SpaceTheme.Mode.auto.icon,
        label: SpaceTheme.Mode.auto.label,
        isSelected: theme.mode == .auto,
        action: { theme.mode = .auto }
      )

      ThemeModeButton(
        icon: SpaceTheme.Mode.dark.icon,
        label: SpaceTheme.Mode.dark.label,
        isSelected: theme.mode == .dark,
        action: { theme.mode = .dark }
      )
    }
  }
}
