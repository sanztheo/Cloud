# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cloud Browser is a modern Arc-inspired web browser for macOS built with SwiftUI and WebKit. Written in Swift 5.9+ targeting macOS 13.0+.

## Build & Development

```bash
# Open project in Xcode
open Cloud.xcodeproj

# Build and Run
# Use Xcode: Cmd+R

# Type check without building (preferred after changes)
npx tsc --noEmit

# Run tests
# Use Xcode: Cmd+U
```

**Important**: Do not attempt `xcodebuild` from CLI - use Xcode directly.

## Architecture

MVVM architecture with SwiftUI. The main components:

### Core ViewModel Pattern
`BrowserViewModel` is split into modular extensions in `Cloud/ViewModels/BrowserViewModel/`:
- `BrowserViewModel.swift` - Core properties, initialization, Combine subscriptions
- `+Navigation.swift` - URL navigation, back/forward
- `+Tabs.swift` - Tab creation, selection, closing, reordering
- `+Spaces.swift` - Workspace management (Arc-style spaces)
- `+Folders.swift` - Tab folder organization
- `+Search.swift` - Spotlight search, autocomplete, suggestions
- `+Summary.swift` - AI summarization via OpenAI
- `+Persistence.swift` - UserDefaults storage for tabs/spaces/folders
- `+History.swift` - Browser history with frecency scoring
- `+Bookmarks.swift` - Bookmark management
- `+WebViews.swift` - WKWebView instance management

### Key Models (`Cloud/Models/`)
- `BrowserTab` - Tab with URL, title, favicon, pinned/folder state
- `Space` - Workspace container with theme
- `TabFolder` - Folder for organizing tabs within a space
- `HistoryEntry` - History with frecency scoring (visitCount, typedCount, lastVisitDate)
- `SearchResult` - Unified search result type (tab/bookmark/history/suggestion/command)

### Spotlight System (`Cloud/Views/Spotlight/`)
AppKit-based search interface (not SwiftUI) with modular architecture:
- `SpotlightViewController.swift` - Main coordinator
- `Extensions/` - Separated by responsibility (UI, DataSource, Delegate, SearchField)
- `Components/` - Reusable views (TableView, CellView)
- `Protocols/` - Delegate protocols

### Services (`Cloud/Services/`)
- `OpenAIService` - AI summarization with streaming
- `SummaryCacheService` - Caches AI summaries
- `GoogleSuggestionsService` - Search autocomplete
- `DownloadManager` - Native WebKit downloads with progress
- `StealthWebKitConfig` - Anti-detection WebKit configuration
- `OptimizedWebKitConfig` - Performance-tuned WebKit settings

### Communication Pattern
App-wide events use `NotificationCenter` with names defined in `CloudApp.swift`:
- `.showSpotlight`, `.showSettings`, `.toggleSidebar`
- `.goBack`, `.goForward`, `.reload`, `.addBookmark`

## Key Patterns

### Frecency Scoring
History entries use frecency (frequency + recency) via `FrecencyCalculator.swift`. Score combines visit count, typed count, and time decay.

### Tab Protection
- Pinned tabs ignore Cmd+W
- Tabs in folders are protected from accidental closure

### WebView Management
`BrowserViewModel.webViews` dictionary maps `UUID` to `WKWebView`. KVO observers track loading state.

### Persistence
UserDefaults-based persistence for:
- Spaces, tabs, folders (automatic save on change)
- Active tab/space IDs
- History, bookmarks

## Language

The codebase and comments are primarily in French. README and documentation use French.
