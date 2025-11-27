//
//  WaveDivider.swift
//  Cloud
//
//  Animated wave divider using sin() for Tidy feature.
//

import SwiftUI

// MARK: - Wave Divider Shape
struct WaveShape: Shape {
  var phase: CGFloat
  var amplitude: CGFloat
  var frequency: CGFloat

  var animatableData: CGFloat {
    get { phase }
    set { phase = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let midY = rect.midY
    let width = rect.width

    path.move(to: CGPoint(x: 0, y: midY))

    // Draw wave using sin()
    for x in stride(from: 0, through: width, by: 1) {
      let relativeX = x / width
      let sine = sin((relativeX * frequency * .pi * 2) + phase)
      let y = midY + (sine * amplitude)
      path.addLine(to: CGPoint(x: x, y: y))
    }

    return path
  }
}

// MARK: - Animated Wave Divider
struct WaveDivider: View {
  let color: Color
  let isAnimating: Bool

  @State private var phase: CGFloat = 0
  @State private var amplitude: CGFloat = 0

  private let maxAmplitude: CGFloat = 3
  private let frequency: CGFloat = 3

  var body: some View {
    ZStack {
      // Static line (always visible)
      Rectangle()
        .fill(color)
        .frame(height: 1)
        .opacity(isAnimating ? 0 : 1)

      // Animated wave
      if isAnimating {
        WaveShape(phase: phase, amplitude: amplitude, frequency: frequency)
          .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
          .frame(height: maxAmplitude * 2 + 2)
      }
    }
    .frame(height: isAnimating ? maxAmplitude * 2 + 2 : 1)
    .onChange(of: isAnimating) { _, newValue in
      if newValue {
        startAnimation()
      } else {
        stopAnimation()
      }
    }
  }

  private func startAnimation() {
    // Fade in amplitude
    withAnimation(.easeOut(duration: 0.2)) {
      amplitude = maxAmplitude
    }

    // Continuous wave movement
    withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
      phase = .pi * 2
    }
  }

  private func stopAnimation() {
    // Fade out amplitude
    withAnimation(.easeIn(duration: 0.3)) {
      amplitude = 0
    }

    // Reset phase after fade out
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      phase = 0
    }
  }
}

#Preview {
  VStack(spacing: 20) {
    WaveDivider(color: .gray.opacity(0.5), isAnimating: false)
      .padding(.horizontal)

    WaveDivider(color: .blue.opacity(0.5), isAnimating: true)
      .padding(.horizontal)
  }
  .frame(width: 200, height: 100)
  .background(Color.gray.opacity(0.1))
}
