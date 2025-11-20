//
//  NavigationBarView.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import SwiftUI

struct NavigationBarView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @FocusState private var isAddressBarFocused: Bool
    @State private var isEditing: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Navigation buttons
            navigationButtons

            // Address bar
            addressBar

            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 4) {
            // Toggle sidebar
            Button(action: { viewModel.toggleSidebar() }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Toggle Sidebar")
            .keyboardShortcut("s", modifiers: [.command, .shift])

            // Back
            Button(action: { viewModel.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(viewModel.activeTab?.canGoBack == true ? .primary : .secondary.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeTab?.canGoBack != true)
            .help("Go Back")
            .keyboardShortcut("[", modifiers: .command)

            // Forward
            Button(action: { viewModel.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(viewModel.activeTab?.canGoForward == true ? .primary : .secondary.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeTab?.canGoForward != true)
            .help("Go Forward")
            .keyboardShortcut("]", modifiers: .command)

            // Reload/Stop
            if viewModel.activeTab?.isLoading == true {
                Button(action: { viewModel.stopLoading() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Stop Loading")
            } else {
                Button(action: { viewModel.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Reload")
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }

    // MARK: - Address Bar
    private var addressBar: some View {
        HStack(spacing: 8) {
            // Security indicator
            if let url = viewModel.activeTab?.url {
                Image(systemName: url.scheme == "https" ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 10))
                    .foregroundColor(url.scheme == "https" ? .green : .orange)
            }

            // URL/Search field
            TextField("Search or enter URL", text: $viewModel.addressBarText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isAddressBarFocused)
                .onSubmit {
                    viewModel.navigateToAddress(viewModel.addressBarText)
                    isAddressBarFocused = false
                }
                .onChange(of: isAddressBarFocused) { _, focused in
                    isEditing = focused
                    if focused {
                        // Select all text when focused
                        DispatchQueue.main.async {
                            NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSText.selectAll(_:)), with: nil)
                        }
                    }
                }

            // Clear button when editing
            if isEditing && !viewModel.addressBarText.isEmpty {
                Button(action: { viewModel.addressBarText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isEditing ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 4) {
            // Spotlight/Command palette
            Button(action: { viewModel.toggleSpotlight() }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Search (Cmd+K)")
            .keyboardShortcut("k", modifiers: .command)

            // Bookmark
            Button(action: {
                if let tab = viewModel.activeTab {
                    if viewModel.isBookmarked(url: tab.url) {
                        if let bookmark = viewModel.bookmarks.first(where: { $0.url == tab.url }) {
                            viewModel.removeBookmark(bookmark.id)
                        }
                    } else {
                        viewModel.addBookmark(url: tab.url, title: tab.title)
                    }
                }
            }) {
                Image(systemName: viewModel.activeTab.map { viewModel.isBookmarked(url: $0.url) } ?? false ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(viewModel.activeTab.map { viewModel.isBookmarked(url: $0.url) } ?? false ? .yellow : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Bookmark")
            .keyboardShortcut("d", modifiers: .command)

            // Share
            Button(action: {
                if let url = viewModel.activeTab?.url {
                    let picker = NSSharingServicePicker(items: [url])
                    if let button = NSApp.keyWindow?.contentView?.hitTest(NSEvent.mouseLocation) {
                        picker.show(relativeTo: .zero, of: button, preferredEdge: .minY)
                    }
                }
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Share")
        }
    }
}
