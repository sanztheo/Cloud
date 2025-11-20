# Spotlight Arc Browser Redesign

## Overview
Redesigned the Spotlight interface to match Arc browser's design language and behavior, including new tab creation instead of navigating current tab.

## Design Changes

### Visual Improvements
1. **Larger Row Height**: Increased from 54px to 66px for more spacious layout
2. **Increased Spacing**:
   - Horizontal padding: 12px → 16px
   - Vertical padding: 13px → 15px
   - Inter-cell spacing: 2px → 4px
3. **Larger Icons**: Circular backgrounds increased from 32px to 36px
4. **Better Typography**:
   - Title font: 14px → 15px (medium weight)
   - Subtitle font: 12px → 13px
5. **Arc-Style Selection**:
   - Blue/teal gradient background (#4A7C8E)
   - White text on selected rows
   - Smooth animations (0.15s duration)
6. **"Switch to Tab" Badge**:
   - Shown only for existing tabs
   - Styled badge container with rounded corners
   - Hidden for bookmarks, history, and suggestions

### Layout Updates
- Corner radius: 10px → 12px for selection background
- Background inset: 8px → 10px horizontal
- Removed "⏎ to open" hint, replaced with contextual badge
- Maximum results height: 360px → 400px

## Behavior Changes

### New Tab Creation (Arc-Style)
**Previous Behavior:**
- Clicking or pressing Enter on search results navigated the current tab
- All result types replaced current tab content

**New Behavior:**
- **Existing Tabs** (.tab type): Switch to that tab (no new tab created)
- **Bookmarks** (.bookmark type): Open in NEW tab
- **History** (.history type): Open in NEW tab
- **Suggestions** (.suggestion type): Open in NEW tab (Google search)

### Implementation Details

#### SpotlightViewController.swift
- Increased row height and spacing
- Larger icon circles (36px)
- Better font hierarchy (15px/13px)
- Arc blue selection color (#4A7C8E)
- Conditional badge display (only for .tab type)
- Removed unused badgeConfig method
- Updated container height calculation

#### BrowserViewModel.swift
- Modified `selectSearchResult()` method
- Existing tabs: call `selectTab(tabId)` to switch
- All other types: call `createNewTab(url:)` to open new tab
- Closes Spotlight after selection

## Visual Design Reference

### Arc Browser Style Elements
- Rounded selection with blue/teal background
- "Switch to Tab" badge for existing tabs
- Larger, more spacious layout
- Clean typography hierarchy
- Circular icon backgrounds
- Better use of whitespace

### Color Palette
- Arc Blue: RGB(74, 124, 142) / #4A7C8E
- Selected text: White
- Selected subtitle: White with 70% opacity
- Badge background: Arc blue with 20% opacity
- Selected badge: White with 15% opacity

## Code Quality
- All AppKit implementations maintained
- Keyboard navigation preserved
- Hover and auto-scroll functionality intact
- Smooth animations using NSAnimationContext
- Clean, maintainable code structure

## Testing Recommendations
1. Test keyboard navigation (up/down arrows, Enter, Escape)
2. Verify mouse hover and click behavior
3. Confirm new tab creation for bookmarks/history/suggestions
4. Verify tab switching for existing tabs
5. Test animations and visual transitions
6. Verify badge display logic (only for .tab type)
