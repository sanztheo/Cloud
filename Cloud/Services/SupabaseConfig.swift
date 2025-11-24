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
              !urlString.isEmpty,
              !urlString.contains("$("),
              let url = URL(string: urlString) else {
            fatalError("""
                SUPABASE_URL not found in Info.plist.

                Configuration requise:
                1. Vérifie que Cloud/Config/Secrets.xcconfig existe avec tes clés
                2. Dans Xcode → Project → Info → Configurations:
                   - Debug → Cloud (PROJECT) = Debug.xcconfig
                   - Release → Cloud (PROJECT) = Release.xcconfig
                3. Clean Build (Cmd+Shift+K) puis Build (Cmd+B)
                """)
        }
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              !key.contains("$(") else {
            fatalError("""
                SUPABASE_ANON_KEY not found in Info.plist.

                Configuration requise:
                1. Vérifie que Cloud/Config/Secrets.xcconfig existe avec tes clés
                2. Dans Xcode → Project → Info → Configurations:
                   - Debug → Cloud (PROJECT) = Debug.xcconfig
                   - Release → Cloud (PROJECT) = Release.xcconfig
                3. Clean Build (Cmd+Shift+K) puis Build (Cmd+B)
                """)
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
