import SwiftUI

struct SummaryView: View {
  @ObservedObject var viewModel: BrowserViewModel

  // Computed property pour obtenir la couleur du bouton (background - 36% brightness)
  private var buttonColor: Color {
    let bgColor = AppColors.background(for: viewModel.activeSpace?.theme)
    return bgColor.adjustedBrightness(by: -0.36)
  }

  // Computed property pour la couleur du texte basée sur le mode du space/profil
  private var textColor: Color {
    guard let theme = viewModel.activeSpace?.theme else {
      return .black // Fallback si pas de theme (mode light par défaut)
    }

    switch theme.mode {
    case .light:
      return .black
    case .dark:
      return .white
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Main content area
      ZStack {
        if let error = viewModel.summaryError {
          // Error state
          errorView(error: error)
        } else if !viewModel.isSummaryComplete {
          // Loading state
          loadingView
        } else {
          // Summary display
          summaryContent
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      // Bottom action bar
      if viewModel.isSummaryComplete && viewModel.summaryError == nil {
        bottomActionBar
      }
    }
    .background(backgroundView)
  }

  // MARK: - Summary Content

  private var summaryContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Summary header
      HStack {
        Image(systemName: "doc.text.magnifyingglass")
          .font(.title2)
          .foregroundStyle(textColor)

        Text("Page Summary")
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundStyle(textColor)

        Spacer()
      }
      .padding(.bottom, 8)

      // Markdown content
      if !viewModel.summaryText.isEmpty {
        markdownText
      }
    }
    .padding(24)
  }

  private var markdownText: some View {
    Text(viewModel.summaryText)
      .font(.system(.body, design: .default))
      .lineSpacing(4)
      .textSelection(.enabled)
      .foregroundStyle(textColor)
      .animation(.easeInOut(duration: 0.2), value: viewModel.summaryText)
  }

  // MARK: - Loading View

  private var loadingView: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Centered loading indicator at top
      HStack {
        Spacer()
        VStack(spacing: 16) {
          // Animated loading indicator
          ZStack {
            Circle()
              .stroke(
                LinearGradient(
                  colors: [.teal, .blue],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 3
              )
              .frame(width: 60, height: 60)
              .rotationEffect(.degrees(360))
              .animation(
                Animation.linear(duration: 2)
                  .repeatForever(autoreverses: false),
                value: true
              )

            Image(systemName: "brain")
              .font(.title)
              .foregroundColor(.teal)
              .symbolEffect(.pulse)
          }

          VStack(spacing: 8) {
            Text("Analyzing Page")
              .font(.title3)
              .fontWeight(.semibold)
              .foregroundStyle(textColor)

            if !viewModel.summarizingStatus.isEmpty {
              Text(viewModel.summarizingStatus)
                .font(.callout)
                .foregroundStyle(textColor.opacity(0.7))
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: viewModel.summarizingStatus)
            }
          }
        }
        Spacer()
      }
      .padding(.bottom, !viewModel.summaryText.isEmpty ? 16 : 0)

      // Partial summary if available - same layout as completed summary
      if !viewModel.summaryText.isEmpty {
        markdownText
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .padding(24)
  }

  // MARK: - Error View

  private func errorView(error: String) -> some View {
    VStack(spacing: 24) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 48))
        .foregroundColor(.red)
        .symbolEffect(.bounce)

      VStack(spacing: 12) {
        Text("Summary Generation Failed")
          .font(.title3)
          .fontWeight(.semibold)
          .foregroundStyle(textColor)

        Text(error)
          .font(.callout)
          .foregroundStyle(textColor.opacity(0.7))
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }

      HStack(spacing: 16) {
        Button(action: {
          viewModel.restorePage()
        }) {
          Label("Go Back", systemImage: "arrow.backward")
            .font(.callout)
            .fontWeight(.medium)
        }
        .buttonStyle(SecondaryButtonStyle())

        Button(action: {
          // Retry summarization
          Task {
            await viewModel.summarizePage()
          }
        }) {
          Label("Try Again", systemImage: "arrow.clockwise")
            .font(.callout)
            .fontWeight(.medium)
        }
        .buttonStyle(PrimaryButtonStyle())
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(32)
  }

  // MARK: - Bottom Action Bar

  private var bottomActionBar: some View {
    HStack {
      // Summary complete indicator
      HStack(spacing: 8) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(.green)
          .font(.callout)

        Text("Summary Complete")
          .font(.callout)
          .foregroundStyle(textColor.opacity(0.7))
      }

      Spacer()

      // Restore page button
      Button(action: {
        viewModel.restorePage()
      }) {
        HStack(spacing: 8) {
          Text("Restore Page")
            .fontWeight(.medium)

          Image(systemName: "arrow.up.right")
            .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(buttonColor)
        .clipShape(Capsule())
      }
      .buttonStyle(ScaleButtonStyle())
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }

  // MARK: - Background

  private var backgroundView: some View {
    Color.clear
  }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(.white)
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      .background(
        LinearGradient(
          colors: [.teal, .blue],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .clipShape(Capsule())
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
  }
}

struct SecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(.primary)
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      .background(
        Capsule()
          .stroke(Color.white.opacity(0.2), lineWidth: 1)
          .background(
            Capsule()
              .fill(Color.white.opacity(0.05))
          )
      )
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
  }
}

struct ScaleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
  }
}

// MARK: - Preview

struct SummaryView_Previews: PreviewProvider {
  static var previews: some View {
    SummaryView(viewModel: BrowserViewModel())
      .frame(width: 800, height: 600)
  }
}
