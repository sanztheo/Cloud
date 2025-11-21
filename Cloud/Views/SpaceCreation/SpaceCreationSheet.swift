//
//  SpaceCreationSheet.swift
//  Cloud
//
//  Vue principale de création d'espace (Arc-style)
//

import SwiftUI

struct SpaceCreationSheet: View {
  @Binding var isPresented: Bool
  @ObservedObject var viewModel: BrowserViewModel

  @State private var spaceName: String = ""
  @State private var selectedEmoji: String = "📁"
  @State private var selectedTheme: SpaceTheme = SpaceTheme()
  @State private var showEmojiPicker: Bool = false

  var body: some View {
    ZStack {
      // Background
      Color.black
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // Header
        header
          .padding(.horizontal, 24)
          .padding(.top, 24)
          .padding(.bottom, 20)

        Divider()

        // Content
        ScrollView {
          VStack(spacing: 28) {
            // Nom + Emoji
            SpaceNameField(
              name: $spaceName,
              emoji: $selectedEmoji,
              onEmojiTap: { showEmojiPicker = true }
            )

            // Thème
            ThemeSelector(theme: $selectedTheme)
          }
          .padding(24)
        }

        Divider()

        // Actions
        actionButtons
          .padding(24)
      }
    }
    .frame(width: 540, height: 720)
    .sheet(isPresented: $showEmojiPicker) {
      EmojiPicker(selectedEmoji: $selectedEmoji)
    }
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Create a Space")
          .font(.system(size: 24, weight: .bold))
          .foregroundColor(.white)

        Text("Separate your tabs for life, work, projects, and more.")
          .font(.system(size: 13))
          .foregroundColor(.white.opacity(0.6))
      }

      Spacer()

      Button(action: { isPresented = false }) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 24))
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
  }

  private var actionButtons: some View {
    HStack(spacing: 12) {
      Button("Cancel") {
        isPresented = false
      }
      .keyboardShortcut(.escape)
      .buttonStyle(.plain)
      .foregroundColor(.white.opacity(0.7))
      .padding(.horizontal, 20)
      .padding(.vertical, 10)

      Spacer()

      Button(action: createSpace) {
        Text("Create Space")
          .fontWeight(.semibold)
      }
      .keyboardShortcut(.return)
      .buttonStyle(.borderedProminent)
      .disabled(spaceName.isEmpty)
    }
  }

  private func createSpace() {
    viewModel.createNewSpace(
      name: spaceName,
      icon: selectedEmoji,
      color: selectedTheme.baseColor,
      theme: selectedTheme
    )
    isPresented = false
  }
}
