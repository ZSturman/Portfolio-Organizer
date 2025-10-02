//
//  RootSetupView.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation
import SwiftUI
import AppKit

struct RootSetupView: View {
    @EnvironmentObject var app: AppState

    @State private var userConfirmedRoot = false
    
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Portfolio Root").font(.headline)
                HStack {
                    Text(app.rootURL?.path ?? "No root selected")
                        .lineLimit(1)
                    Spacer()
                    Button("Choose…") { pickRoot() }
//                    Button("Default Setup") { createDefaultSetup() }
//                        .disabled(app.rootURL == nil || !userConfirmedRoot)
                }
                Divider()
                if userConfirmedRoot {
                    List(app.domains, id: \.self, selection: $app.selectedDomain) { url in
                        Text(url.lastPathComponent)
                    }
                } else {
                    Text("Choose a root to list domains")
                }
            }
            .padding()
        } content: {
            if let domain = app.selectedDomain {
                DomainProjectSplitView(domainURL: domain)
                    .id(domain)
            } else {
                Text("Select a domain")
            }
        } detail: {
            ProjectWizardHost()
        }
        .onChange(of: app.selectedDomain) {
            app.selectedProjectDir = nil
        }
        .onAppear { userConfirmedRoot = false }
    }

    func pickRoot() {
        app.promptForRootDirectory()
        userConfirmedRoot = true
    }

    func createDefaultSetup() {
        guard let root = app.rootURL else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let accessed = root.startAccessingSecurityScopedResource()
            defer { if accessed { root.stopAccessingSecurityScopedResource() } }
            for name in ["Creative","Technology","Expository"] {
                let dir = root.appendingPathComponent(name, isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            DispatchQueue.main.async { app.reloadDomains() }
        }
    }
}
