//
//  RegisterView.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import SwiftUI

struct RegisterView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @Binding var showLogin: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmationView = false
    @State private var isCreateAccountHovered = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, confirmPassword
    }

    // Design System Colors
    private let primaryBlack = Color(hex: "0A0A0A")
    private let bodyText = Color(hex: "374151")
    private let subtleGray = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")

    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var isFormValid: Bool {
        !email.isEmpty && password.count >= 6 && passwordsMatch
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer()

                    if showConfirmationView {
                        // Email Confirmation View
                        emailConfirmationView
                    } else {
                        // Registration Form
                        registrationFormView
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
        .onChange(of: confirmPassword) { _ in
            errorMessage = nil
        }
    }

    // MARK: - Registration Form View

    private var registrationFormView: some View {
        VStack(spacing: 0) {
            // Logo
            Text("Cloud")
                .font(.custom("Pixelify Sans", size: 48))
                .foregroundColor(primaryBlack)
                .padding(.bottom, 32)

            // Heading
            Text("Create your account")
                .font(.custom("Pixelify Sans", size: 32))
                .foregroundColor(primaryBlack)
                .padding(.bottom, 8)

            // Subtitle
            Text("Start your modern browser experience")
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
                HStack {
                    Text("Password")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(bodyText)

                    Spacer()

                    if !password.isEmpty && password.count < 6 {
                        Text("Min 6 characters")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }

                SecureField("Create a password", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(primaryBlack)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                !password.isEmpty && password.count < 6 ?
                                Color.orange : (focusedField == .password ? primaryBlack : borderColor),
                                lineWidth: 1
                            )
                    )
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        focusedField = .confirmPassword
                    }
                    .textContentType(.newPassword)
            }
            .padding(.bottom, 16)

            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Confirm Password")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(bodyText)

                    Spacer()

                    if !confirmPassword.isEmpty {
                        if passwordsMatch {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)

                                Text("Match")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        } else {
                            Text("Passwords don't match")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }

                SecureField("Confirm your password", text: $confirmPassword)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(primaryBlack)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                !confirmPassword.isEmpty && !passwordsMatch ?
                                Color.orange : (focusedField == .confirmPassword ? primaryBlack : borderColor),
                                lineWidth: 1
                            )
                    )
                    .focused($focusedField, equals: .confirmPassword)
                    .onSubmit {
                        handleSignUp()
                    }
                    .textContentType(.newPassword)
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

            // Create Account Button
            Button(action: handleSignUp) {
                HStack(spacing: 8) {
                    if isLoading || supabaseService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Create Account")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isCreateAccountHovered ? primaryBlack.opacity(0.85) : primaryBlack)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(isLoading || supabaseService.isLoading || !isFormValid)
            .opacity((isLoading || supabaseService.isLoading || !isFormValid) ? 0.6 : 1)
            .onHover { hovering in
                isCreateAccountHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .padding(.bottom, 32)

            // Toggle to Login
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(subtleGray)

                Button("Sign in") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showLogin = true
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
        }
    }

    // MARK: - Email Confirmation View

    private var emailConfirmationView: some View {
        VStack(spacing: 0) {
            // Success Icon
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "10B981"))
                .padding(.bottom, 32)

            // Heading
            Text("Check your email")
                .font(.custom("Pixelify Sans", size: 32))
                .foregroundColor(primaryBlack)
                .padding(.bottom, 12)

            // Email sent to
            Text("We sent a confirmation link to")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(subtleGray)

            Text(email)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(primaryBlack)
                .padding(.bottom, 24)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text("1")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(primaryBlack)
                        .clipShape(Circle())

                    Text("Open your email inbox")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(bodyText)
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("2")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(primaryBlack)
                        .clipShape(Circle())

                    Text("Click the confirmation link in the email")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(bodyText)
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("3")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(primaryBlack)
                        .clipShape(Circle())

                    Text("Return here and sign in")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(bodyText)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "F9FAFB"))
            .cornerRadius(12)
            .padding(.bottom, 32)

            // Go to Login Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showLogin = true
                }
            }) {
                Text("Go to Sign In")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(primaryBlack)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .padding(.bottom, 16)

            // Didn't receive email
            HStack(spacing: 4) {
                Text("Didn't receive the email?")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(subtleGray)

                Button("Check spam folder") {
                    // Could add resend functionality here
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
        }
    }

    // MARK: - Sign Up Handler

    private func handleSignUp() {
        guard isFormValid else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await supabaseService.signUp(email: email, password: password)

                await MainActor.run {
                    isLoading = false
                    // Show confirmation view since email confirmation is required
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showConfirmationView = true
                    }
                }
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

        if errorString.contains("already registered") || errorString.contains("User already registered") {
            return "This email is already registered. Try signing in."
        } else if errorString.contains("Password should be at least") {
            return "Password must be at least 6 characters"
        } else if errorString.contains("Invalid email") {
            return "Please enter a valid email address"
        } else if errorString.contains("Network") {
            return "Network error. Check your connection"
        } else {
            return "An error occurred. Please try again"
        }
    }
}
