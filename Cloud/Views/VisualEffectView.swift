//
//  VisualEffectView.swift
//  Cloud
//
//  Created by Sanz on 21/11/2025.
//

import AppKit
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
  let material: NSVisualEffectView.Material
  let blendingMode: NSVisualEffectView.BlendingMode
  let state: NSVisualEffectView.State

  init(
    material: NSVisualEffectView.Material = .sidebar,
    blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
    state: NSVisualEffectView.State = .followsWindowActiveState
  ) {
    self.material = material
    self.blendingMode = blendingMode
    self.state = state
  }

  func makeNSView(context: Context) -> NSVisualEffectView {
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
    visualEffectView.state = state
    return visualEffectView
  }

  func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
    visualEffectView.state = state
  }
}
