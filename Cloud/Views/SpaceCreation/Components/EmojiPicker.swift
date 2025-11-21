//
//  EmojiPicker.swift
//  Cloud
//
//  Sélecteur d'emoji avec recherche
//

import SwiftUI

struct EmojiPicker: View {
  @Binding var selectedEmoji: String
  @Environment(\.dismiss) private var dismiss
  @State private var searchText: String = ""
  @State private var selectedCategory: EmojiCategory = .smileys

  enum EmojiCategory: String, CaseIterable {
    case smileys = "Smileys"
    case objects = "Objects"
    case nature = "Nature"
    case symbols = "Symbols"

    var icon: String {
      switch self {
      case .smileys: return "😀"
      case .objects: return "📁"
      case .nature: return "🌱"
      case .symbols: return "✨"
      }
    }

    var emojis: [String] {
      switch self {
      case .smileys:
        return [
          "😀", "😃", "😄", "😊", "🙂", "😇", "🥰", "😍", "🤩", "😎",
          "🤓", "🧐", "🤔", "🤨", "😐", "😑", "🙄", "😏", "😴", "😌"
        ]
      case .objects:
        return [
          "📁", "📂", "🗂️", "📋", "📝", "✏️", "🖊️", "📌", "📍", "🔖",
          "📚", "📖", "📕", "📗", "📘", "📙", "💼", "🎒", "👜", "🛍️"
        ]
      case .nature:
        return [
          "🌱", "🌿", "🍀", "🌵", "🌴", "🌲", "🌳", "🌾", "🌺", "🌸",
          "🌼", "🌻", "🌞", "🌝", "🌛", "⭐", "✨", "💫", "🌟", "🔥"
        ]
      case .symbols:
        return [
          "✨", "💎", "🔮", "🎯", "🎨", "🎭", "🎪", "🎬", "🎮", "🎲",
          "🎯", "🎳", "🎸", "🎹", "🎺", "🎻", "🎤", "🎧", "🎼", "🎵"
        ]
      }
    }
  }

  var filteredEmojis: [String] {
    if searchText.isEmpty {
      return selectedCategory.emojis
    }
    return selectedCategory.emojis  // Simplified for now
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header
      header

      // Search bar
      searchBar

      // Category tabs
      categoryTabs

      // Emoji grid
      ScrollView {
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
          spacing: 8
        ) {
          ForEach(filteredEmojis, id: \.self) { emoji in
            emojiButton(emoji)
          }
        }
        .padding(16)
      }
    }
    .frame(width: 420, height: 480)
    .background(Color(nsColor: .windowBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  private var header: some View {
    HStack {
      Text("Choose Emoji")
        .font(.system(size: 16, weight: .semibold))

      Spacer()

      Button(action: { dismiss() }) {
        Image(systemName: "xmark.circle.fill")
          .foregroundColor(.secondary)
          .font(.system(size: 20))
      }
      .buttonStyle(.plain)
    }
    .padding(16)
  }

  private var searchBar: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundColor(.secondary)

      TextField("Search", text: $searchText)
        .textFieldStyle(.plain)
    }
    .padding(10)
    .background(Color.black.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
  }

  private var categoryTabs: some View {
    HStack(spacing: 4) {
      ForEach(EmojiCategory.allCases, id: \.self) { category in
        Button(action: { selectedCategory = category }) {
          Text(category.icon)
            .font(.system(size: 24))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
              selectedCategory == category
                ? Color.accentColor.opacity(0.2) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
  }

  private func emojiButton(_ emoji: String) -> some View {
    Button(action: {
      selectedEmoji = emoji
      dismiss()
    }) {
      Text(emoji)
        .font(.system(size: 32))
        .frame(width: 44, height: 44)
        .background(
          selectedEmoji == emoji
            ? Color.accentColor.opacity(0.2) : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }
}
