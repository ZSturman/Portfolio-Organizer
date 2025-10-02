//
//  StepG_ResourcesView.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct StepG_ResourcesView: View {
    @ObservedObject var wiz: WizardCoordinator
    // Optional project directory for selecting existing files
    var projectDir: URL? = nil

    // Top-level category
    enum Category: String, CaseIterable, Identifiable {
        case repository, localDownload, app, url, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .repository: return "Repository"
            case .localDownload: return "Local download"
            case .app: return "App"
            case .url: return "URL"
            case .other: return "Other"
            }
        }
    }

    // Subtypes
    enum RepoKind: String, CaseIterable, Identifiable { case github, gitlab, bitbucket, other; var id: String { rawValue } }
    enum AppKind: String, CaseIterable, Identifiable { case windows, macAppStore, iosAppStore, googlePlay, steam, other; var id: String { rawValue } }
    enum URLKind: String, CaseIterable, Identifiable { case none, blog, youtube, overleaf, docs, slides, dataset, website, other; var id: String { rawValue } }
    enum OtherKind: String, CaseIterable, Identifiable { case email, contactForm, drive, dropbox, oneDrive, notion, figma, arxiv, zenodo, kaggle, huggingface, other; var id: String { rawValue } }

    // UI state
    @State private var category: Category = .repository
    @State private var repoKind: RepoKind = .github
    @State private var appKind: AppKind = .windows
    @State private var urlKind: URLKind = .none
    @State private var otherKind: OtherKind = .other

    @State private var linkText: String = "" // used for repo/app/url/other
    @State private var localURL: URL? = nil   // used for local download
    @State private var label: String = ""
    @State private var userEditedLabel: Bool = false
    @State private var isDragOver: Bool = false
    @State private var projectItems: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Entry row
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Picker("Type", selection: $category) {
                        ForEach(Category.allCases) { c in Text(c.label).tag(c) }
                    }
                    .frame(width: 180)

                    Group {
                        switch category {
                        case .repository:
                            HStack(spacing: 8) {
                                Picker("Repo", selection: $repoKind) {
                                    Text("GitHub").tag(RepoKind.github)
                                    Text("GitLab").tag(RepoKind.gitlab)
                                    Text("Bitbucket").tag(RepoKind.bitbucket)
                                    Text("Other").tag(RepoKind.other)
                                }
                                .frame(width: 140)
                                TextField("Repository URL", text: $linkText)
                                    .textFieldStyle(.roundedBorder)
                            }
                        case .localDownload:
                            HStack(spacing: 8) {
                                dropZone
                                Button("Choose…") { pickLocal() }
                                if let pd = projectDir {
                                    Menu("From project folder") {
                                        ForEach(projectItems, id: \.self) { u in
                                            Button(u.lastPathComponent) { localURL = u }
                                        }
                                    }
                                    .onAppear { loadProjectItems(from: pd) }
                                }
                                if let u = localURL {
                                    Text(u.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        case .app:
                            HStack(spacing: 8) {
                                Picker("Store", selection: $appKind) {
                                    Text("Windows").tag(AppKind.windows)
                                    Text("Mac App Store").tag(AppKind.macAppStore)
                                    Text("iOS App Store").tag(AppKind.iosAppStore)
                                    Text("Google Play").tag(AppKind.googlePlay)
                                    Text("Steam").tag(AppKind.steam)
                                    Text("Other").tag(AppKind.other)
                                }
                                .frame(width: 180)
                                TextField("Store link", text: $linkText)
                                    .textFieldStyle(.roundedBorder)
                            }
                        case .url:
                            HStack(spacing: 8) {
                                Picker("Kind", selection: $urlKind) {
                                    Text("None").tag(URLKind.none)
                                    Text("Blog").tag(URLKind.blog)
                                    Text("YouTube").tag(URLKind.youtube)
                                    Text("Overleaf").tag(URLKind.overleaf)
                                    Text("Docs").tag(URLKind.docs)
                                    Text("Slides").tag(URLKind.slides)
                                    Text("Dataset").tag(URLKind.dataset)
                                    Text("Website").tag(URLKind.website)
                                    Text("Other").tag(URLKind.other)
                                }
                                .frame(width: 160)
                                TextField("URL", text: $linkText)
                                    .textFieldStyle(.roundedBorder)
                            }
                        case .other:
                            HStack(spacing: 8) {
                                Picker("Method", selection: $otherKind) {
                                    Text("Email").tag(OtherKind.email)
                                    Text("Contact form").tag(OtherKind.contactForm)
                                    Text("Drive").tag(OtherKind.drive)
                                    Text("Dropbox").tag(OtherKind.dropbox)
                                    Text("OneDrive").tag(OtherKind.oneDrive)
                                    Text("Notion").tag(OtherKind.notion)
                                    Text("Figma").tag(OtherKind.figma)
                                    Text("arXiv").tag(OtherKind.arxiv)
                                    Text("Zenodo").tag(OtherKind.zenodo)
                                    Text("Kaggle").tag(OtherKind.kaggle)
                                    Text("HuggingFace").tag(OtherKind.huggingface)
                                    Text("Other").tag(OtherKind.other)
                                }
                                .frame(width: 180)
                                TextField("Link or address", text: $linkText)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    TextField("Label", text: $label, onEditingChanged: { editing in
                        if editing == true { userEditedLabel = true }
                    })
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)

                    Button("Add") { add() }
                        .disabled(!canAdd)
                }
            }

            // Existing list
            List {
                ForEach(wiz.project.resources) { r in
                    VStack(alignment: .leading) {
                        Text(r.label.isEmpty ? r.url : r.label).font(.headline)
                        Text("\(r.type) • \(r.url)").font(.caption)
                    }
                }
                .onDelete { idx in wiz.project.resources.remove(atOffsets: idx) }
            }
        }
        .padding()
        .onChange(of: category) { autoFillLabel() }
        .onChange(of: repoKind) { autoFillLabel() }
        .onChange(of: appKind) { autoFillLabel() }
        .onChange(of: urlKind) { autoFillLabel() }
        .onChange(of: otherKind) { autoFillLabel() }
        .onChange(of: linkText) { autoFillLabel() }
        .onChange(of: localURL) { autoFillLabel() }
    }

    // MARK: - Drop zone view for local download
    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDragOver ? .primary : .secondary, style: StrokeStyle(lineWidth: 1, dash: [5,5]))
                .frame(width: 220, height: 60)
            VStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down")
                Text("Drop file/folder/zip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragOver) { providers in
            handleFileDrop(providers)
        }
    }

    // MARK: - Actions
    private var canAdd: Bool {
        switch category {
        case .localDownload: return localURL != nil && !label.isEmpty
        default: return !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !label.isEmpty
        }
    }

    private func add() {
        let t = derivedType()
        let link: String
        switch category {
        case .localDownload:
            link = localURL?.absoluteString ?? ""
        default:
            link = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        wiz.project.resources.append(.init(type: t, label: label, url: link))
        // reset
        linkText = ""
        localURL = nil
        if !userEditedLabel { label = "" }
    }

    private func derivedType() -> String {
        switch category {
        case .repository:
            return "repository:\(repoKind.rawValue)"
        case .localDownload:
            return "local-download"
        case .app:
            return "app:\(appKind.rawValue)"
        case .url:
            return urlKind == .none ? "url" : "url:\(urlKind.rawValue)"
        case .other:
            return "other:\(otherKind.rawValue)"
        }
    }

    private func autoFillLabel() {
        guard !userEditedLabel else { return }
        switch category {
        case .repository:
            label = repoLabel(from: linkText, kind: repoKind)
        case .localDownload:
            if let u = localURL { label = u.lastPathComponent }
        case .app:
            label = appLabel(kind: appKind, link: linkText)
        case .url:
            if urlKind != .none { label = urlKind.rawValue.capitalized }
            else { label = hostOrTitle(from: linkText) }
        case .other:
            label = otherKind.rawValue.capitalized
        }
    }

    // MARK: - Label helpers
    private func repoLabel(from url: String, kind: RepoKind) -> String {
        let name = URL(string: url)?.deletingPathExtension().lastPathComponent
        let repoName = (name?.isEmpty == false ? name! : "repo")
        switch kind {
        case .github: return "GitHub: \(repoName)"
        case .gitlab: return "GitLab: \(repoName)"
        case .bitbucket: return "Bitbucket: \(repoName)"
        case .other: return "Repository: \(repoName)"
        }
    }

    private func appLabel(kind: AppKind, link: String) -> String {
        let base: String = {
            switch kind {
            case .windows: return "Windows download"
            case .macAppStore: return "Mac App Store"
            case .iosAppStore: return "App Store"
            case .googlePlay: return "Google Play"
            case .steam: return "Steam"
            case .other: return "App"
            }
        }()
        if let n = URL(string: link)?.deletingPathExtension().lastPathComponent, !n.isEmpty, kind == .windows {
            return "\(base): \(n)"
        }
        return base
    }

    private func hostOrTitle(from s: String) -> String {
        guard let u = URL(string: s), let host = u.host else { return "Link" }
        let last = u.deletingPathExtension().lastPathComponent
        if !last.isEmpty && last != "/" {
            return "\(host) / \(last)"
        }
        return host
    }

    // MARK: - File helpers
    private func pickLocal() {
        let p = NSOpenPanel()
        p.canChooseFiles = true
        p.canChooseDirectories = true
        p.allowsMultipleSelection = false
        if #available(macOS 12.0, *) {
            // Allow any file type; leaving empty means no restriction
            p.allowedContentTypes = []
        }
        if let dir = projectDir { p.directoryURL = dir }
        if p.runModal() == .OK { localURL = p.url }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let prov = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else { return false }
        var ok = false
        let _ = prov.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data, let s = String(data: data, encoding: .utf8), let u = URL(string: s) {
                DispatchQueue.main.async { self.localURL = u }
                ok = true
            } else if let url = item as? URL {
                DispatchQueue.main.async { self.localURL = url }
                ok = true
            }
        }
        return ok
    }

    private func loadProjectItems(from dir: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
        // show files, folders, and zips at top level only
        projectItems = items.filter { u in
            u.pathExtension.lowercased() == "zip" || true
        }.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}

