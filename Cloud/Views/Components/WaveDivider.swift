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

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(phase, amplitude) }
    set {
      phase = newValue.first
      amplitude = newValue.second
    }
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
  @State private var waveOpacity: CGFloat = 0

  private let maxAmplitude: CGFloat = 3
  private let frequency: CGFloat = 3

  var body: some View {
    ZStack {
      // Static line - fades out when animating
      Rectangle()
        .fill(color)
        .frame(height: 1)
        .opacity(1 - waveOpacity)

      // Animated wave - always present, controlled by opacity
      WaveShape(phase: phase, amplitude: amplitude, frequency: frequency)
        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        .frame(height: maxAmplitude * 2 + 2)
        .opacity(waveOpacity)
    }
    .frame(height: maxAmplitude * 2 + 2)
    .clipped()
    .onChange(of: isAnimating) { _, newValue in
      if newValue {
        startAnimation()
      } else {
        stopAnimation()
      }
    }
  }

  private func startAnimation() {
    // Smooth fade in wave and fade out line
    withAnimation(.easeOut(duration: 0.3)) {
      waveOpacity = 1
      amplitude = maxAmplitude
    }

    // Start continuous wave movement after a tiny delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
        phase = .pi * 2
      }
    }
  }

  private func stopAnimation() {
    // Stop the repeating animation by setting to current value
    withAnimation(.easeIn(duration: 0.3)) {
      amplitude = 0
      waveOpacity = 0
    }

    // Reset phase after fade out completes
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      withAnimation(nil) {
        phase = 0
      }
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
