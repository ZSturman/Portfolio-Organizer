//
//  StepB_GeneralInfoView.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation
import SwiftUI

struct StepB_GeneralInfoView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var wiz: WizardCoordinator
    let config: Config
    let projectDir: URL

    @State private var titleDraft: String = ""
    @State private var subtitleDraft: String = ""
    @State private var summaryDraft: String = ""
    @State private var newTagText: String = ""

    // overview.md editing
    @State private var showOverviewEditor: Bool = false
    @State private var overviewText: String = ""
    @State private var overviewExists: Bool = false
    @State private var isSavingOverview: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("Title")
                        TextField("", text: $titleDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 420)
                            .onChange(of: titleDraft) { _, newValue in
                                wiz.project.title = newValue
                            }
                    }
                    GridRow {
                        Text("Subtitle")
                        TextField("", text: $subtitleDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 420)
                            .onChange(of: subtitleDraft) { _, newValue in
                                wiz.project.subtitle = newValue
                            }
                    }

                    GridRow {
                        Text("Summary")
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Spacer()
                                if overviewExists {
                                    Button {
                                        openOverview()
                                    } label: {
                                        Label("View overview", systemImage: "doc.text.magnifyingglass")
                                    }
                                } else {
                                    Button {
                                        createOverview()
                                    } label: {
                                        Label("Create overview", systemImage: "doc.badge.plus")
                                    }
                                }
                            }
                            TextEditor(text: $summaryDraft)
                                .onChange(of: summaryDraft) { _, newValue in
                                    wiz.project.summary = newValue
                                }
                                .frame(minHeight: 100, maxHeight: 160)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                                .accessibilityLabel("Project summary")
                                .font(.body)
                        }
                        .frame(maxWidth: 600)
                    }

                    GridRow {
                        Text("Visibility")
                        Picker("", selection: Binding(get: { wiz.project.visibility }, set: { wiz.project.visibility = $0 })) {
                            Text("Public").tag("public")
                            Text("Private").tag("private")
                        }
                        .pickerStyle(.radioGroup)
                    }
                    if wiz.project.visibility.lowercased() == "public" && summaryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            Text("A brief summary (2–3 sentences) is required for Public projects before saving.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    GridRow {
                        Text("Status")
                        Picker("", selection: Binding(get: { wiz.project.status }, set: { wiz.updateStatus($0) })) {
                            ForEach(MainStatus.allCases, id: \.self) { s in
                                Text(s.rawValue.replacingOccurrences(of: "_", with: " ").capitalized).tag(s)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                    GridRow {
                        Text("Tags")
                        VStack(alignment: .leading, spacing: 8) {
                            // Current tags chips
                            WrapHStack(spacing: 6) {
                                ForEach(wiz.project.tags, id: \.self) { t in
                                    HStack(spacing: 4) {
                                        Text(t)
                                        Button(role: .destructive) { wiz.project.tags.removeAll { $0 == t } } label: { Image(systemName: "xmark.circle.fill") }
                                            .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            // Add tag field with suggestions
                            HStack {
                                TextField("Add tag", text: $newTagText, onCommit: { addTag() })
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 240)
                                Button("Add") { addTag() }.disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            if app.isLoadingTags {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Loading tags...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !app.allTags.isEmpty {
                                Text("Suggestions").font(.caption).foregroundStyle(.secondary)
                                WrapHStack(spacing: 6) {
                                    ForEach(app.allTags.sorted(), id: \.self) { s in
                                        Button(action: { if !wiz.project.tags.contains(s) { wiz.project.tags.append(s) } }) {
                                            Text(s)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.secondary.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .onAppear {
            titleDraft = wiz.project.title
            subtitleDraft = wiz.project.subtitle
            summaryDraft = wiz.project.summary
            refreshOverviewState()
            loadOverviewIfNeeded()
            app.refreshAllTagsIfNeeded(for: projectDir.deletingLastPathComponent())
        }
        .onChange(of: projectDir) {
            // When the selected project directory changes, reseed local UI state
            titleDraft = wiz.project.title
            subtitleDraft = wiz.project.subtitle
            summaryDraft = wiz.project.summary
            refreshOverviewState()
            loadOverviewIfNeeded()
            app.refreshAllTagsIfNeeded(for: projectDir.deletingLastPathComponent())
        }
        .onChange(of: wiz.project) { _, _ in
            // Only refresh overview state and load overview, but do NOT reset drafts during editing
            refreshOverviewState()
            loadOverviewIfNeeded()
        }
        .sheet(isPresented: $showOverviewEditor) {
            MarkdownEditorSheet(text: $overviewText,
                                isSaving: $isSavingOverview,
                                filename: .constant("overview.md"),
                                showFilenameField: false) { text, _ in
                saveOverview(text)
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }

    // MARK: - Overview helpers
    private var overviewURL: URL { projectDir.appendingPathComponent("overview.md") }

    private func refreshOverviewState() {
        overviewExists = FileManager.default.fileExists(atPath: overviewURL.path)
    }

    private func loadOverviewIfNeeded() {
        guard overviewExists else { return }
        if let data = try? Data(contentsOf: overviewURL), let text = String(data: data, encoding: .utf8) {
            overviewText = text
        } else {
            overviewText = ""
        }
    }

    private func openOverview() {
        loadOverviewIfNeeded()
        showOverviewEditor = true
    }

    private func createOverview() {
        let accessed = projectDir.startAccessingSecurityScopedResource()
        defer { if accessed { projectDir.stopAccessingSecurityScopedResource() } }
        do {
            if !FileManager.default.fileExists(atPath: overviewURL.path) {
                try "".data(using: .utf8)?.write(to: overviewURL, options: .atomic)
            }
            refreshOverviewState()
            openOverview()
        } catch {
            #if DEBUG
            print("Failed to create overview.md at \(overviewURL): \(error)")
            #endif
        }
    }

    private func saveOverview(_ text: String) {
        isSavingOverview = true
        let url = overviewURL
        let accessed = projectDir.startAccessingSecurityScopedResource()

        defer {
            if accessed { projectDir.stopAccessingSecurityScopedResource() }
            isSavingOverview = false
        }

        do {
            if !FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path) {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            }
            if let data = text.data(using: .utf8) {
                try data.write(to: url, options: .atomic)
            }
            overviewText = text
            refreshOverviewState()
        } catch {
            #if DEBUG
            print("Failed to save overview.md at \(url): \(error)")
            #endif
        }
    }

    private func limitedToThreeSentences(_ text: String) -> String {
        let separators = CharacterSet(charactersIn: ".!?")
        var sentences: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if String(ch).rangeOfCharacter(from: separators) != nil {
                let s = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { sentences.append(s) }
                current = ""
                if sentences.count >= 3 { break }
            }
        }
        if sentences.count < 3 {
            let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { sentences.append(tail) }
        }
        return sentences.prefix(3).joined(separator: " ")
    }

    private func addTag() {
        let t = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if !wiz.project.tags.contains(t) { wiz.project.tags.append(t) }
        app.registerTag(t)
        newTagText = ""
    }

    private struct WrapHStack<Content: View>: View {
        let spacing: CGFloat
        let content: () -> Content

        init(spacing: CGFloat = 6, @ViewBuilder content: @escaping () -> Content) {
            self.spacing = spacing
            self.content = content
        }

        var body: some View {
            FlowLayout(spacing: spacing) { content() }
        }
    }
}

struct MultiPickerInline: View {
    let title: String
    let all: [String]
    @Binding var selection: Set<String>
    private let columns: [GridItem] = [GridItem(.flexible(minimum: 120)), GridItem(.flexible(minimum: 120))]
    var body: some View {
        GroupBox(title) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(all, id: \.self) { item in
                    Toggle(item, isOn: Binding(
                        get: { selection.contains(item) },
                        set: { newValue in if newValue { selection.insert(item) } else { selection.remove(item) } }
                    ))
                    .toggleStyle(.checkbox)
                }
            }
            .padding(6)
        }
    }
}

struct FlowLayout: View {
    let spacing: CGFloat
    let content: () -> AnyView
    init<Content: View>(spacing: CGFloat = 6, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = { AnyView(content()) }
    }
    var body: some View {
        _FlowLayout(spacing: spacing) { content() }
    }
}

private struct _FlowLayout: Layout {
    let spacing: CGFloat
    init(spacing: CGFloat = 6) { self.spacing = spacing }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Determine an effective max width that is always finite
        let proposedWidth = proposal.width
        let hasFiniteProposedWidth = proposedWidth.map { $0.isFinite } ?? false
        let maxLineWidth = hasFiniteProposedWidth ? proposedWidth! : CGFloat.greatestFiniteMagnitude

        var currentLineWidth: CGFloat = 0
        var usedWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            // If this item would overflow the line, wrap
            if currentLineWidth > 0 && currentLineWidth + sz.width > maxLineWidth {
                usedWidth = max(usedWidth, currentLineWidth - spacing)
                totalHeight += rowHeight + spacing
                currentLineWidth = 0
                rowHeight = 0
            }
            currentLineWidth += sz.width + spacing
            rowHeight = max(rowHeight, sz.height)
        }

        // Finalize the last line
        if currentLineWidth > 0 {
            usedWidth = max(usedWidth, currentLineWidth - spacing)
            totalHeight += rowHeight
        } else if totalHeight == 0 {
            // No subviews case
            usedWidth = 0
            totalHeight = 0
        }

        // Return a finite width. If proposal width was finite, honor it; otherwise use the used width.
        let returnWidth: CGFloat
        if let w = proposal.width, w.isFinite {
            returnWidth = w
        } else {
            returnWidth = usedWidth
        }

        return CGSize(width: max(0, returnWidth), height: max(0, totalHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Use a finite line width for placement
        let availableWidth: CGFloat
        if bounds.width.isFinite && bounds.width > 0 {
            availableWidth = bounds.width
        } else if let w = proposal.width, w.isFinite, w > 0 {
            availableWidth = w
        } else {
            // Fallback to a large finite width if nothing else is available
            availableWidth = 10_000
        }

        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if (x - bounds.minX) > 0 && (x - bounds.minX) + sz.width > availableWidth {
                // Wrap to next line
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: sz.width, height: sz.height))
            x += sz.width + spacing
            rowHeight = max(rowHeight, sz.height)
        }
    }
}

