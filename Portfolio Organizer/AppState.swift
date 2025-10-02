//
//  AppState.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
final class AppState: ObservableObject {
    @Published var isCurrentProjectDirty: Bool = false
    @Published var rootURL: URL? {
        didSet { persistBookmark() ; reloadDomains() }
    }
    @Published var domains: [URL] = []
    @Published var selectedDomain: URL?
    @Published var selectedProjectDir: URL?
    @Published var project: Project = .empty()
    @Published var config: Config = .default()
    @Published var allTags: Set<String> = []
    @Published var dirtyProjects: Set<URL> = []
    @Published var editedProjects: [URL: Project] = [:]
    @Published var isLoadingTags: Bool = false

    private let defaultsKey = "portfolio.root.bookmark"
    private let tagsDefaultsKey = "portfolio.allTags"
    private var bookmarkData: Data?

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let url = try? BookmarkStore.resolve(bookmark: data) {
            bookmarkData = data
            rootURL = url
            reloadDomains()
        }
        if let arr = UserDefaults.standard.array(forKey: tagsDefaultsKey) as? [String] {
            allTags = Set(arr)
        }
    }

    /// Presents an NSOpenPanel to let the user select the root folder.
    /// Grants Powerbox access and persists a security-scoped bookmark.
    func promptForRootDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose the portfolio root folder"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            // Start security scope for immediate access while we scan/persist
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            self?.chooseRoot(url)
        }
    }

    /// Runs a closure while holding a security-scope on the given URL.
    @discardableResult
    nonisolated private static func withScopedAccess<T>(to url: URL, _ work: () throws -> T) rethrows -> T {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try work()
    }

    func chooseRoot(_ url: URL) {
        do {
            let b = try BookmarkStore.makeBookmark(for: url)
            bookmarkData = b
            UserDefaults.standard.set(b, forKey: defaultsKey)
            let resolved = try BookmarkStore.resolve(bookmark: b)
            rootURL = resolved
            self.refreshAllTagsIfNeeded(for: resolved)
        } catch {
            print("bookmark error:", error)
            rootURL = url // fallback
        }
    }

    func persistBookmark() {
        guard let root = rootURL else { return }
        bookmarkData = try? BookmarkStore.makeBookmark(for: root)
        if let b = bookmarkData { UserDefaults.standard.set(b, forKey: defaultsKey) }
    }

    func reloadDomains() {
        guard let root = rootURL else { domains = []; return }
        domains = (try? Self.withScopedAccess(to: root) {
            try PortfolioScanner.listDomains(at: root)
        }) ?? []
        self.refreshAllTagsIfNeeded(for: root)
    }

    func listProjectsIncludingIdeas(in domainURL: URL) -> [ProjectRef] {
        let scopeURL = rootURL ?? domainURL
        return Self.withScopedAccess(to: scopeURL) {
            PortfolioScanner.listProjectsIncludingIdeas(in: domainURL)
        }
    }

    func pickProject(domainURL: URL, projectName: String) {
        let dir = domainURL.appendingPathComponent(projectName, isDirectory: true)
        let scopeURL = rootURL ?? dir

        selectedDomain = domainURL
        selectedProjectDir = dir

        Self.withScopedAccess(to: scopeURL) {
            if let edited = editedProjects[dir] {
                project = edited
            } else if let p = try? ProjectStore.load(from: dir) {
                project = p
            } else {
                project = .seed(domain: domainURL.lastPathComponent,
                                folder: projectName,
                                isIdea: domainURL.lastPathComponent == "_IDEAS_")
            }
        }
    }

    /// Picks a project located in a subfolder (e.g., _IDEAS_) while preserving the top-level domain selection.
    /// - Parameters:
    ///   - topDomainURL: The top-level domain folder URL (e.g., .../Technology)
    ///   - projectDir: The directory of the project to select (may be inside a special folder like _IDEAS_)
    func pickProjectPreservingTopDomain(topDomainURL: URL, projectDir: URL) {
        // Preserve the top-level domain selection for the UI tabs
        selectedDomain = topDomainURL
        selectedProjectDir = projectDir

        let scopeURL = rootURL ?? projectDir
        Self.withScopedAccess(to: scopeURL) {
            if let edited = editedProjects[projectDir] {
                project = edited
            } else if let p = try? ProjectStore.load(from: projectDir) {
                project = p
            } else {
                let parentName = projectDir.deletingLastPathComponent().lastPathComponent
                let isIdea = parentName == "_IDEAS_"
                project = .seed(domain: topDomainURL.lastPathComponent,
                                folder: projectDir.lastPathComponent,
                                isIdea: isIdea)
            }
        }
    }

    func saveProject() {
        guard let dir = selectedProjectDir else { return }
        let scopeURL = rootURL ?? dir
        _ = Self.withScopedAccess(to: scopeURL) {
            try? ProjectStore.save(project, to: dir)
        }
        editedProjects.removeValue(forKey: dir)
        dirtyProjects.remove(dir)
        saveAllTags()
    }

    // MARK: next-unreviewed
    struct ProjectRef: Comparable, Hashable {
        let domainURL: URL
        let name: String
        var dir: URL { domainURL.appendingPathComponent(name, isDirectory: true) }
        static func < (l: Self, r: Self) -> Bool {
            l.name.localizedCaseInsensitiveCompare(r.name) == .orderedAscending
        }
    }

    func isUnreviewed(_ dir: URL) -> Bool {
        let url = dir.appendingPathComponent("_project.json")
        let scopeURL = rootURL ?? dir

        let obj: [String: Any] = Self.withScopedAccess(to: scopeURL) {
            guard let data = try? Data(contentsOf: url) else { return [:] }
            return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }

        guard !obj.isEmpty else { return false }
        if let r = obj["reviewed"] {
            if let b = r as? Bool { return b == false }
            if r is String { return false }
        }
        let status = (obj["status"] as? String) ?? ""
        return status == "idea"
    }

    @discardableResult
    func selectNextUnreviewed(after current: ProjectRef?) -> Bool {
        guard let domain = selectedDomain else { return false }
        let all = listProjectsIncludingIdeas(in: domain)
        let startIdx = current.flatMap { all.firstIndex(of: $0) } ?? -1
        for i in (startIdx+1)..<all.count {
            let cand = all[i]
            if isUnreviewed(cand.dir) {
                pickProject(domainURL: cand.domainURL.path.hasSuffix("_IDEAS_") ? domain : domain,
                            projectName: cand.name)
                return true
            }
        }
        return false
    }

    func registerTag(_ tag: String) {
        let t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        allTags.insert(t)
        saveAllTags()
    }

    func refreshAllTagsIfNeeded(for rootOrDomain: URL?) {
        guard let rootOrDomain = rootOrDomain else { return }

        // Capture any @MainActor state we need BEFORE hopping to a background queue
        let scanBase = self.rootURL ?? rootOrDomain
        let scanTarget = self.rootURL ?? rootOrDomain

        self.isLoadingTags = true

        DispatchQueue.global(qos: .background).async {
            var tags = Set<String>()
            let fm = FileManager.default

            func scan(_ dir: URL) {
                if let kids = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                    for k in kids {
                        let isDir = (try? k.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                        if isDir { scan(k) }
                        if k.lastPathComponent == "_project.json" {
                            if let data = try? Data(contentsOf: k),
                               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let arr = obj["tags"] as? [String] {
                                for t in arr { tags.insert(t) }
                            }
                        }
                    }
                }
            }

            // Use captured values; do not reference self here
            Self.withScopedAccess(to: scanBase) {
                scan(scanTarget)
            }

            // Hop back to the main actor to update observable state and persistence
            DispatchQueue.main.async {
                let persisted = Set(UserDefaults.standard.array(forKey: self.tagsDefaultsKey) as? [String] ?? [])
                let merged = persisted.union(self.allTags).union(tags)
                self.allTags = merged
                self.saveAllTags()
                self.isLoadingTags = false
            }
        }
    }

    private func saveAllTags() {
        UserDefaults.standard.set(Array(allTags).sorted(), forKey: tagsDefaultsKey)
    }

    func saveAllEditedProjects() {
        let items = editedProjects
        for (dir, proj) in items {
            let scopeURL = rootURL ?? dir
            _ = Self.withScopedAccess(to: scopeURL) {
                try? ProjectStore.save(proj, to: dir)
            }
            editedProjects.removeValue(forKey: dir)
            dirtyProjects.remove(dir)
        }
        saveAllTags()
    }
}

