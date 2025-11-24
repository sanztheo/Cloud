//
//  LoginView.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @Binding var showLogin: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?
    @FocusState private var focusedField: Field?

    // Hover states
    @State private var isGoogleHovered = false
    @State private var isMicrosoftHovered = false
    @State private var isAppleHovered = false
    @State private var isSSOHovered = false
    @State private var isSignInHovered = false

    enum Field {
        case email, password
    }

    // Design System Colors
    private let primaryBlack = Color(hex: "0A0A0A")
    private let bodyText = Color(hex: "374151")
    private let subtleGray = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    private let buttonHover = Color(hex: "F9FAFB")

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Logo
                Text("Cloud")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(primaryBlack)
                    .padding(.bottom, 32)

                // Heading
                Text("Get started with Cloud")
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
                            action: handleGoogleSignIn
                        )

                        SocialButton(
                            title: "Microsoft",
                            icon: "square.grid.2x2.fill",
                            isIconText: false,
                            isHovered: $isMicrosoftHovered,
                            borderColor: borderColor,
                            hoverColor: buttonHover,
                            action: handleMicrosoftSignIn
                        )
                    }

                    HStack(spacing: 12) {
                        SignInWithAppleButton(
                            currentNonce: $currentNonce,
                            isHovered: $isAppleHovered,
                            borderColor: borderColor,
                            hoverColor: buttonHover,
                            onCompletion: handleAppleSignIn
                        )

                        SocialButton(
                            title: "SSO",
                            icon: "rectangle.grid.1x2.fill",
                            isIconText: false,
                            isHovered: $isSSOHovered,
                            borderColor: borderColor,
                            hoverColor: buttonHover,
                            action: handleSSOSignIn
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
                    Text("Password")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(bodyText)

                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: 1)
                        )
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            handleSignIn()
                        }
                        .textContentType(.password)
                }
                .padding(.bottom, 16)

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
                                .font(.system(size: 14, weight: .medium))
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
                }
                .padding(.bottom, 24)

                // Toggle to Register
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(subtleGray)

                    Button("Sign up") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showLogin = false
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
        }
        .onChange(of: password) { _ in
            errorMessage = nil
        }
    }

    // MARK: - Sign In Handlers

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

    private func handleGoogleSignIn() {
        errorMessage = "Google Sign-In coming soon"
    }

    private func handleMicrosoftSignIn() {
        errorMessage = "Microsoft Sign-In coming soon"
    }

    private func handleSSOSignIn() {
        errorMessage = "SSO Sign-In coming soon"
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
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
                errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            }
        }
    }

    private func formatErrorMessage(_ error: Error) -> String {
        let errorString = error.localizedDescription

        if errorString.contains("Invalid login credentials") {
            return "Invalid email or password"
        } else if errorString.contains("Email not confirmed") {
            return "Please confirm your email address"
        } else if errorString.contains("Network") {
            return "Network error. Check your connection"
        } else {
            return "An error occurred. Please try again"
        }
    }
}

// MARK: - Social Button Component

struct SocialButton: View {
    let title: String
    let icon: String
    let isIconText: Bool
    @Binding var isHovered: Bool
    let borderColor: Color
    let hoverColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isIconText {
                    Text(icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "0A0A0A"))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "0A0A0A"))
                }

                Text(title)
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

// MARK: - Sign In With Apple Button

struct SignInWithAppleButton: View {
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
            SignInWithAppleButtonRepresentable(
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

// MARK: - Apple Sign-In Representable

struct SignInWithAppleButtonRepresentable: NSViewRepresentable {
    @Binding var currentNonce: String?
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeNSView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        button.target = context.coordinator
        button.action = #selector(Coordinator.handleAppleSignIn)
        return button
    }

    func updateNSView(_ nsView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: SignInWithAppleButtonRepresentable

        init(_ parent: SignInWithAppleButtonRepresentable) {
            self.parent = parent
        }

        @objc func handleAppleSignIn() {
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
