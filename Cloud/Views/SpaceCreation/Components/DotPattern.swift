//
//  DotPattern.swift
//  Cloud
//
//  Pattern de points pour la prévisualisation des thèmes
//

import SwiftUI

struct DotPattern: View {
  let color: Color
  let spacing: CGFloat
  let size: CGFloat
  let opacity: Double

  init(
    color: Color = .white,
    spacing: CGFloat = 12,
    size: CGFloat = 2,
    opacity: Double = 0.3
  ) {
    self.color = color
    self.spacing = spacing
    self.size = size
    self.opacity = opacity
  }

  var body: some View {
    GeometryReader { geometry in
      Canvas { context, size in
        let columns = Int(size.width / spacing)
        let rows = Int(size.height / spacing)

        for row in 0..<rows {
          for column in 0..<columns {
            let x = CGFloat(column) * spacing + spacing / 2
            let y = CGFloat(row) * spacing + spacing / 2

            context.fill(
              Circle().path(
                in: CGRect(
                  x: x - self.size / 2,
                  y: y - self.size / 2,
                  width: self.size,
                  height: self.size
                )
              ),
              with: .color(color.opacity(opacity))
            )
          }
        }
      }
    }
  }
}
