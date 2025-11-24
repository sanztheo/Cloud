//
//  RegisterView.swift
//  Cloud
//

import SwiftUI

struct RegisterView: View {
    @Binding var showLogin: Bool
    @StateObject private var supabaseService = SupabaseService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false

    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, confirmPassword
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

            // Register Form (centered)
            if showConfirmation {
                // Confirmation View
                VStack(spacing: 24) {
                    Text("Check your email")
                        .font(.custom("Pixelify Sans", size: 32))
                        .foregroundColor(.white)

                    Text("We sent a confirmation link to \(email)")
                        .font(.custom("Pixelify Sans", size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Button(action: { showLogin = true }) {
                        Text("Back to login")
                            .font(.custom("Pixelify Sans", size: 16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 340)
            } else {
                // Registration Form
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

                    // Confirm Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.custom("Pixelify Sans", size: 14))
                            .foregroundColor(.white)

                        SecureField("confirm password", text: $confirmPassword)
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
                            .focused($focusedField, equals: .confirmPassword)
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

                    // Sign Up Button
                    Button(action: handleSignUp) {
                        Text(isLoading ? "Loading..." : "Create Account")
                            .font(.custom("Pixelify Sans", size: 16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || !isFormValid)

                    // Toggle
                    Button(action: { showLogin = true }) {
                        Text("Already have an account?")
                            .font(.custom("Pixelify Sans", size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 340)
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 6 && password == confirmPassword
    }

    private func handleSignUp() {
        guard isFormValid else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await supabaseService.signUp(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    showConfirmation = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
