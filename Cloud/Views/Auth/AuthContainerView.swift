//
//  AuthContainerView.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import SwiftUI

struct AuthContainerView: View {
    @State private var showLogin = true

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Panel - Form
                ZStack {
                    Color.white

                    if showLogin {
                        LoginView(showLogin: $showLogin)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    } else {
                        RegisterView(showLogin: $showLogin)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(width: geometry.size.width * 0.5)
                .clipped()

                // Right Panel - Visual/Image Placeholder
                AuthRightPanelView()
                    .frame(width: geometry.size.width * 0.5)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showLogin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - Right Panel View

struct AuthRightPanelView: View {
    // Change this to your image name in Assets.xcassets
    private let imageName = "AuthBackground"

    var body: some View {
        ZStack {
            // Try to load custom image, fallback to gradient
            if let _ = NSImage(named: imageName) {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                // Fallback: Gradient Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "1e3a5f"),
                        Color(hex: "4c1d95"),
                        Color(hex: "7c3aed")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative Elements (only shown with gradient fallback)
                VStack(spacing: 32) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                    VStack(spacing: 12) {
                        Text("Welcome to Cloud")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        Text("A modern browsing experience\ndesigned for the future")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    VStack(spacing: 12) {
                        FeaturePillView(icon: "bolt.fill", text: "Lightning Fast")
                        FeaturePillView(icon: "lock.shield.fill", text: "Secure & Private")
                        FeaturePillView(icon: "arrow.triangle.2.circlepath", text: "Sync Everywhere")
                    }
                    .padding(.top, 24)
                }
                .padding(40)
            }
        }
    }
}

struct FeaturePillView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.15))
        .cornerRadius(20)
    }
}

// MARK: - Visual Effect Background (kept for compatibility)

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
