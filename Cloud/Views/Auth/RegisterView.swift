//
//  RegisterView.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct RegisterView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @Binding var showLogin: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var currentNonce: String?
    @FocusState private var focusedField: Field?

    // Hover states
    @State private var isGoogleHovered = false
    @State private var isMicrosoftHovered = false
    @State private var isAppleHovered = false
    @State private var isSSOHovered = false
    @State private var isCreateAccountHovered = false

    enum Field {
        case email, password, confirmPassword
    }

    // Design System Colors
    private let primaryBlack = Color(hex: "0A0A0A")
    private let bodyText = Color(hex: "374151")
    private let subtleGray = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    private let buttonHover = Color(hex: "F9FAFB")

    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var isFormValid: Bool {
        !email.isEmpty && password.count >= 6 && passwordsMatch
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Logo
                Text("Cloud")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(primaryBlack)
                    .padding(.bottom, 32)

                // Heading
                Text("Create your account")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(primaryBlack)
                    .padding(.bottom, 8)

                // Subtitle
                Text("Your modern browser experience")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(subtleGray)
                    .padding(.bottom, 32)

                // Social Buttons Grid (2x2)
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        SocialButton(
                            title: "Google",
                            icon: "G",
                            isIconText: true,
                            isHovered: $isGoogleHovered,
                            borderColor: borderColor,
                            hoverColor: buttonHover,
                            action: handleGoogleSignUp
                        )

                        SocialButton(
                            title: "Microsoft",
                            icon: "square.grid.2x2.fill",
                            isIconText: false,
                            isHovered: $isMicrosoftHovered,
                            borderColor: borderColor,
                            hoverColor: buttonHover,
                            action: handleMicrosoftSignUp
                        )
                    }

                    HStack(spacing: 12) {
                        RegisterSignInWithAppleButton(
                            currentNonce: $currentNonce,
                            isHovered: $isAppleHovered,
                            borderColor: borderColor,
                            hoverColor: buttonHover,
                            onCompletion: handleAppleSignUp
                        )

                        SocialButton(
                            title: "SSO",
                            icon: "rectangle.grid.1x2.fill",
                            isIconText: false,
                            isHovered: $isSSOHovered,
                            borderColor: borderColor,
                            hoverColor: buttonHover,
                            action: handleSSOSignUp
                        )
                    }
                }
                .padding(.bottom, 24)

                // OR Divider
                HStack(spacing: 16) {
                    Rectangle()
                        .fill(borderColor)
                        .frame(height: 1)

                    Text("OR")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(subtleGray)

                    Rectangle()
                        .fill(borderColor)
                        .frame(height: 1)
                }
                .padding(.bottom, 24)

                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(bodyText)

                    TextField("name@example.com", text: $email)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: 1)
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
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(bodyText)

                        Spacer()

                        if !password.isEmpty && password.count < 6 {
                            Text("Min 6 characters")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.orange)
                        }
                    }

                    SecureField("Create a password", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    !password.isEmpty && password.count < 6 ?
                                    Color.orange.opacity(0.8) : borderColor,
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
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(bodyText)

                        Spacer()

                        if !confirmPassword.isEmpty {
                            if passwordsMatch {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)

                                    Text("Match")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(.green)
                                }
                            } else {
                                Text("Passwords don't match")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    SecureField("Confirm your password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    !confirmPassword.isEmpty && !passwordsMatch ?
                                    Color.orange.opacity(0.8) : borderColor,
                                    lineWidth: 1
                                )
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .onSubmit {
                            handleSignUp()
                        }
                        .textContentType(.newPassword)
                }
                .padding(.bottom, 16)

                // Success Message
                if let successMessage = successMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)

                        Text(successMessage)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.green)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)
                    .padding(.bottom, 16)
                }

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
                                .font(.system(size: 14, weight: .medium))
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
                }
                .padding(.bottom, 24)

                // Toggle to Login
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(subtleGray)

                    Button("Sign in") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showLogin = true
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
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
            .padding(.horizontal, 60)
            .padding(.top, 80)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            focusedField = .email
        }
        .onChange(of: email) { _ in
            errorMessage = nil
            successMessage = nil
        }
        .onChange(of: password) { _ in
            errorMessage = nil
            successMessage = nil
        }
        .onChange(of: confirmPassword) { _ in
            errorMessage = nil
            successMessage = nil
        }
    }

    // MARK: - Sign Up Handlers

    private func handleSignUp() {
        guard isFormValid else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await supabaseService.signUp(email: email, password: password)

                await MainActor.run {
                    isLoading = false
                    if supabaseService.authState == .signedOut {
                        successMessage = "Account created! Check your email to confirm."
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            email = ""
                            password = ""
                            confirmPassword = ""
                            showLogin = true
                        }
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

    private func handleGoogleSignUp() {
        errorMessage = "Google Sign-Up coming soon"
    }

    private func handleMicrosoftSignUp() {
        errorMessage = "Microsoft Sign-Up coming soon"
    }

    private func handleSSOSignUp() {
        errorMessage = "SSO Sign-Up coming soon"
    }

    private func handleAppleSignUp(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Failed to get Apple ID credentials"
                return
            }

            isLoading = true
            errorMessage = nil

            Task {
                do {
                    try await supabaseService.signInWithApple(idToken: idTokenString, nonce: nonce)
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = formatErrorMessage(error)
                    }
                }
            }

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple Sign-Up failed: \(error.localizedDescription)"
            }
        }
    }

    private func formatErrorMessage(_ error: Error) -> String {
        let errorString = error.localizedDescription

        if errorString.contains("already registered") || errorString.contains("User already registered") {
            return "This email is already registered"
        } else if errorString.contains("Password should be at least") {
            return "Password must be at least 6 characters"
        } else if errorString.contains("Invalid email") {
            return "Invalid email address"
        } else if errorString.contains("Network") {
            return "Network error. Check your connection"
        } else {
            return "An error occurred. Please try again"
        }
    }
}

// MARK: - Register Sign In With Apple Button

struct RegisterSignInWithAppleButton: View {
    @Binding var currentNonce: String?
    @Binding var isHovered: Bool
    let borderColor: Color
    let hoverColor: Color
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "0A0A0A"))

                Text("Apple")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "374151"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isHovered ? hoverColor : Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .overlay(
            RegisterSignInWithAppleButtonRepresentable(
                currentNonce: $currentNonce,
                onCompletion: onCompletion
            )
            .opacity(0.02)
        )
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Register Apple Sign-In Representable

struct RegisterSignInWithAppleButtonRepresentable: NSViewRepresentable {
    @Binding var currentNonce: String?
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeNSView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signUp, style: .white)
        button.target = context.coordinator
        button.action = #selector(Coordinator.handleAppleSignUp)
        return button
    }

    func updateNSView(_ nsView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: RegisterSignInWithAppleButtonRepresentable

        init(_ parent: RegisterSignInWithAppleButtonRepresentable) {
            self.parent = parent
        }

        @objc func handleAppleSignUp() {
            let nonce = randomNonceString()
            parent.currentNonce = nonce

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            parent.onCompletion(.success(authorization))
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            parent.onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSApplication.shared.windows.first!
        }

        private func randomNonceString(length: Int = 32) -> String {
            precondition(length > 0)
            var randomBytes = [UInt8](repeating: 0, count: length)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }

            let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
            let nonce = randomBytes.map { byte in
                charset[Int(byte) % charset.count]
            }

            return String(nonce)
        }

        private func sha256(_ input: String) -> String {
            let inputData = Data(input.utf8)
            let hashedData = SHA256.hash(data: inputData)
            let hashString = hashedData.compactMap {
                String(format: "%02x", $0)
            }.joined()

            return hashString
        }
    }
}
