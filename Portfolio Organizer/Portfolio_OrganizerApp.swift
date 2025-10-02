//
//  Portfolio_OrganizerApp.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import SwiftUI

@main
struct PortfolioApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootSetupView()
                .environmentObject(app)
        }
        .windowStyle(.titleBar)
    }
}
