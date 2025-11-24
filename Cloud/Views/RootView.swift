//
//  RootView.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import SwiftUI
import Auth

struct RootView: View {
    @StateObject private var supabaseService = SupabaseService.shared

    var body: some View {
        ZStack {
            switch supabaseService.authState {
            case .unknown:
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)

                    Text("Chargement...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))

            case .signedOut:
                AuthContainerView()
                    .ignoresSafeArea(.all)
                    .transition(.opacity)

            case .signedIn:
                BrowserView()
                    .transition(.opacity.animation(.easeOut(duration: 0.3)))
            }
        }
        .animation(.default, value: supabaseService.authState.discriminator)
        .onAppear {
            Task {
                await supabaseService.checkSession()
            }
        }
    }
}

// Helper extension to get discriminator for animation
extension AuthState {
    var discriminator: String {
        switch self {
        case .unknown:
            return "unknown"
        case .signedOut:
            return "signedOut"
        case .signedIn:
            return "signedIn"
        }
    }
}