//
//  SpaceNameField.swift
//  Cloud
//
//  Champ de nom avec bouton emoji
//

import SwiftUI

struct SpaceNameField: View {
  @Binding var name: String
  @Binding var emoji: String
  var onEmojiTap: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      // Bouton emoji
      Button(action: onEmojiTap) {
        ZStack {
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.2))
            .frame(width: 56, height: 56)

          Text(emoji)
            .font(.system(size: 32))
        }
      }
      .buttonStyle(.plain)
      .help("Choose emoji")

      // Champ de texte
      TextField("Space name...", text: $name)
        .textFieldStyle(.plain)
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(.white)
        .padding(16)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
  }
}
