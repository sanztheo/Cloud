//
//  ColorPickerGrid.swift
//  Cloud
//
//  Sélecteur de couleur 2D avec couleurs harmonieuses
//

import SwiftUI

struct ColorPickerGrid: View {
  @Binding var hue: Double
  @Binding var saturation: Double
  var mode: SpaceTheme.Mode

  @State private var dragPosition: CGPoint = .zero

  // Brightness basé sur le mode
  private var brightness: Double {
    switch mode {
    case .light:
      return 0.95 // Très lumineux
    case .auto:
      return 0.85 // Normal
    case .dark:
      return 0.65 // Plus sombre
    }
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Gradient de couleurs harmonieuses (spectre complet)
        LinearGradient(
          gradient: Gradient(stops: [
            .init(color: Color(hue: 0.0, saturation: 1.0, brightness: brightness), location: 0.0),      // Rouge
            .init(color: Color(hue: 0.083, saturation: 1.0, brightness: brightness), location: 0.083),  // Orange
            .init(color: Color(hue: 0.167, saturation: 1.0, brightness: brightness), location: 0.167),  // Jaune
            .init(color: Color(hue: 0.25, saturation: 1.0, brightness: brightness), location: 0.25),    // Jaune-Vert
            .init(color: Color(hue: 0.333, saturation: 1.0, brightness: brightness), location: 0.333),  // Vert
            .init(color: Color(hue: 0.417, saturation: 1.0, brightness: brightness), location: 0.417),  // Cyan-Vert
            .init(color: Color(hue: 0.5, saturation: 1.0, brightness: brightness), location: 0.5),      // Cyan
            .init(color: Color(hue: 0.583, saturation: 1.0, brightness: brightness), location: 0.583),  // Bleu clair
            .init(color: Color(hue: 0.667, saturation: 1.0, brightness: brightness), location: 0.667),  // Bleu
            .init(color: Color(hue: 0.75, saturation: 1.0, brightness: brightness), location: 0.75),    // Violet
            .init(color: Color(hue: 0.833, saturation: 1.0, brightness: brightness), location: 0.833),  // Magenta
            .init(color: Color(hue: 0.917, saturation: 1.0, brightness: brightness), location: 0.917),  // Rose
            .init(color: Color(hue: 1.0, saturation: 1.0, brightness: brightness), location: 1.0)       // Rouge
          ]),
          startPoint: .leading,
          endPoint: .trailing
        )
        .overlay(
          // Gradient vertical (saturé en haut, désaturé en bas)
          LinearGradient(
            gradient: Gradient(colors: [
              Color.clear,
              Color.white
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .overlay(
          // Grille de points comme Arc
          DotGridPattern()
            .opacity(0.15)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))

        // Cercle de sélection
        Circle()
          .fill(Color.white)
          .frame(width: 28, height: 28)
          .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
          .overlay(
            Circle()
              .stroke(Color.white, lineWidth: 3)
              .frame(width: 36, height: 36)
          )
          .position(dragPosition)
      }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            updateColor(at: value.location, in: geometry.size)
          }
      )
      .onAppear {
        updateDragPosition(size: geometry.size)
      }
      .onChange(of: hue) { _ in
        updateDragPosition(size: geometry.size)
      }
      .onChange(of: saturation) { _ in
        updateDragPosition(size: geometry.size)
      }
    }
    .frame(height: 240) // Taille fixe réduite
    .aspectRatio(1, contentMode: .fit) // Carré
  }

  private func updateDragPosition(size: CGSize) {
    // Limiter dans les bounds
    let x = max(0, min(CGFloat(hue) * size.width, size.width))
    let y = max(0, min((1 - CGFloat(saturation)) * size.height, size.height))

    dragPosition = CGPoint(x: x, y: y)
  }

  private func updateColor(at location: CGPoint, in size: CGSize) {
    // Limiter strictement la position dans les bounds
    let x = max(0, min(location.x, size.width))
    let y = max(0, min(location.y, size.height))

    dragPosition = CGPoint(x: x, y: y)

    // Calculer hue (0-1) basé sur X
    hue = Double(x / size.width)

    // Calculer saturation (0-1) basé sur Y (inversé)
    saturation = Double(1 - (y / size.height))

    // Assurer que la saturation reste dans une plage harmonieuse
    saturation = max(0.3, min(saturation, 1.0))
  }
}

// MARK: - Dot Grid Pattern
struct DotGridPattern: View {
  var body: some View {
    Canvas { context, size in
      let spacing: CGFloat = 8
      let dotSize: CGFloat = 1.5

      for x in stride(from: 0, through: size.width, by: spacing) {
        for y in stride(from: 0, through: size.height, by: spacing) {
          let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
          context.fill(Path(ellipseIn: rect), with: .color(.white))
        }
      }
    }
  }
}

struct ColorPickerGrid_Previews: PreviewProvider {
  static var previews: some View {
    ColorPickerGrid(hue: .constant(0.5), saturation: .constant(0.7), mode: .auto)
      .padding()
      .background(Color.black)
  }
}
