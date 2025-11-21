//
//  String+Markdown.swift
//  Cloud
//
//  Extension to convert Markdown strings to AttributedString for live rendering
//

import SwiftUI

extension String {
  /// Convert a Markdown string to AttributedString for SwiftUI Text rendering
  /// Supports: # headings, **bold**, *italic*, bullet points, and line breaks
  func toMarkdown(baseColor: Color) -> AttributedString {
    // Process headers manually since SwiftUI doesn't support them natively
    var result = processMarkdownHeaders(self, baseColor: baseColor)
    result.foregroundColor = baseColor
    return result
  }

  /// Process Markdown headers and convert to styled AttributedString
  private func processMarkdownHeaders(_ text: String, baseColor: Color) -> AttributedString {
    var result = AttributedString()
    let lines = text.components(separatedBy: "\n")

    for (index, line) in lines.enumerated() {
      var styledLine = AttributedString()

      if line.hasPrefix("### ") {
        // H3 - Small header
        let content = String(line.dropFirst(4))
        styledLine = parseInlineMarkdown(content, baseColor: baseColor)
        styledLine.font = .system(size: 14, weight: .semibold)
      } else if line.hasPrefix("## ") {
        // H2 - Medium header
        let content = String(line.dropFirst(3))
        styledLine = parseInlineMarkdown(content, baseColor: baseColor)
        styledLine.font = .system(size: 16, weight: .bold)
      } else if line.hasPrefix("# ") {
        // H1 - Large header
        let content = String(line.dropFirst(2))
        styledLine = parseInlineMarkdown(content, baseColor: baseColor)
        styledLine.font = .system(size: 18, weight: .bold)
      } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
        // Bullet point
        let content = String(line.dropFirst(2))
        var bullet = AttributedString("• ")
        bullet.font = .system(size: 14)
        bullet.foregroundColor = baseColor
        styledLine = bullet + parseInlineMarkdown(content, baseColor: baseColor)
      } else {
        // Regular text
        styledLine = parseInlineMarkdown(line, baseColor: baseColor)
      }

      styledLine.foregroundColor = baseColor
      result += styledLine

      // Add newline between lines (except after last line)
      if index < lines.count - 1 {
        var newline = AttributedString("\n")
        newline.foregroundColor = baseColor
        result += newline
      }
    }

    return result
  }

  /// Parse inline Markdown (bold, italic) within a line
  private func parseInlineMarkdown(_ text: String, baseColor: Color) -> AttributedString {
    do {
      var attributed = try AttributedString(
        markdown: text,
        options: AttributedString.MarkdownParsingOptions(
          interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
      )
      // Set default font if not already set
      if attributed.font == nil {
        attributed.font = .system(size: 14)
      }
      attributed.foregroundColor = baseColor
      return attributed
    } catch {
      var plain = AttributedString(text)
      plain.foregroundColor = baseColor
      return plain
    }
  }
}
