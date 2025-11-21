//
//  SpotlightView.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import SwiftUI

struct SpotlightView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @State private var eventMonitor: Any?
    @FocusState private var isSearchFieldFocused: Bool

    private var searchResults: [SearchResult] {
        viewModel.searchResults(for: viewModel.searchQuery)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 80)

            // Spotlight container
            VStack(spacing: 0) {
                // Search field
                searchField

                if !viewModel.searchQuery.isEmpty && !searchResults.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Results list
                    resultsList
                        .id(viewModel.searchQuery) // Force re-render on query change
                }
            }
            .frame(width: 680)
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)

            Spacer()
        }
        .onAppear {
            isSearchFieldFocused = true
            viewModel.spotlightSelectedIndex = 0
            setupKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private func setupKeyMonitor() {
        // Capture viewModel directly - safe because we remove monitor in onDisappear
        let vm = viewModel
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let results = vm.searchResults(for: vm.searchQuery)

            switch event.keyCode {
            case 126: // Up arrow
                if vm.spotlightSelectedIndex > 0 {
                    vm.spotlightSelectedIndex -= 1
                }
                return nil
            case 125: // Down arrow
                if vm.spotlightSelectedIndex < results.count - 1 {
                    vm.spotlightSelectedIndex += 1
                }
                return nil
            case 53: // Escape
                vm.isSpotlightVisible = false
                return nil
            case 36: // Return/Enter - handle selection
                if !results.isEmpty && vm.spotlightSelectedIndex < results.count {
                    vm.selectSearchResult(results[vm.spotlightSelectedIndex])
                } else if !vm.searchQuery.isEmpty {
                    vm.navigateToAddress(vm.searchQuery)
                    vm.isSpotlightVisible = false
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Search Field
    private var searchField: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.secondary)

            TextField("Search or enter URL...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .regular))
                .focused($isSearchFieldFocused)
                .onSubmit {
                    handleSubmit()
                }
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.spotlightSelectedIndex = 0
                }

            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            // Keyboard hint
            HStack(spacing: 4) {
                Text("esc")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    // MARK: - Results List
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
                        resultRow(result, isSelected: index == viewModel.spotlightSelectedIndex)
                            .id(index)
                            .onTapGesture {
                                viewModel.selectSearchResult(result)
                            }
                            .onHover { hovering in
                                if hovering {
                                    viewModel.spotlightSelectedIndex = index
                                }
                            }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 360)
            .onChange(of: viewModel.spotlightSelectedIndex) { _, newIndex in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private func resultRow(_ result: SearchResult, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(iconBackground(for: result.type))
                    .frame(width: 32, height: 32)

                resultIcon(for: result.type)
            }

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(result.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            // Action hint for selected
            if isSelected {
                HStack(spacing: 2) {
                    Image(systemName: "return")
                        .font(.system(size: 10, weight: .medium))
                    Text("to open")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                // Type badge
                resultTypeBadge(for: result.type)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func iconBackground(for type: SearchResultType) -> Color {
        switch type {
        case .tab:
            return Color.blue.opacity(0.15)
        case .bookmark:
            return Color.yellow.opacity(0.15)
        case .history:
            return Color.gray.opacity(0.15)
        case .suggestion:
            return Color.purple.opacity(0.15)
        case .website:
            return Color.white.opacity(0.1)
        }
    }

    private func resultIcon(for type: SearchResultType) -> some View {
        Group {
            switch type {
            case .tab:
                Image(systemName: "square.on.square")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
            case .bookmark:
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.yellow)
            case .history:
                Image(systemName: "clock.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            case .suggestion:
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            case .website:
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }

    private func resultTypeBadge(for type: SearchResultType) -> some View {
        Group {
            switch type {
            case .tab:
                Text("Tab")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue.opacity(0.8))
            case .bookmark:
                Text("Bookmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.yellow.opacity(0.9))
            case .history:
                Text("History")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
            case .suggestion:
                EmptyView()
            case .website:
                EmptyView()
            }
        }
    }

    private func handleSubmit() {
        if searchResults.isEmpty {
            // Navigate directly to URL or search
            viewModel.navigateToAddress(viewModel.searchQuery)
            viewModel.isSpotlightVisible = false
        } else if viewModel.spotlightSelectedIndex < searchResults.count {
            viewModel.selectSearchResult(searchResults[viewModel.spotlightSelectedIndex])
        }
    }
}

// MARK: - Visual Effect View
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

