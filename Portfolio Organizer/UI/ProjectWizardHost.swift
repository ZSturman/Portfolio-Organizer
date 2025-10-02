//
//  ProjectWizardHost.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation
import SwiftUI
import Combine

struct ProjectWizardHost: View {
    @EnvironmentObject var app: AppState
    @State private var wiz: WizardCoordinator?
    @State private var showUnsavedAlert = false
    @State private var pendingSelection: URL? = nil
    @State private var lastSelectedDir: URL?

    @State private var showSummaryRequiredAlert = false
    @State private var summaryValidationMessage: String = ""

    @State private var showSaveToast = false
    @State private var saveToastMessage = ""

    @State private var showDirtyList: Bool = false
    @State private var showFolderPreview: Bool = true

    var body: some View {
        if let dir = app.selectedProjectDir {
            VStack {
                HStack {
                    Text(folderHeaderTitle(for: dir))
                    Spacer()
                    if hasProjectJSON(in: dir) {
                        Button("Save") { save() }
                        if app.dirtyProjects.count > 1 {
                            HStack(spacing: 8) {
                                Button("Save All Changes") { saveAll() }
                                Menu("Dirty Projects") {
                                    let items = Array(app.dirtyProjects).sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                                    if items.isEmpty {
                                        Text("None")
                                    } else {
                                        ForEach(items, id: \.self) { u in
                                            Text(u.lastPathComponent)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Divider()
                if hasProjectJSON(in: dir) {
                    if showFolderPreview {
                        VSplitView {
                            wizardPane(dir)
                                .frame(minHeight: 280)
                                .layoutPriority(1)

                            ZStack(alignment: .topTrailing) {
                                FolderPreviewView(folderURL: dir)
                                    .frame(minHeight: 120)
                                    .layoutPriority(1)
                            }
                            .overlay(alignment: .topTrailing) {
                                Button(action: { showFolderPreview = false }) {
                                    Label("Hide Directory Tree", systemImage: "eye.slash")
                                }
                                .buttonStyle(.bordered)
                                .padding(8)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ZStack(alignment: .bottomTrailing) {
                            wizardPane(dir)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Button(action: { showFolderPreview = true }) {
                                Label("Show Directory Tree", systemImage: "eye")
                            }
                            .buttonStyle(.bordered)
                            .padding(8)
                        }
                    }
                } else {
                    FolderPreviewView(folderURL: dir)
                }
            }
            .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
                Button("Save") {
                    performSaveAndNavigateIfNeeded()
                }
                Button("Discard") {
                    wiz = WizardCoordinator(project: app.project) { app.saveProject() }
                    proceedPendingNavigation()
                }
                Button("Cancel", role: .cancel) {
                    pendingSelection = nil
                }
            } message: {
                Text("You have unsaved changes. What would you like to do?")
            }
            .alert("Summary Required", isPresented: $showSummaryRequiredAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(summaryValidationMessage)
            }
            .onAppear {
                if let dir = app.selectedProjectDir {
                    if wiz == nil || lastSelectedDir != dir {
                        if hasProjectJSON(in: dir) {
                            wiz = WizardCoordinator(project: app.project) { app.saveProject() }
                        } else {
                            wiz = nil
                        }
                        lastSelectedDir = dir
                        app.isCurrentProjectDirty = wiz?.isDirty ?? false
                    }
                    app.refreshAllTagsIfNeeded(for: dir.deletingLastPathComponent())
                }
            }
            .onChange(of: app.selectedProjectDir) { _, newDir in
                guard let newDir = newDir else {
                    wiz = nil
                    lastSelectedDir = nil
                    return
                }
                if let oldDir = lastSelectedDir, oldDir != newDir {
                    if wiz?.isDirty == true {
                        pendingSelection = newDir
                        showUnsavedAlert = true
                        // revert selection to old
                        app.selectedProjectDir = oldDir
                        return
                    }
                }
                // proceed normally if no dirty or no change
                if hasProjectJSON(in: newDir) {
                    wiz = WizardCoordinator(project: app.project) { app.saveProject() }
                } else {
                    wiz = nil
                }
                app.isCurrentProjectDirty = wiz?.isDirty ?? false
                lastSelectedDir = newDir

                app.refreshAllTagsIfNeeded(for: newDir.deletingLastPathComponent())
            }
            .onReceive(app.$project) { _ in
                if let curDir = app.selectedProjectDir, hasProjectJSON(in: curDir) {
                    wiz = WizardCoordinator(project: app.project) { app.saveProject() }
                } else {
                    wiz = nil
                }
                app.isCurrentProjectDirty = wiz?.isDirty ?? false

                if let dir = app.selectedProjectDir {
                    app.refreshAllTagsIfNeeded(for: dir.deletingLastPathComponent())
                }
            }
            .onChange(of: wiz?.isDirty ?? false) { _, newDirty in
                guard let dir = app.selectedProjectDir, let w = wiz else { return }
                if newDirty {
                    app.editedProjects[dir] = w.project
                    app.dirtyProjects.insert(dir)
                } else {
                    app.editedProjects.removeValue(forKey: dir)
                    app.dirtyProjects.remove(dir)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if showSaveToast {
                    Text(saveToastMessage)
                        .padding(8)
                        .background(.ultraThickMaterial)
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding(.top, 8)
                }
            }
            .onChange(of: wiz?.isDirty ?? false) { _, newValue in
                app.isCurrentProjectDirty = newValue
            }
        } else {
            Text("Select a project or folder")
        }
    }

    @ViewBuilder
    private func wizardPane(_ dir: URL) -> some View {
        if let w = wiz {
            // Deduplicate steps while preserving order
            let uniqueSteps: [StepID] = {
                var seen = Set<StepID>()
                return w.steps.filter { $0 != .e_specific && seen.insert($0).inserted }
            }()

            VStack(spacing: 8) {
                TabView(selection: Binding(get: {
                    if w.index >= 0 && w.index < w.steps.count {
                        return w.steps[w.index]
                    }
                    return uniqueSteps.first ?? w.steps.first!
                }, set: { newStep in
                    if let i = w.steps.firstIndex(of: newStep) {
                        w.index = i
                    }
                })) {
                    ForEach(uniqueSteps, id: \.self) { step in
                        stepView(step, dir, w, app.config)
                            .tabItem { Label(step.title, systemImage: step.systemImage) }
                            .tag(step)
                    }
                }
                .frame(minHeight: 280)
            }
        } else {
            EmptyView()
        }
    }

    func save() {
        guard let wizard = wiz, let dir = app.selectedProjectDir else { return }

        // Enforce summary when public
        var projectToSave = wizard.committedProject()
        if projectToSave.visibility.lowercased() == "public" {
            let trimmed = projectToSave.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                summaryValidationMessage = "Public projects require a brief summary (2–3 sentences) before saving. Please add a summary in General Info."
                showSummaryRequiredAlert = true
                return
            }
            // Cap to three sentences
            projectToSave.summary = limitedToThreeSentences(trimmed)
        }

        app.project = projectToSave

        // Use security-scoped access when writing outside the sandbox
        let accessed = dir.startAccessingSecurityScopedResource()
        defer { if accessed { dir.stopAccessingSecurityScopedResource() } }

        var saveError: Error? = nil
        do {
            try ProjectStore.save(projectToSave, to: dir)
        } catch {
            #if DEBUG
            print("Failed to save _project.json at \(dir): \(error)")
            #endif
            saveError = error
        }
        saveToastMessage = saveError == nil ? "Saved" : "Save failed"
        showSaveToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSaveToast = false }

        // Re-seed the wizard with the saved project so it is no longer dirty and clear dirty indicators
        self.wiz = WizardCoordinator(project: projectToSave) { app.saveProject() }
        app.isCurrentProjectDirty = self.wiz?.isDirty ?? false
        app.editedProjects.removeValue(forKey: dir)
        app.dirtyProjects.remove(dir)
    }

    private func performSaveAndNavigateIfNeeded() {
        save()
        proceedPendingNavigation()
    }

    private func proceedPendingNavigation() {
        if let pending = pendingSelection {
            app.selectedProjectDir = pending
            lastSelectedDir = pending
            pendingSelection = nil
        }
    }

    func hasProjectJSON(in dir: URL) -> Bool {
        let file = dir.appendingPathComponent("_project.json")
        return FileManager.default.fileExists(atPath: file.path)
    }

    func folderHeaderTitle(for dir: URL) -> String {
        if hasProjectJSON(in: dir) {
            return "Project: \(app.project.domain)/\(app.project.title)"
        } else {
            return "Folder: \(dir.lastPathComponent)"
        }
    }

    @ViewBuilder
    func stepView(_ s: StepID, _ dir: URL, _ wiz: WizardCoordinator, _ cfg: Config) -> some View {
        switch s {
        case .b_general:   StepB_GeneralInfoView(wiz: wiz, config: cfg, projectDir: dir)
        case .c_classification: StepC_ClassificationView(wiz: wiz, config: cfg)
        case .d_thumb:     StepD_ThumbnailView(wiz: wiz, projectDir: dir)
        case .e_specific:  StepE_SpecificInfoView(wiz: wiz, config: cfg)
        case .g_resources: StepG_ResourcesView(wiz: wiz)
        case .z_review:    StepZ_ReviewView(wiz: wiz)
        }
    }

    private func limitedToThreeSentences(_ text: String) -> String {
        // A simple sentence splitter based on punctuation. Keeps up to three sentences.
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
    
    func saveAll() {
        // Save current wizard first to ensure UI state is captured
        if let w = wiz { app.project = w.committedProject() }
        app.saveAllEditedProjects()
        // Refresh current wizard to clear dirty state
        if let dir = app.selectedProjectDir {
            if hasProjectJSON(in: dir) {
                wiz = WizardCoordinator(project: app.project) { app.saveProject() }
            } else {
                wiz = nil
            }
            app.isCurrentProjectDirty = wiz?.isDirty ?? false
        }
    }
}
