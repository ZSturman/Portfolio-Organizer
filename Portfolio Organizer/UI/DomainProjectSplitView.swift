//
//  DomainProjectSplitView.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation
import SwiftUI

struct DomainProjectSplitView: View {
    @EnvironmentObject var app: AppState
    let domainURL: URL
    @State private var projects: [String] = []
    @State private var specialFolders: [URL] = []

    var body: some View {
        VStack {
            HStack {
                Text(domainURL.lastPathComponent).font(.title3)
                Spacer()
                Button("New Project") { newProject() }
            }
            TabView {
                // Main projects tab (excludes underscore-wrapped folders)
                List(projects, id: \.self) { name in
                    let dir = domainURL.appendingPathComponent(name, isDirectory: true)
                    Button(action: { load(name) }) {
                        HStack(spacing: 8) {
                            // Leading icon for Project vs Not A Project
                            if hasProjectJSON(in: dir) {
                                Image(systemName: statusIcon(for: dir)).foregroundColor(.accentColor)
                            } else {
                                Image(systemName: "folder").foregroundColor(.secondary)
                            }

                            // Title and optional file count
                            Text(name)
                            if !hasProjectJSON(in: dir) {
                                Text("(\(nonProjectFileCount(in: dir)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            // Reviewed indicator (needs attention if reviewed == false)
                            if needsAttention(dir) {
                                Label("Needs review", systemImage: "exclamationmark.circle.fill")
                                    .labelStyle(.iconOnly)
                                    .foregroundColor(.orange)
                                    .help("Not reviewed yet")
                            }
                            // Visibility indicator (public/private)
                            if let vis = readVisibility(in: dir) {
                                Image(systemName: vis == "public" ? "globe" : "lock.fill")
                                    .foregroundColor(vis == "public" ? .blue : .secondary)
                                    .help(vis.capitalized)
                            }

                            Spacer()

                            // Unsaved changes indicator for currently selected project
                            if app.dirtyProjects.contains(dir) {
                                Circle().fill(Color.orange).frame(width: 8, height: 8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

                // Tabs for each special folder (starts and ends with underscore)
                ForEach(specialFolders, id: \.self) { folder in
                    SpecialFolderListView(parentURL: folder) { subfolderName in
                        loadSpecial(parentURL: folder, name: subfolderName)
                    }
                    .environmentObject(app)
                    .tabItem {
                        Label(displayName(for: folder.lastPathComponent), systemImage: "folder")
                    }
                }
            }
        }
        .padding()
        .onAppear { refresh() }
        .onChange(of: domainURL) {
            refresh()
        }
    }

    func refresh() {
        let fm = FileManager.default
        var normal: [String] = []
        var specials: [URL] = []
        if let kids = try? fm.contentsOfDirectory(at: domainURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for k in kids {
                let isDir = (try? k.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir else { continue }
                let name = k.lastPathComponent
                if isUnderscoreWrapped(name) {
                    specials.append(k)
                } else {
                    normal.append(name)
                }
            }
        }
        normal.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        specials.sort { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        projects = normal
        specialFolders = specials
    }

    func isUnderscoreWrapped(_ name: String) -> Bool {
        return name.hasPrefix("_") && name.hasSuffix("_") && name.count >= 2
    }

    func displayName(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        guard let first = trimmed.first else { return raw }
        let rest = trimmed.dropFirst().lowercased()
        return String(first).uppercased() + rest
    }

    func load(_ name: String) {
        app.pickProject(domainURL: domainURL, projectName: name)
    }

    func newProject() {
        let alert = NSAlert()
        alert.messageText = "New Project Name"
        let field = NSTextField(string: "")
        alert.accessoryView = field
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            let dir = domainURL.appendingPathComponent(name, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            app.pickProject(domainURL: domainURL, projectName: name)
            refresh()
        }
    }

    func loadSpecial(parentURL: URL, name: String) {
        // parentURL is the special folder (e.g., .../Technology/_IDEAS_)
        let projectDir = parentURL.appendingPathComponent(name, isDirectory: true)
        // Ensure we keep the top-level domain (the owner of the special folder)
        let topDomainURL = domainURL
        app.pickProjectPreservingTopDomain(topDomainURL: topDomainURL, projectDir: projectDir)
    }

    func hasProjectJSON(in dir: URL) -> Bool {
        let file = dir.appendingPathComponent("_project.json")
        return FileManager.default.fileExists(atPath: file.path)
    }

    func readProjectStatus(in dir: URL) -> String? {
        let url = dir.appendingPathComponent("_project.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["status"] as? String
    }

    func statusIcon(for dir: URL) -> String {
        switch (readProjectStatus(in: dir) ?? "").lowercased() {
        case "idea": return "lightbulb"
        case "draft": return "doc.badge.ellipsis"
        case "active": return "hammer"
        case "paused": return "pause.circle"
        case "completed": return "checkmark.seal"
        default: return "doc"
        }
    }

    func nonProjectFileCount(in dir: URL) -> Int {
        let fm = FileManager.default
        guard let kids = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return 0 }
        // Count files and subfolders excluding the _project.json file
        return kids.filter { $0.lastPathComponent != "_project.json" }.count
    }

    func isCurrentlySelected(_ dir: URL) -> Bool {
        return app.selectedProjectDir == dir
    }
    
    func readVisibility(in dir: URL) -> String? {
        let url = dir.appendingPathComponent("_project.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (obj["visibility"] as? String)?.lowercased()
    }
    func needsAttention(_ dir: URL) -> Bool {
        let url = dir.appendingPathComponent("_project.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        if let r = obj["reviewed"] as? Bool { return r == false }
        return false
    }
}

private struct SpecialFolderListView: View {
    let parentURL: URL
    let onSelect: (String) -> Void
    @State private var subfolders: [String] = []
    @EnvironmentObject var app: AppState

    func hasProjectJSON(in dir: URL) -> Bool {
        let file = dir.appendingPathComponent("_project.json")
        return FileManager.default.fileExists(atPath: file.path)
    }
    func readProjectStatus(in dir: URL) -> String? {
        let url = dir.appendingPathComponent("_project.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["status"] as? String
    }
    func statusIcon(for dir: URL) -> String {
        switch (readProjectStatus(in: dir) ?? "").lowercased() {
        case "idea": return "lightbulb"
        case "draft": return "doc.badge.ellipsis"
        case "active": return "hammer"
        case "paused": return "pause.circle"
        case "completed": return "checkmark.seal"
        default: return "doc"
        }
    }
    func nonProjectFileCount(in dir: URL) -> Int {
        let fm = FileManager.default
        guard let kids = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return 0 }
        return kids.filter { $0.lastPathComponent != "_project.json" }.count
    }
    func isCurrentlySelected(_ dir: URL) -> Bool {
        return app.selectedProjectDir == dir
    }

    func readVisibility(in dir: URL) -> String? {
        let url = dir.appendingPathComponent("_project.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (obj["visibility"] as? String)?.lowercased()
    }
    func needsAttention(_ dir: URL) -> Bool {
        let url = dir.appendingPathComponent("_project.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        if let r = obj["reviewed"] as? Bool { return r == false }
        return false
    }

    var body: some View {
        List(subfolders, id: \.self) { name in
            let dir = parentURL.appendingPathComponent(name, isDirectory: true)
            Button(action: { onSelect(name) }) {
                HStack(spacing: 8) {
                    if hasProjectJSON(in: dir) {
                        Image(systemName: statusIcon(for: dir)).foregroundColor(.accentColor)
                    } else {
                        Image(systemName: "folder").foregroundColor(.secondary)
                    }
                    Text(name)
                    if !hasProjectJSON(in: dir) {
                        Text("(\(nonProjectFileCount(in: dir)))").font(.caption).foregroundColor(.secondary)
                    }
                    // Reviewed indicator (needs attention if reviewed == false)
                    if needsAttention(dir) {
                        Label("Needs review", systemImage: "exclamationmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.orange)
                            .help("Not reviewed yet")
                    }
                    // Visibility indicator (public/private)
                    if let vis = readVisibility(in: dir) {
                        Image(systemName: vis == "public" ? "globe" : "lock.fill")
                            .foregroundColor(vis == "public" ? .blue : .secondary)
                            .help(vis.capitalized)
                    }
                    Spacer()
                    if app.dirtyProjects.contains(dir) {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .onAppear { refresh() }
        .onChange(of: parentURL) { refresh() }
    }

    private func refresh() {
        subfolders = (try? PortfolioScanner.listProjects(in: parentURL)) ?? []
    }
}

