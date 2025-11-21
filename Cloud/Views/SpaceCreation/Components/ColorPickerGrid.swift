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
        // Gradient de couleurs harmonieuses
        LinearGradient(
          gradient: Gradient(stops: [
            .init(color: Color(hue: 0.0, saturation: 0.8, brightness: brightness), location: 0.0),
            .init(color: Color(hue: 0.08, saturation: 0.8, brightness: brightness), location: 0.14),
            .init(color: Color(hue: 0.15, saturation: 0.8, brightness: brightness), location: 0.28),
            .init(color: Color(hue: 0.33, saturation: 0.8, brightness: brightness), location: 0.42),
            .init(color: Color(hue: 0.55, saturation: 0.8, brightness: brightness), location: 0.57),
            .init(color: Color(hue: 0.6, saturation: 0.8, brightness: brightness), location: 0.71),
            .init(color: Color(hue: 0.75, saturation: 0.8, brightness: brightness), location: 0.85),
            .init(color: Color(hue: 1.0, saturation: 0.8, brightness: brightness), location: 1.0)
          ]),
          startPoint: .leading,
          endPoint: .trailing
        )
        .overlay(
          // Gradient de saturation (transparent en haut, blanc en bas)
          LinearGradient(
            gradient: Gradient(colors: [
              Color.white.opacity(0.0),
              Color.white.opacity(0.3)
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))

        // Cercle de sélection
        Circle()
          .fill(Color.white)
          .frame(width: 24, height: 24)
          .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
          .overlay(
            Circle()
              .stroke(Color.white.opacity(0.5), lineWidth: 2)
              .frame(width: 28, height: 28)
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
    .aspectRatio(1, contentMode: .fit) // Carré
  }

  private func updateDragPosition(size: CGSize) {
    dragPosition = CGPoint(
      x: CGFloat(hue) * size.width,
      y: (1 - CGFloat(saturation)) * size.height
    )
  }

  private func updateColor(at location: CGPoint, in size: CGSize) {
    // Limiter la position dans les bounds
    let x = max(0, min(location.x, size.width))
    let y = max(0, min(location.y, size.height))

    dragPosition = CGPoint(x: x, y: y)

    // Calculer hue (0-1) basé sur X
    hue = Double(x / size.width)

    // Calculer saturation (0-1) basé sur Y (inversé)
    saturation = Double(1 - (y / size.height))

    // Assurer que la saturation reste dans une plage harmonieuse
    saturation = max(0.4, min(saturation, 1.0))
  }
}

struct ColorPickerGrid_Previews: PreviewProvider {
  static var previews: some View {
    ColorPickerGrid(hue: .constant(0.5), saturation: .constant(0.7), mode: .auto)
      .padding()
      .background(Color.black)
  }
}
