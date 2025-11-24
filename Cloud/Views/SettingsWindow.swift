//
//  SettingsWindow.swift
//  Cloud
//
//  Settings window for managing application configuration
//

import SwiftUI
import Auth

struct SettingsWindow: View {
    // MARK: - Properties

    @StateObject private var supabaseService = SupabaseService.shared
    @AppStorage("openai_api_key") private var apiKey: String = ""
    @AppStorage("summary_language") private var summaryLanguage: String = "English"
    @State private var tempApiKey: String = ""
    @State private var showKey: Bool = false
    @State private var saveMessage: String = ""
    @State private var showSaveMessage: Bool = false
    @State private var isError: Bool = false

    // Test API
    @State private var isTesting: Bool = false
    @State private var testMessage: String = ""
    @State private var showTestMessage: Bool = false
    @State private var testSuccess: Bool = false

    // Cache statistics (placeholder values since SummaryCacheService doesn't exist yet)
    @State private var cachedSummaries: Int = 0
    @State private var cacheSize: String = "0 KB"
    @State private var isClearing: Bool = false

    // MARK: - Computed Properties

    private var isValidApiKey: Bool {
        tempApiKey.hasPrefix("sk-") && tempApiKey.count > 10
    }

    private var canSave: Bool {
        !tempApiKey.isEmpty && tempApiKey != apiKey
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            titleBar

            Divider()
                .opacity(0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Account Section
                    accountSection

                    Divider()
                        .padding(.horizontal, -20)

                    // OpenAI Configuration Section
                    openAISection

                    Divider()
                        .padding(.horizontal, -20)

                    // Cache Statistics Section
                    cacheSection
                }
                .padding(20)
            }
        }
        .frame(width: 600, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            tempApiKey = apiKey
            loadCacheStatistics()
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Label("Account", systemImage: "person.circle")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 12) {
                // User Info
                if case .signedIn(let user) = supabaseService.authState {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                            .symbolRenderingMode(.hierarchical)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(user.email ?? "No email")
                                .font(.body)
                                .fontWeight(.medium)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Sign Out Button
                    HStack {
                        Button(action: handleSignOut) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                Text("Se déconnecter")
                            }
                            .frame(minWidth: 120)
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .padding(.top, 8)
                } else {
                    // Not signed in (shouldn't happen in settings)
                    Text("Aucun compte connecté")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - OpenAI Configuration Section

    private var openAISection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Label("OpenAI Configuration", systemImage: "brain")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 12) {
                // Description
                Text("Configure your OpenAI API key for AI-powered features")
                    .font(.callout)
                    .foregroundColor(.secondary)

                // Language Selector
                VStack(alignment: .leading, spacing: 6) {
                    Text("Summary Language")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Language", selection: $summaryLanguage) {
                        Text("🇬🇧 English").tag("English")
                        Text("🇫🇷 Français").tag("French")
                        Text("🇪🇸 Español").tag("Spanish")
                        Text("🇩🇪 Deutsch").tag("German")
                        Text("🇮🇹 Italiano").tag("Italian")
                        Text("🇯🇵 日本語").tag("Japanese")
                        Text("🇨🇳 中文").tag("Chinese")
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                }
                .padding(.vertical, 8)

                // API Key Field
                HStack(spacing: 12) {
                    Group {
                        if showKey {
                            TextField("API Key", text: $tempApiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("API Key", text: $tempApiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    // Show/Hide Toggle
                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help(showKey ? "Hide API Key" : "Show API Key")
                }

                // Validation Message
                if !tempApiKey.isEmpty && !isValidApiKey {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("API key should start with 'sk-'")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }

                // Save Message
                if showSaveMessage {
                    HStack(spacing: 4) {
                        Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(isError ? .red : .green)
                        Text(saveMessage)
                            .font(.caption)
                            .foregroundColor(isError ? .red : .green)
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .scale))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showSaveMessage = false
                            }
                        }
                    }
                }

                // Save and Test Buttons
                HStack {
                    Button(action: validateAndSave) {
                        Label("Save", systemImage: "checkmark")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave || !isValidApiKey)

                    if tempApiKey != apiKey && !tempApiKey.isEmpty {
                        Button("Cancel") {
                            tempApiKey = apiKey
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    // Test API Button
                    Button(action: testAPIKey) {
                        HStack(spacing: 6) {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text("Test API")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.bordered)
                    .disabled(tempApiKey.isEmpty || !isValidApiKey || isTesting)
                }
                .padding(.top, 8)

                // Test Message
                if showTestMessage {
                    HStack(spacing: 4) {
                        Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(testSuccess ? .green : .red)
                        Text(testMessage)
                            .font(.caption)
                            .foregroundColor(testSuccess ? .green : .red)
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .scale))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation {
                                showTestMessage = false
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cache Section

    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Label("Cache Statistics", systemImage: "internaldrive")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 12) {
                // Cache Stats
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cached Summaries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(cachedSummaries)")
                            .font(.title3)
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cache Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(cacheSize)
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Clear Cache Button
                Button(action: clearCache) {
                    HStack {
                        if isClearing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text(isClearing ? "Clearing..." : "Clear Cache")
                    }
                    .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .disabled(isClearing || cachedSummaries == 0)
            }
        }
    }

    // MARK: - Actions

    private func validateAndSave() {
        guard isValidApiKey else {
            withAnimation(.spring(response: 0.3)) {
                isError = true
                saveMessage = "Invalid API key format"
                showSaveMessage = true
            }
            return
        }

        // Save to UserDefaults
        apiKey = tempApiKey

        // Post notification
        NotificationCenter.default.post(
            name: Notification.Name("apiKeyUpdated"),
            object: nil,
            userInfo: ["apiKey": tempApiKey]
        )

        // Show success message
        withAnimation(.spring(response: 0.3)) {
            isError = false
            saveMessage = "API key saved successfully"
            showSaveMessage = true
        }
    }

    private func loadCacheStatistics() {
        // Placeholder implementation - would connect to actual cache service
        // For now, use mock data
        cachedSummaries = Int.random(in: 0...50)
        let sizeInKB = Double.random(in: 0...1024)
        if sizeInKB < 1024 {
            cacheSize = String(format: "%.1f KB", sizeInKB)
        } else {
            cacheSize = String(format: "%.1f MB", sizeInKB / 1024)
        }
    }

    private func clearCache() {
        isClearing = true

        // Simulate cache clearing - would call actual SummaryCacheService
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            cachedSummaries = 0
            cacheSize = "0 KB"
            isClearing = false

            // Show success message
            withAnimation(.spring(response: 0.3)) {
                isError = false
                saveMessage = "Cache cleared successfully"
                showSaveMessage = true
            }
        }
    }

    private func handleSignOut() {
        Task {
            do {
                try await supabaseService.signOut()
                // The RootView will automatically handle the navigation to login
            } catch {
                // Show error message
                await MainActor.run {
                    isError = true
                    saveMessage = "Erreur lors de la déconnexion"
                    showSaveMessage = true
                }
            }
        }
    }

    private func testAPIKey() {
        isTesting = true
        showTestMessage = false

        Task {
            do {
                // Create OpenAI service instance
                let service = OpenAIService()

                // Save the key temporarily to test it
                UserDefaults.standard.set(tempApiKey, forKey: "openai_api_key")

                // Try to stream a simple test
                let testContent = "Hello, this is a test."
                let stream = try await service.streamSummary(for: testContent)

                // Check if we get at least one chunk
                var gotResponse = false
                for try await _ in stream {
                    gotResponse = true
                    break // Just need to confirm we got a response
                }

                // Restore original key if test failed
                if !gotResponse {
                    UserDefaults.standard.set(apiKey, forKey: "openai_api_key")
                }

                await MainActor.run {
                    isTesting = false
                    testSuccess = true
                    testMessage = "API key is valid! ✓"
                    withAnimation(.spring(response: 0.3)) {
                        showTestMessage = true
                    }
                }
            } catch {
                // Restore original key on error
                UserDefaults.standard.set(apiKey, forKey: "openai_api_key")

                await MainActor.run {
                    isTesting = false
                    testSuccess = false

                    // Provide user-friendly error messages
                    if let openAIError = error as? OpenAIError {
                        switch openAIError {
                        case .missingAPIKey:
                            testMessage = "No API key provided"
                        case .invalidResponse:
                            testMessage = "Invalid API key or network error"
                        case .rateLimitExceeded:
                            testMessage = "Rate limit exceeded"
                        default:
                            testMessage = "API test failed: \(openAIError.localizedDescription)"
                        }
                    } else {
                        testMessage = "API test failed: \(error.localizedDescription)"
                    }

                    withAnimation(.spring(response: 0.3)) {
                        showTestMessage = true
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct SettingsWindow_Previews: PreviewProvider {
    static var previews: some View {
        SettingsWindow()
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let apiKeyUpdated = Notification.Name("apiKeyUpdated")
}