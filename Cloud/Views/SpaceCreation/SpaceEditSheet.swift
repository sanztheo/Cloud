//
//  SpaceEditSheet.swift
//  Cloud
//
//  Vue d'édition d'espace
//

import SwiftUI

struct SpaceEditSheet: View {
  let space: Space
  @Binding var isPresented: Bool
  @ObservedObject var viewModel: BrowserViewModel

  @State private var spaceName: String
  @State private var selectedEmoji: String
  @State private var selectedTheme: SpaceTheme
  @State private var showEmojiPicker: Bool = false

  init(space: Space, isPresented: Binding<Bool>, viewModel: BrowserViewModel) {
    self.space = space
    self._isPresented = isPresented
    self.viewModel = viewModel
    self._spaceName = State(initialValue: space.name)
    self._selectedEmoji = State(initialValue: space.icon)
    self._selectedTheme = State(initialValue: space.theme ?? SpaceTheme())
  }

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
        Text("Edit Space")
          .font(.system(size: 24, weight: .bold))
          .foregroundColor(.white)

        Text("Customize your space appearance and settings.")
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

      Button(action: updateSpace) {
        Text("Save Changes")
          .fontWeight(.semibold)
      }
      .keyboardShortcut(.return)
      .buttonStyle(.borderedProminent)
      .disabled(spaceName.isEmpty)
    }
  }

  private func updateSpace() {
    viewModel.updateSpace(
      id: space.id,
      name: spaceName,
      icon: selectedEmoji,
      color: selectedTheme.baseColor,
      theme: selectedTheme
    )
    isPresented = false
  }
}
