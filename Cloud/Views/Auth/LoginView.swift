//
//  LoginView.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @Binding var showLogin: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSignInHovered = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    // Design System Colors
    private let primaryBlack = Color(hex: "0A0A0A")
    private let bodyText = Color(hex: "374151")
    private let subtleGray = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer()

                    // Logo
                    Text("Cloud")
                        .font(.custom("Pixelify Sans", size: 48))
                        .foregroundColor(primaryBlack)
                        .padding(.bottom, 32)

                    // Heading
                    Text("Welcome back")
                        .font(.custom("Pixelify Sans", size: 32))
                        .foregroundColor(primaryBlack)
                        .padding(.bottom, 8)

                    // Subtitle
                    Text("Sign in to your account")
                        .font(.custom("Pixelify Sans", size: 16))
                        .foregroundColor(subtleGray)
                        .padding(.bottom, 40)

                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(bodyText)

                        TextField("name@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundColor(primaryBlack)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(focusedField == .email ? primaryBlack : borderColor, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .email)
                            .onSubmit {
                                focusedField = .password
                            }
                            .textContentType(.emailAddress)
                            .disableAutocorrection(true)
                    }
                    .padding(.bottom, 16)

                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(bodyText)

                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundColor(primaryBlack)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(focusedField == .password ? primaryBlack : borderColor, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                handleSignIn()
                            }
                            .textContentType(.password)
                    }
                    .padding(.bottom, 24)

                    // Error Message
                    if let errorMessage = errorMessage ?? supabaseService.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)

                            Text(errorMessage)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                        .padding(.bottom, 16)
                    }

                    // Sign In Button
                    Button(action: handleSignIn) {
                        HStack(spacing: 8) {
                            if isLoading || supabaseService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(isSignInHovered ? primaryBlack.opacity(0.85) : primaryBlack)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || supabaseService.isLoading || email.isEmpty || password.isEmpty)
                    .opacity((isLoading || supabaseService.isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1)
                    .onHover { hovering in
                        isSignInHovered = hovering
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .padding(.bottom, 32)

                    // Toggle to Register
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(subtleGray)

                        Button("Sign up") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showLogin = false
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(primaryBlack)
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }

                    Spacer()
                }
                .frame(width: 340)
                .frame(minHeight: geometry.size.height)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.white)
        .onAppear {
            focusedField = .email
        }
        .onChange(of: email) { _ in
            errorMessage = nil
        }
        .onChange(of: password) { _ in
            errorMessage = nil
        }
    }

    // MARK: - Sign In Handler

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
                    errorMessage = formatErrorMessage(error)
                }
            }
        }
    }

    private func formatErrorMessage(_ error: Error) -> String {
        let errorString = error.localizedDescription

        if errorString.contains("Invalid login credentials") {
            return "Invalid email or password"
        } else if errorString.contains("Email not confirmed") {
            return "Please check your email and confirm your account"
        } else if errorString.contains("Network") {
            return "Network error. Check your connection"
        } else {
            return "An error occurred. Please try again"
        }
    }
}
