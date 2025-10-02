import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import Quartz
import QuickLookThumbnailing
#endif

struct FileNode: Identifiable {
    let id = UUID()
    let url: URL
    var children: [FileNode]? // nil for files
}

struct FolderPreviewView: View {
    let folderURL: URL

    @State private var currentURL: URL
    @State private var tree: [FileNode] = []

    @State private var showingAddFilePicker = false
    @State private var newSubfolderName = ""
    @State private var showingNewSubfolderAlert = false
    @State private var editingURL: URL?
    @State private var editingName: String = ""

    @State private var previewURL: URL?
    @State private var isShowingPreview: Bool = false

    @State private var showingMarkdownEditor = false
    @State private var markdownText: String = ""
    @State private var markdownFilename: String = "New Note.md"
    @State private var isSavingMarkdown = false
    
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
    #if os(macOS)
    @State private var thumbCache: [URL: NSImage] = [:]
    private class ThumbTracker {
        static var inFlight = Set<URL>()
    }
    #endif
    
    private enum ViewMode: String, CaseIterable, Identifiable { case list, grid; var id: String { rawValue } }
    @State private var viewMode: ViewMode = .list
    
    
    init(folderURL: URL) {
        self.folderURL = folderURL
        _currentURL = State(initialValue: folderURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack {
                
                
                HStack {
                    if currentURL != folderURL {
                        Button {
                            navigateUp()
                        } label: {
                            Label("Up", systemImage: "chevron.left")
                        }
                    }
                    Text(breadcrumb(for: currentURL))
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Picker("View", selection: $viewMode) {
                        Text("List").tag(ViewMode.list)
                        Text("Grid").tag(ViewMode.grid)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                    Spacer()
                    
                }
                HStack {
                    Button {
                        newSubfolderName = ""
                        showingNewSubfolderAlert = true
                    } label: { Label("New Folder…", systemImage: "folder.badge.plus") }
                    .buttonStyle(.borderless)
                    .help("Create a new subfolder at the current level")

                    Button {
                        markdownFilename = "New Note.md"
                        markdownText = """
# New Note

- Write your notes here.
- This is **markdown**.

"""
                        showingMarkdownEditor = true
                    } label: { Label("Add Markdown…", systemImage: "doc.badge.plus") }
                    .buttonStyle(.borderless)
                    .help("Create a markdown file in the current folder")
                    Spacer()
                }

            }

            Group {
                if viewMode == .list {
                    List {
                        OutlineGroup(tree, children: \.children) { node in
                            let url = node.url
                            HStack {
                                Image(systemName: isDirectory(url) ? "folder" : "doc.text")
                                    .foregroundColor(isDirectory(url) ? .accentColor : .secondary)
                                if editingURL == url {
                                    TextField("", text: $editingName, onCommit: { commitEdit() })
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(minWidth: 180)
                                } else {
                                    Text(url.lastPathComponent)
                                        .onTapGesture(count: 2) {
                                            if isDirectory(url) { navigateInto(url) }
                                            else { open(url) }
                                        }
                                        .onTapGesture(count: 1) {
                                            if !isDirectory(url) { quickLook(url) }
                                        }
                                }
                                Spacer()
                            }
                            .contextMenu {
                                if isDirectory(url) {
                                    Button("Open") { navigateInto(url) }
                                    Button("New Folder…") {
                                        newSubfolderName = ""
                                        editingURL = nil
                                        showingNewSubfolderAlert = true
                                    }
                                } else {
                                    Button("Open") { open(url) }
                                    Button("Quick Look") { quickLook(url) }
                                }
                                Divider()
                                Button("Rename") { startEditing(url) }
                                Button(role: .destructive) { delete(url) } label: { Text("Delete") }
                            }
                            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                                guard isDirectory(url) else { return false }
                                return handleDrop(into: url, providers: providers)
                            }
                        }
                    }
                } else {
                    ScrollView {
                        let items = directoryItems(at: currentURL)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                            ForEach(items, id: \.self) { url in
                                GridTile(url: url,
                                         isDirectory: isDirectory(url),
                                         thumbnail: thumbnail(for: url))
                                .onTapGesture(count: 2) {
                                    if isDirectory(url) { navigateInto(url) } else { open(url) }
                                }
                                .onTapGesture(count: 1) {
                                    if isDirectory(url) { /* expand by navigating on double-click only */ } else { quickLook(url) }
                                }
                                .contextMenu {
                                    if isDirectory(url) {
                                        Button("Open") { navigateInto(url) }
                                        Button("New Folder…") {
                                            newSubfolderName = ""
                                            editingURL = nil
                                            showingNewSubfolderAlert = true
                                        }
                                    } else {
                                        Button("Open") { open(url) }
                                        Button("Quick Look") { quickLook(url) }
                                    }
                                    Divider()
                                    Button("Rename") { startEditing(url) }
                                    Button(role: .destructive) { delete(url) } label: { Text("Delete") }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                            handleDrop(providers: providers)
                        }
                    }
                }
            }
            .background(Color.clear.contextMenu {
                Button("New Folder…") {
                    newSubfolderName = ""
                    showingNewSubfolderAlert = true
                }
            })
        }
        .overlay(alignment: .top) {
            if showToast {
                Text(toastMessage)
                    .padding(8)
                    .background(.ultraThickMaterial)
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .padding(.top, 8)
            }
        }
        .onAppear {
            loadViewMode(for: currentURL)
            refresh()
        }
        .onChange(of: folderURL) {
            // Reset navigation state when the root folder changes
            currentURL = folderURL
            loadViewMode(for: currentURL)
            refresh()
        }
        .onChange(of: currentURL) {
            loadViewMode(for: currentURL)
            refresh()
        }
        .onChange(of: viewMode) {
            persistViewMode(for: currentURL)
        }
        .padding()
        .fileImporter(isPresented: $showingAddFilePicker, allowedContentTypes: [UTType.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let src = urls.first { addFileFromURL(src) }
            case .failure:
                break
            }
        }
        .alert("New Subfolder", isPresented: $showingNewSubfolderAlert, actions: {
            TextField("Folder name", text: $newSubfolderName)
            Button("Create") { createSubfolder(named: newSubfolderName) }
            Button("Cancel", role: .cancel) {}
        })
        .sheet(isPresented: $showingMarkdownEditor) {
            MarkdownEditorSheet(text: $markdownText,
                                isSaving: $isSavingMarkdown,
                                filename: $markdownFilename,
                                showFilenameField: true) { text, filename in
                let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let name = trimmed.lowercased().hasSuffix(".md") ? trimmed : trimmed + ".md"
                let url = currentURL.appendingPathComponent(name)
                do {
                    try text.data(using: .utf8)?.write(to: url, options: .atomic)
                    toastMessage = "Saved \(name)"
                    showToast = true
                } catch {
                    toastMessage = "Failed to save \(name)"
                    showToast = true
                }
                refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showToast = false }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }

    private func breadcrumb(for url: URL) -> String {
        let parts = url.pathComponents.suffix(3) // keep short
        return parts.joined(separator: "/")
    }

    #if os(macOS)
    private func quickLook(_ url: URL) {
        previewURL = url
        QuickLookPanelPresenter.shared.preview(urls: [url])
    }
    #else
    private func quickLook(_ url: URL) {
        previewURL = url
        isShowingPreview = true
    }
    #endif

    private func refresh() {
        tree = buildTree(at: currentURL)
    }

    private func buildTree(at url: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let kids = try? fm.contentsOfDirectory(at: url,
                                                     includingPropertiesForKeys: [.isDirectoryKey],
                                                     options: [.skipsHiddenFiles]) else { return [] }
        let filtered = kids.filter { !$0.lastPathComponent.hasPrefix("_") }
        let sorted = filtered.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
        return sorted.map { child in
            if isDirectory(child) {
                return FileNode(url: child, children: buildTree(at: child))
            } else {
                return FileNode(url: child, children: nil)
            }
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private func open(_ url: URL) {
    #if os(macOS)
        NSWorkspace.shared.open(url)
    #endif
    }

    private func navigateInto(_ url: URL) {
        guard isDirectory(url) else { return }
        currentURL = url
    }

    private func navigateUp() {
        let parent = currentURL.deletingLastPathComponent()
        if parent.path.hasPrefix(folderURL.path) || parent == folderURL { // stay within root
            currentURL = parent
        } else {
            currentURL = folderURL
        }
    }

    private func createSubfolder(named name: String) {
        createSubfolder(at: currentURL, named: name)
    }

    private func createSubfolder(at base: URL, named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newURL = base.appendingPathComponent(trimmed, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
            refresh()
        } catch {
            // Handle error if needed
        }
    }

    private func addFileFromURL(_ src: URL) {
        guard !src.lastPathComponent.hasPrefix("_") else { return }
        let dest = currentURL.appendingPathComponent(src.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            refresh()
        } catch {
            // Handle error if needed
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        var handled = false
        let group = DispatchGroup()
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    addFileFromURL(url)
                    if url.lastPathComponent.hasPrefix("_") { handled = false; return }
                    handled = true
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            refresh()
        }
        return handled
    }

    private func handleDropToSpecificFolder(subfolder: String, providers: [NSItemProvider]) -> Bool {
        let dest = currentURL.appendingPathComponent(subfolder, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        } catch { /* ignore if exists */ }
        var handled = false
        let group = DispatchGroup()
        if let provider = providers.first, provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    let target = dest.appendingPathComponent(url.lastPathComponent)
                    do {
                        try FileManager.default.copyItem(at: url, to: target)
                        handled = true
                    } catch { }
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { refresh() }
        return handled
    }

    private func handleDrop(into destinationDir: URL, providers: [NSItemProvider]) -> Bool {
        do { try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true) } catch {}
        var handled = false
        let group = DispatchGroup()
        if let provider = providers.first, provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    let target = destinationDir.appendingPathComponent(url.lastPathComponent)
                    do {
                        try FileManager.default.copyItem(at: url, to: target)
                        handled = true
                    } catch { }
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { refresh() }
        return handled
    }

    private func startEditing(_ url: URL) {
        editingURL = url
        editingName = url.lastPathComponent
    }

    private func commitEdit() {
        guard let url = editingURL else { return }
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newURL = url.deletingLastPathComponent().appendingPathComponent(trimmed)
        guard newURL != url else {
            editingURL = nil
            return
        }
        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            refresh()
        } catch {
            // Handle error if needed
        }
        editingURL = nil
    }

    private func delete(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            refresh()
        } catch {
            // Handle error if needed
        }
    }
    
    // MARK: - View mode persistence per folder
    private func viewModeKey(for url: URL) -> String {
        // Keyed by full path so each folder can remember its preferred mode
        return "FolderPreviewView.viewMode." + url.path
    }

    private func loadViewMode(for url: URL) {
        let key = viewModeKey(for: url)
        if let raw = UserDefaults.standard.string(forKey: key), let mode = ViewMode(rawValue: raw) {
            viewMode = mode
        }
    }

    private func persistViewMode(for url: URL) {
        let key = viewModeKey(for: url)
        UserDefaults.standard.set(viewMode.rawValue, forKey: key)
    }

    // MARK: - Grid helpers
    private func directoryItems(at url: URL) -> [URL] {
        let fm = FileManager.default
        guard let kids = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        let filtered = kids.filter { !$0.lastPathComponent.hasPrefix("_") }
        return filtered.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["png","jpg","jpeg","gif","heic","tiff","bmp","webp"].contains(ext)
    }

    #if os(macOS)
    private func thumbnail(for url: URL) -> Image? {
        if isDirectory(url) { return Image(systemName: "folder") }
        if let cached = thumbCache[url] {
            return Image(nsImage: cached)
        }
        if isImageFile(url), let nsimg = NSImage(contentsOf: url) {
            // Only cache if not already present to avoid redundant state updates
            if thumbCache[url] == nil {
                DispatchQueue.main.async {
                    thumbCache[url] = nsimg
                }
            }
            return Image(nsImage: nsimg)
        }
        // Request a Quick Look thumbnail asynchronously; return a placeholder for now
        requestQuickLookThumbnail(for: url, size: CGSize(width: 256, height: 256))
        return Image(systemName: "doc")
    }

    private func requestQuickLookThumbnail(for url: URL, size: CGSize) {
        // Avoid issuing duplicate requests for the same URL
        if ThumbTracker.inFlight.contains(url) { return }
        ThumbTracker.inFlight.insert(url)

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let req = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .all)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
            let nsimg: NSImage? = {
                guard let rep else { return nil }
                let cg = rep.cgImage
                return NSImage(cgImage: cg, size: .zero)
            }()
            DispatchQueue.main.async {
                if let nsimg { thumbCache[url] = nsimg }
                ThumbTracker.inFlight.remove(url)
            }
        }
    }
    #else
    private func thumbnail(for url: URL) -> Image? {
        if isDirectory(url) { return Image(systemName: "folder") }
        if isImageFile(url), let data = try? Data(contentsOf: url), let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        }
        return Image(systemName: "doc.text")
    }
    #endif

    private struct GridTile: View {
        let url: URL
        let isDirectory: Bool
        let thumbnail: Image?

        var body: some View {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(width: 120, height: 120)
                    if let thumb = thumbnail {
                        if isDirectory {
                            thumb
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.accentColor)
                                .frame(width: 36, height: 36)
                        } else {
                            thumb
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .padding(10)
                        }
                    }
                }
                Text(url.lastPathComponent)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 120)
        }
    }
}

#if os(macOS)
final class QuickLookPanelPresenter: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookPanelPresenter()
    private var items: [URL] = []

    func preview(urls: [URL]) {
        items = urls
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { items.count }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem {
        items[index] as QLPreviewItem
    }
}
#endif

// MARK: - Reusable Markdown Editor Sheet
struct MarkdownEditorSheet: View {
    @Binding var text: String
    @Binding var isSaving: Bool
    @Binding var filename: String
    var showFilenameField: Bool = true
    var onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                if showFilenameField {
                    TextField("Filename.md", text: $filename)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                } else {
                    Text(filename).font(.headline)
                }
                Spacer()
                Button("Save") {
                    onSave(text, filename)
                    dismiss()
                }.disabled(isSaving)
                Button("Close") { dismiss() }
            }
            .padding(.bottom, 4)

            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
        .padding()
    }
}

