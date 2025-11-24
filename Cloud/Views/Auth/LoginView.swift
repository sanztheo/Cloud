//
//  LoginView.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @Binding var showRegister: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text("Cloud Browser")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Connectez-vous à votre compte")
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
                    Text("Mot de passe")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    SecureField("••••••••", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            handleSignIn()
                        }
                        .textContentType(.password)
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

                // Sign In Button
                Button(action: handleSignIn) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Text("Se connecter")
                                .fontWeight(.medium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading || email.isEmpty || password.isEmpty)

                // Register Link
                HStack {
                    Text("Pas encore de compte?")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Créer un compte") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRegister = true
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
        }
        .onChange(of: password) { _ in
            errorMessage = nil
        }
    }

    private func handleSignIn() {
        guard !email.isEmpty, !password.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await supabaseService.signIn(email: email, password: password)
                // Navigation handled by RootView observing authState
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
            return "Email ou mot de passe incorrect"
        } else if errorString.contains("Email not confirmed") {
            return "Veuillez confirmer votre adresse email"
        } else if errorString.contains("Network") {
            return "Erreur de connexion. Vérifiez votre connexion internet"
        } else {
            return "Une erreur s'est produite. Veuillez réessayer"
        }
    }
}