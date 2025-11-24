//
//  SupabaseConfig.swift
//  Cloud
//
//  Created by Sanz on 24/11/2025.
//

import Foundation
import Supabase

enum SupabaseConfig {
    static var url: URL {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not found in Info.plist. Make sure Secrets.xcconfig is configured.")
        }
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist. Make sure Secrets.xcconfig is configured.")
        }
        return key
    }

    static var client: SupabaseClient {
        SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }
}
