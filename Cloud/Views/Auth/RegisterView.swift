//
//  RegisterView.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import SwiftUI

struct RegisterView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @Binding var showRegister: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, confirmPassword
    }

    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var isFormValid: Bool {
        !email.isEmpty && password.count >= 6 && passwordsMatch
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text("Créer un compte")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Rejoignez Cloud Browser")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)

            // Form
            VStack(spacing: 16) {
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("nom@exemple.com", text: $email)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .focused($focusedField, equals: .email)
                        .onSubmit {
                            focusedField = .password
                        }
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)
                }

                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Mot de passe")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if !password.isEmpty && password.count < 6 {
                            Text("Minimum 6 caractères")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }

                    SecureField("••••••••", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    !password.isEmpty && password.count < 6 ?
                                    Color.orange.opacity(0.5) :
                                    Color.gray.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                        .textContentType(.newPassword)
                }

                // Confirm Password Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Confirmer le mot de passe")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if !confirmPassword.isEmpty {
                            if passwordsMatch {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Les mots de passe ne correspondent pas")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    SecureField("••••••••", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    !confirmPassword.isEmpty && !passwordsMatch ?
                                    Color.orange.opacity(0.5) :
                                    Color.gray.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .onSubmit {
                            handleSignUp()
                        }
                        .textContentType(.newPassword)
                }

                // Success Message
                if let successMessage = successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)

                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }

                // Error Message
                if let errorMessage = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)

                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }

                // Sign Up Button
                Button(action: handleSignUp) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Text("Créer un compte")
                                .fontWeight(.medium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading || !isFormValid)

                // Login Link
                HStack {
                    Text("Déjà un compte?")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Se connecter") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRegister = false
                        }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
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
                    // Check if email confirmation is required
                    if supabaseService.authState == .signedOut {
                        successMessage = "Compte créé! Vérifiez votre email pour confirmer votre inscription."
                        // Clear form after a delay then switch to login
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            email = ""
                            password = ""
                            confirmPassword = ""
                            showRegister = false
                        }
                    }
                    // If auto-logged in (no email confirmation required)
                    // Navigation handled by RootView observing authState
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
            return "Cet email est déjà utilisé"
        } else if errorString.contains("Password should be at least") {
            return "Le mot de passe doit contenir au moins 6 caractères"
        } else if errorString.contains("Invalid email") {
            return "Adresse email invalide"
        } else if errorString.contains("Network") {
            return "Erreur de connexion. Vérifiez votre connexion internet"
        } else {
            return "Une erreur s'est produite. Veuillez réessayer"
        }
    }
}