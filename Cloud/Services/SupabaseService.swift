//
//  SupabaseService.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import Foundation
import Combine
import Supabase
import Auth

// MARK: - Supabase Models (Database Tables)

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var email: String?
    var displayName: String?
    var avatarUrl: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SyncedSpace: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var name: String
    var icon: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, icon
        case colorHex = "color_hex"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SyncedTab: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var spaceId: UUID
    var folderId: UUID?
    var url: String
    var title: String
    var isPinned: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case spaceId = "space_id"
        case folderId = "folder_id"
        case url, title
        case isPinned = "is_pinned"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SyncedFolder: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var spaceId: UUID
    var name: String
    var isExpanded: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case spaceId = "space_id"
        case name
        case isExpanded = "is_expanded"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SyncedBookmark: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var url: String
    var title: String
    var folderId: UUID?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case url, title
        case folderId = "folder_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case signedOut
    case signedIn(User)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.signedOut, .signedOut):
            return true
        case let (.signedIn(user1), .signedIn(user2)):
            return user1.id == user2.id
        default:
            return false
        }
    }
}

// MARK: - Supabase Service

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    private let client = SupabaseConfig.client

    @Published var authState: AuthState = .unknown
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Current User ID
    var currentUserId: String? {
        currentUser?.id.uuidString
    }

    private init() {
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    func checkSession() async {
        do {
            let session = try await client.auth.session
            currentUser = session.user
            authState = .signedIn(session.user)
        } catch {
            currentUser = nil
            authState = .signedOut
        }
    }

    // MARK: - Authentication

    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(email: email, password: password)

            // Check if email confirmation is required
            if let session = response.session {
                // User is auto-confirmed (email confirmation disabled in Supabase settings)
                currentUser = session.user
                authState = .signedIn(session.user)
                try await createUserProfile(userId: session.user.id, email: email)

                // Reload user-specific data for new user
                NotificationCenter.default.post(name: .reloadUserData, object: nil)
            } else {
                // Email confirmation required - user must verify email before signing in
                currentUser = nil
                authState = .signedOut
                // Do not create profile yet - wait for email confirmation
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            currentUser = session.user
            authState = .signedIn(session.user)

            // Reload user-specific data
            NotificationCenter.default.post(name: .reloadUserData, object: nil)
        } catch {
            let errorDesc = error.localizedDescription
            // Provide a better error message for unconfirmed email
            if errorDesc.contains("Email not confirmed") || errorDesc.contains("email_not_confirmed") {
                errorMessage = "Please confirm your email before signing in. Check your inbox for the confirmation link."
            } else {
                errorMessage = errorDesc
            }
            throw error
        }
    }

    func signOut() async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await client.auth.signOut()
            currentUser = nil
            authState = .signedOut

            // Clear all session data from BrowserViewModel
            NotificationCenter.default.post(name: .clearBrowserSession, object: nil)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            currentUser = session.user
            authState = .signedIn(session.user)

            // Create profile if first time
            if let user = currentUser {
                try? await createUserProfile(userId: user.id, email: user.email)
            }

            // Reload user-specific data
            NotificationCenter.default.post(name: .reloadUserData, object: nil)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - User Profile

    private func createUserProfile(userId: UUID, email: String?) async throws {
        let profile: [String: AnyJSON] = [
            "id": .string(userId.uuidString),
            "email": email.map { .string($0) } ?? .null,
            "created_at": .string(ISO8601DateFormatter().string(from: Date())),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]

        try await client
            .from("profiles")
            .upsert(profile)
            .execute()
    }

    func fetchUserProfile() async throws -> UserProfile? {
        guard let userId = currentUser?.id else { return nil }

        let response: [UserProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        return response.first
    }

    // MARK: - Spaces Sync

    func syncSpaces(_ spaces: [Space]) async throws {
        guard let userId = currentUser?.id else { return }

        for (index, space) in spaces.enumerated() {
            let syncedSpace: [String: AnyJSON] = [
                "id": .string(space.id.uuidString),
                "user_id": .string(userId.uuidString),
                "name": .string(space.name),
                "icon": .string(space.icon),
                "color_hex": .string(space.colorHex),
                "sort_order": .integer(index),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]

            try await client
                .from("spaces")
                .upsert(syncedSpace)
                .execute()
        }
    }

    func fetchSpaces() async throws -> [SyncedSpace] {
        guard let userId = currentUser?.id else { return [] }

        let response: [SyncedSpace] = try await client
            .from("spaces")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("sort_order")
            .execute()
            .value

        return response
    }

    // MARK: - Tabs Sync

    func syncTabs(_ tabs: [BrowserTab]) async throws {
        guard let userId = currentUser?.id else { return }

        for (index, tab) in tabs.enumerated() {
            let syncedTab: [String: AnyJSON] = [
                "id": .string(tab.id.uuidString),
                "user_id": .string(userId.uuidString),
                "space_id": .string(tab.spaceId.uuidString),
                "folder_id": tab.folderId.map { .string($0.uuidString) } ?? .null,
                "url": .string(tab.url.absoluteString),
                "title": .string(tab.title),
                "is_pinned": .bool(tab.isPinned),
                "sort_order": .integer(index),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]

            try await client
                .from("tabs")
                .upsert(syncedTab)
                .execute()
        }
    }

    func fetchTabs() async throws -> [SyncedTab] {
        guard let userId = currentUser?.id else { return [] }

        let response: [SyncedTab] = try await client
            .from("tabs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("sort_order")
            .execute()
            .value

        return response
    }

    func deleteTab(id: UUID) async throws {
        try await client
            .from("tabs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Folders Sync

    func syncFolders(_ folders: [TabFolder]) async throws {
        guard let userId = currentUser?.id else { return }

        for (index, folder) in folders.enumerated() {
            let syncedFolder: [String: AnyJSON] = [
                "id": .string(folder.id.uuidString),
                "user_id": .string(userId.uuidString),
                "space_id": .string(folder.spaceId.uuidString),
                "name": .string(folder.name),
                "is_expanded": .bool(folder.isExpanded),
                "sort_order": .integer(index),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]

            try await client
                .from("folders")
                .upsert(syncedFolder)
                .execute()
        }
    }

    func fetchFolders() async throws -> [SyncedFolder] {
        guard let userId = currentUser?.id else { return [] }

        let response: [SyncedFolder] = try await client
            .from("folders")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("sort_order")
            .execute()
            .value

        return response
    }

    // MARK: - Bookmarks Sync

    func syncBookmarks(_ bookmarks: [Bookmark]) async throws {
        guard let userId = currentUser?.id else { return }

        for bookmark in bookmarks {
            let syncedBookmark: [String: AnyJSON] = [
                "id": .string(bookmark.id.uuidString),
                "user_id": .string(userId.uuidString),
                "url": .string(bookmark.url.absoluteString),
                "title": .string(bookmark.title),
                "folder_id": bookmark.folderId.map { .string($0.uuidString) } ?? .null,
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]

            try await client
                .from("bookmarks")
                .upsert(syncedBookmark)
                .execute()
        }
    }

    func fetchBookmarks() async throws -> [SyncedBookmark] {
        guard let userId = currentUser?.id else { return [] }

        let response: [SyncedBookmark] = try await client
            .from("bookmarks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response
    }

    func deleteBookmark(id: UUID) async throws {
        try await client
            .from("bookmarks")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Full Sync

    func performFullSync(
        spaces: [Space],
        tabs: [BrowserTab],
        folders: [TabFolder],
        bookmarks: [Bookmark]
    ) async throws {
        try await syncSpaces(spaces)
        try await syncFolders(folders)
        try await syncTabs(tabs)
        try await syncBookmarks(bookmarks)
    }
}
