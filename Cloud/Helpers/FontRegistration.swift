//
//  FontRegistration.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import AppKit
import CoreText

enum FontRegistration {
    static func registerCustomFonts() {
        // List of custom fonts to register
        let fontNames = ["PixelifySans-Regular"]

        for fontName in fontNames {
            registerFont(named: fontName, withExtension: "ttf")
        }
    }

    private static func registerFont(named name: String, withExtension ext: String) {
        // Try to find the font in the main bundle (check Fonts subdirectory first)
        var url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fonts")

        // Fallback to root Resources directory
        if url == nil {
            url = Bundle.main.url(forResource: name, withExtension: ext)
        }

        guard let fontURL = url else {
            print("Font file not found: \(name).\(ext)")
            return
        }

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
            if let error = error?.takeRetainedValue() {
                let errorDescription = CFErrorCopyDescription(error) as String? ?? "Unknown error"
                // Font might already be registered, which is fine
                if !errorDescription.contains("already registered") {
                    print("Failed to register font \(name): \(errorDescription)")
                }
            }
        } else {
            print("Successfully registered font: \(name)")
        }
    }

    // Debug helper to list all available font families
    static func listAvailableFonts() {
        let fontFamilies = NSFontManager.shared.availableFontFamilies
        print("Available font families:")
        for family in fontFamilies.sorted() {
            if family.lowercased().contains("pixel") {
                print("  - \(family) (MATCH)")
            }
        }
    }
}
