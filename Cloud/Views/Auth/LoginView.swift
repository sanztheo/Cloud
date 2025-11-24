//
//  LoginView.swift
//  Cloud
//

import SwiftUI

struct LoginView: View {
    @Binding var showLogin: Bool
    @StateObject private var supabaseService = SupabaseService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        ZStack {
            // Background Image (full screen)
            if let _ = NSImage(named: "AuthBackground") {
                Image("AuthBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea(.all)
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "1e3a5f"),
                        Color(hex: "7c3aed")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea(.all)
            }

            // Login Form (centered)
            VStack(spacing: 24) {
                // Logo
                Text("Cloud")
                    .font(.custom("Pixelify Sans", size: 48))
                    .foregroundColor(.white)

                // Email
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.custom("Pixelify Sans", size: 14))
                        .foregroundColor(.white)

                    TextField("email@example.com", text: $email)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            ZStack {
                                Color.white.opacity(0.15)
                                Color.black.opacity(0.3)
                            }
                            .background(.ultraThinMaterial)
                        )
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .focused($focusedField, equals: .email)
                }

                // Password
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.custom("Pixelify Sans", size: 14))
                        .foregroundColor(.white)

                    SecureField("password", text: $password)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            ZStack {
                                Color.white.opacity(0.15)
                                Color.black.opacity(0.3)
                            }
                            .background(.ultraThinMaterial)
                        )
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .focused($focusedField, equals: .password)
                }

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(6)
                }

                // Sign In Button
                Button(action: handleSignIn) {
                    Text(isLoading ? "Loading..." : "Sign In")
                        .font(.custom("Pixelify Sans", size: 16))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                // Toggle
                Button(action: { showLogin = false }) {
                    Text("Create account")
                        .font(.custom("Pixelify Sans", size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 340)
        }
    }

    private func handleSignIn() {
        guard !email.isEmpty, !password.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await supabaseService.signIn(email: email, password: password)
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
