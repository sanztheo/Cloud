# Modern SaaS Authentication UI Design Specification

## 📐 Design System Values

### Spacing System (Points)
- **Container Padding**: 60pt (main content padding from edges)
- **Top Padding**: 80pt (space above logo)
- **Section Spacing**: 32pt (between major sections)
- **Element Spacing**: 16pt (between related elements)
- **Small Spacing**: 8pt (between tightly coupled elements)
- **Button Grid Spacing**: 12pt (gap between social buttons)
- **Divider Padding**: 24pt (space around OR divider)

### Typography Scale
| Element | Size | Weight | Color |
|---------|------|--------|-------|
| Logo | 32pt | - | #0A0A0A |
| Main Heading | 28pt | Bold (700) | #0A0A0A |
| Subtitle | 15pt | Regular (400) | #6B7280 |
| Button Text | 14pt | Medium (500) | #374151 |
| Helper Text | 13pt | Regular (400) | #6B7280 |
| Footer Links | 12pt | Regular (400) | #4B5563 |

### Color Palette
| Element | Hex Code | Usage |
|---------|----------|-------|
| **Primary Colors** |
| Heading Black | #0A0A0A | Headlines, primary button bg |
| Body Text | #374151 | Button labels, form text |
| Subtle Text | #6B7280 | Descriptions, helper text |
| Light Text | #9CA3AF | Divider text, disabled states |
| **Backgrounds** |
| White | #FFFFFF | Form panel, button backgrounds |
| Light Gray | #F7F9FC | Right panel fallback |
| Hover Gray | #F9FAFB | Button hover states |
| **Borders** |
| Light Border | #E5E7EB | Button borders, dividers |
| Medium Border | #D1D5DB | Input field borders |
| **Interactive States** |
| Primary Hover | #1F1F1F | Dark button hover |
| Link Hover | #0A0A0A | Footer link hover |
| Focus Ring | #0A0A0A | Input field focus |

### Component Dimensions
| Component | Height | Border Radius | Border Width |
|-----------|--------|---------------|--------------|
| Social Button | 44pt | 8pt | 1pt |
| Primary Button | 44pt | 8pt | - |
| Text Field | 44pt | 8pt | 1pt |
| Icon Size | 20pt | - | - |

### Layout Structure
- **Split Ratio**: 50/50 (with min width 480pt for auth panel)
- **Max Form Width**: 400pt
- **Min Window Width**: 960pt
- **Min Window Height**: 600pt

## 🎨 Visual Hierarchy

### Component Hierarchy (Top to Bottom)
1. **Logo Section**
   - Centered horizontally
   - 80pt from top edge

2. **Title Block**
   - Main heading + subtitle
   - 32pt below logo
   - Center aligned text

3. **Social Login Grid**
   - 2x2 grid layout
   - 32pt below title block
   - 12pt gaps between buttons

4. **Divider Section**
   - 24pt padding above and below
   - Horizontal line with centered "OR" text

5. **Email Form**
   - Text field + helper text + button
   - 24pt below divider
   - Full width components

6. **Footer Links**
   - 32pt below email section
   - Centered with bullet separator

## 🖱️ Interaction States (macOS-specific)

### Hover States
| Component | Default | Hover |
|-----------|---------|-------|
| Social Button | White bg | #F9FAFB bg |
| Primary Button | #0A0A0A bg | #1F1F1F bg |
| Footer Links | #4B5563 | #0A0A0A |
| Text Field | #D1D5DB border | No change |

### Focus States
| Component | Focus Behavior |
|-----------|---------------|
| Text Field | Border changes to #0A0A0A, 1pt width |
| Buttons | System default focus ring |
| Links | Underline on keyboard navigation |

### Active/Pressed States
- Buttons: Scale to 0.98 with spring animation
- Links: Immediate color change

## 📱 Responsive Behavior

### Breakpoints
- **Large**: > 1200pt width (comfortable spacing)
- **Medium**: 960-1200pt (default layout)
- **Small**: < 960pt (not supported, show minimum size warning)

### Panel Behavior
- Left panel: Min 480pt, max 600pt
- Right panel: Fills remaining space
- Content: Max 400pt width, centered in left panel

## 🏗️ SwiftUI Implementation Structure

```
ModernAuthView
├── HStack (spacing: 0)
│   ├── Left Panel (50% or min 480pt)
│   │   └── ScrollView
│   │       └── VStack (custom spacing)
│   │           ├── Logo Image
│   │           ├── Title Text
│   │           ├── Subtitle Text
│   │           ├── LazyVGrid (2 columns)
│   │           │   └── SocialLoginButton × 4
│   │           ├── HStack (OR Divider)
│   │           ├── VStack (Email Section)
│   │           │   ├── TextField
│   │           │   ├── Helper Text
│   │           │   └── Primary Button
│   │           └── HStack (Footer Links)
│   └── Right Panel (remaining space)
│       └── ZStack
│           ├── Gradient/Image Background
│           └── Content Overlay
```

## 🎯 Key Implementation Notes

1. **No Navigation Bar**: Window should hide title bar or use custom window styling
2. **Keyboard Navigation**: Ensure all interactive elements are keyboard accessible
3. **Text Field Focus**: Use `.onFocusChange` modifier for focus tracking
4. **Button Styles**: Use `PlainButtonStyle()` to avoid default macOS button chrome
5. **Hover Tracking**: Use `@State` variable to track hover states
6. **Smooth Animations**: Add `.animation(.easeInOut(duration: 0.2))` for state changes
7. **Accessibility**: Include proper labels and hints for VoiceOver support

## 🚀 Advanced Features (Optional)

- **Password Strength Indicator**: For signup flow
- **Loading States**: Spinner overlay during authentication
- **Error Messages**: Inline validation below fields
- **Success Animation**: Checkmark animation on successful auth
- **Keyboard Shortcuts**: Cmd+Return to submit form
- **Remember Me**: Checkbox below email field
- **Language Selector**: Dropdown in footer area