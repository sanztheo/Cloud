//
//  GoogleSuggestionsService.swift
//  Cloud
//
//  Created by Sanz on 20/11/2025.
//

import Combine
import Foundation

class GoogleSuggestionsService {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func fetchSuggestions(for query: String) -> AnyPublisher<[String], Never> {
    guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
      let url = URL(string: "https://google.com/complete/search?client=chrome&q=\(encodedQuery)")
    else {
      return Just([]).eraseToAnyPublisher()
    }

    return session.dataTaskPublisher(for: url)
      .map { $0.data }
      .tryMap { data -> [String] in
        // Google returns JSON in format: ["query", ["suggestion1", "suggestion2", ...], ...]
        guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [Any],
          jsonArray.count >= 2,
          let suggestions = jsonArray[1] as? [String]
        else {
          return []
        }
        return suggestions
      }
      .replaceError(with: [])
      .eraseToAnyPublisher()
  }
}
