//
//  HoverTrackingView.swift
//  Cloud
//
//  Created by Sanz on 22/11/2025.
//

import AppKit
import SwiftUI

/// A reliable hover tracking view using AppKit's tracking areas
/// SwiftUI's onHover can be unreliable on macOS, this provides consistent behavior
struct HoverTrackingView<Content: View>: NSViewRepresentable {
    let content: Content
    let onHover: (Bool) -> Void

    init(@ViewBuilder content: () -> Content, onHover: @escaping (Bool) -> Void) {
        self.content = content()
        self.onHover = onHover
    }

    func makeNSView(context: Context) -> HoverTrackingNSView {
        let view = HoverTrackingNSView()
        view.onHover = onHover

        // Host the SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        context.coordinator.hostingView = hostingView

        return view
    }

    func updateNSView(_ nsView: HoverTrackingNSView, context: Context) {
        nsView.onHover = onHover
        context.coordinator.hostingView?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var hostingView: NSHostingView<Content>?
    }
}

class HoverTrackingNSView: NSView {
    var onHover: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        if let area = trackingArea {
            addTrackingArea(area)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHover?(false)
    }
}

// MARK: - View Extension for easier usage
extension View {
    /// Use this instead of .onHover for reliable hover detection on macOS
    func reliableHover(onHover: @escaping (Bool) -> Void) -> some View {
        HoverTrackingView(content: { self }, onHover: onHover)
    }
}
