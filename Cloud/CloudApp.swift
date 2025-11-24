//
//  CloudApp.swift
//  Cloud
//
//  Created by Sanz on 19/11/2025.
//

import SwiftUI

@main
struct CloudApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      RootView()
    }
    .defaultSize(width: 1400, height: 900)
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unified(showsTitle: false))
    .commands {
      // File menu
      CommandGroup(replacing: .newItem) {
        Button("New Window") {
          // Open new window
        }
        .keyboardShortcut("n", modifiers: .command)
      }

      // Edit menu additions
      CommandGroup(after: .pasteboard) {
        Divider()
        Button("Search...") {
          NotificationCenter.default.post(name: .showSpotlight, object: nil)
        }
        .keyboardShortcut("t", modifiers: .command)

        Button("Settings...") {
          NotificationCenter.default.post(name: .showSettings, object: nil)
        }
        .keyboardShortcut(",", modifiers: .command)
      }

      // View menu
      CommandGroup(replacing: .sidebar) {
        Button("Toggle Sidebar") {
          NotificationCenter.default.post(name: .toggleSidebar, object: nil)
        }
        .keyboardShortcut("s", modifiers: .command)
      }

      // History menu
      CommandMenu("History") {
        Button("Back") {
          NotificationCenter.default.post(name: .goBack, object: nil)
        }
        .keyboardShortcut("[", modifiers: .command)

        Button("Forward") {
          NotificationCenter.default.post(name: .goForward, object: nil)
        }
        .keyboardShortcut("]", modifiers: .command)

        Divider()

        Button("Reload Page") {
          NotificationCenter.default.post(name: .reload, object: nil)
        }
        .keyboardShortcut("r", modifiers: .command)
      }

      // Bookmarks menu
      CommandMenu("Bookmarks") {
        Button("Add Bookmark") {
          NotificationCenter.default.post(name: .addBookmark, object: nil)
        }
        .keyboardShortcut("d", modifiers: .command)

        Divider()

        Button("Show All Bookmarks") {
          // Show bookmarks
        }
      }
    }
  }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Register custom fonts first
    FontRegistration.registerCustomFonts()

    NSLog("🚀 Cloud App Started - Download debugging enabled")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if let window = NSApp.windows.first {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false

        if let screen = window.screen ?? NSScreen.main {
          let visibleFrame = screen.visibleFrame
          window.setFrame(visibleFrame, display: true, animate: false)
        }
      }
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}

// MARK: - Notification Names
extension Notification.Name {
  static let newTab = Notification.Name("newTab")
  static let showSpotlight = Notification.Name("showSpotlight")
  static let showSettings = Notification.Name("showSettings")
  static let toggleSidebar = Notification.Name("toggleSidebar")
  static let goBack = Notification.Name("goBack")
  static let goForward = Notification.Name("goForward")
  static let reload = Notification.Name("reload")
  static let addBookmark = Notification.Name("addBookmark")
}
