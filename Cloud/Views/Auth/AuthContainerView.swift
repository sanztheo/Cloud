//
//  AuthContainerView.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import SwiftUI

struct AuthContainerView: View {
    @State private var showRegister = false

    var body: some View {
        ZStack {
            // Background
            AuthVisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Content
            VStack {
                if showRegister {
                    RegisterView(showRegister: $showRegister)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    LoginView(showRegister: $showRegister)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showRegister)
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}

// Visual Effect Background
struct AuthVisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}