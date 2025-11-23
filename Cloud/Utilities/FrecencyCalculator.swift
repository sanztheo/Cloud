//
//  FrecencyCalculator.swift
//  Cloud
//
//  Created by Sanz on 23/11/2025.
//

import Foundation

struct FrecencyCalculator {
  // Weights for different visit types
  static let typedURLWeight: Double = 100.0
  static let bookmarkWeight: Double = 75.0
  static let clickedLinkWeight: Double = 50.0

  // Decay constant for exponential decay (0.1 means score halves every ~7 days)
  static let decayConstant: Double = 0.1

  /// Calculates frecency score based on visit frequency, recency, and visit type weights
  ///
  /// Formula: score = visitWeight × visitCount × e^(-decayConstant × daysSinceVisit)
  ///
  /// - Parameters:
  ///   - visitCount: Total number of times the URL was visited
  ///   - lastVisitDate: Date of the most recent visit
  ///   - typedCount: Number of times the URL was typed directly (as opposed to clicked)
  /// - Returns: A frecency score (higher = more frequent and recent)
  static func calculateScore(
    visitCount: Int,
    lastVisitDate: Date,
    typedCount: Int
  ) -> Double {
    let daysSinceVisit = daysSince(lastVisitDate)
    let recencyFactor = exp(-decayConstant * daysSinceVisit)

    // Calculate visit type weight based on typed count proportion
    let typedProportion = visitCount > 0 ? Double(typedCount) / Double(visitCount) : 0
    let clickedProportion = 1.0 - typedProportion

    // Weighted average of visit type weights
    let visitWeight = (typedProportion * typedURLWeight) + (clickedProportion * clickedLinkWeight)

    // Final score: weight × frequency × recency
    return visitWeight * Double(visitCount) * recencyFactor
  }

  /// Calculates frecency score with explicit visit type
  ///
  /// - Parameters:
  ///   - visitCount: Total number of visits
  ///   - lastVisitDate: Date of most recent visit
  ///   - visitType: The type of the current or representative visit
  /// - Returns: A frecency score
  static func calculateScore(
    visitCount: Int,
    lastVisitDate: Date,
    visitType: VisitType = .clickedLink
  ) -> Double {
    let daysSinceVisit = daysSince(lastVisitDate)
    let recencyFactor = exp(-decayConstant * daysSinceVisit)
    let weight = visitType.weight

    return weight * Double(visitCount) * recencyFactor
  }

  /// Returns the number of days elapsed since a given date
  ///
  /// - Parameter date: The reference date
  /// - Returns: Number of days elapsed (can be fractional for times less than 24 hours)
  static func daysSince(_ date: Date) -> Double {
    let elapsed = Date().timeIntervalSince(date)
    return elapsed / (24 * 3600)  // Convert seconds to days
  }

  /// Determines if a URL should be considered "fresh" (recently visited)
  ///
  /// - Parameters:
  ///   - lastVisitDate: Date of most recent visit
  ///   - threshold: Number of days to consider "fresh" (default: 1 day)
  /// - Returns: True if visited within threshold, false otherwise
  static func isFresh(lastVisitDate: Date, threshold: TimeInterval = 1) -> Bool {
    let elapsed = Date().timeIntervalSince(lastVisitDate)
    return elapsed < (threshold * 24 * 3600)
  }

  /// Returns a human-readable frecency category
  ///
  /// - Parameter score: The frecency score
  /// - Returns: A descriptive category
  static func categoryForScore(_ score: Double) -> String {
    switch score {
    case 1000...:
      return "Very Frequent"
    case 500..<1000:
      return "Frequent"
    case 100..<500:
      return "Regular"
    case 10..<100:
      return "Occasional"
    default:
      return "Rare"
    }
  }
}

// MARK: - Visit Type Enum
enum VisitType {
  case typedURL
  case bookmark
  case clickedLink

  var weight: Double {
    switch self {
    case .typedURL:
      return FrecencyCalculator.typedURLWeight
    case .bookmark:
      return FrecencyCalculator.bookmarkWeight
    case .clickedLink:
      return FrecencyCalculator.clickedLinkWeight
    }
  }
}
