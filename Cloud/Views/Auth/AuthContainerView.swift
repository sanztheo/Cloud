//
//  AuthContainerView.swift
//  Cloud
//

import SwiftUI

struct AuthContainerView: View {
    @State private var showLogin = true

    var body: some View {
        Group {
            if showLogin {
                LoginView(showLogin: $showLogin)
            } else {
                RegisterView(showLogin: $showLogin)
            }
        }
    }
}
