//
//  StepD_ThumbnailView.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AppKit
import AVFoundation

struct StepD_ThumbnailView: View {
    @ObservedObject var wiz: WizardCoordinator
    let projectDir: URL

    // Dedicated images subfolder name
    private let imagesDirName = "images"
    private var imagesDirURL: URL { projectDir.appendingPathComponent(imagesDirName, isDirectory: true) }
    // Originals subfolder name (inside images)
    private let originalsDirName = "originals"
    private var originalsDirURL: URL { imagesDirURL.appendingPathComponent(originalsDirName, isDirectory: true) }

    // Preview and UI state
    @State private var previews: [ImageKind: NSImage] = [:]
    @State private var cropping: CroppingState?
    @State private var hoverKind: ImageKind? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Responsive wrap layout of drop targets
                WrapLayout(spacing: 12) {
                    ForEach(ImageKind.allCases, id: \.self) { kind in
                        dropTile(for: kind)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 500, minHeight: 300)
        .padding()
        .onAppear {
            // Load any existing images and reconcile json on first show
            primePreviewsAndReconcile()
        }
        .onChange(of: projectDir) {
            previews.removeAll()
            cropping = nil
            hoverKind = nil
            primePreviewsAndReconcile()
        }
        .sheet(item: $cropping) { state in
            CropperSheet(state: state) { cropped in
                // Save the cropped image to the canonical filename and update json
                save(image: cropped, for: state.kind)
            }
        }
    }

    // MARK: - Drop tile

    @ViewBuilder
    private func dropTile(for kind: ImageKind) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Color.clear
                    .frame(width: kind.displaySize.width, height: kind.displaySize.height)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.secondary, style: StrokeStyle(lineWidth: 1, dash: [6,6]))
                    .frame(width: kind.displaySize.width,
                           height: kind.displaySize.height)
                    .overlay {
                        Group {
                            if let image = previews[kind] {
                                if kind.isCircularMask {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                                } else {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .clipped()
                                }
                            } else if let referenced = jsonImageName(for: kind) {
                                // JSON references an image, but preview may be missing; check file existence
                                let fileURL = imagesDirURL.appendingPathComponent(referenced)
                                if FileManager.default.fileExists(atPath: fileURL.path), let img = NSImage(contentsOf: fileURL) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .clipped()
                                        .onAppear { previews[kind] = img }
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle")
                                        Text("Not Found").font(.caption)
                                    }
                                    .foregroundStyle(.orange)
                                }
                            } else {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo")
                                    Text("Drop \(kind.label)")
                                }
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if hasImage(for: kind) {
                            if let img = loadOriginalOrProcessed(for: kind) {
                                cropping = CroppingState(kind: kind, image: img)
                            }
                        } else {
                            pickImage(for: kind)
                        }
                    }
                    .onDrop(of: [.image, UTType.fileURL], isTargeted: nil) { providers in
                        handleDropEnhanced(providers, for: kind)
                    }

                VStack {
                    HStack(spacing: 8) {
                        if hasImage(for: kind) {
                            Button(role: .destructive) {
                                deleteImage(for: kind)
                            } label: { Image(systemName: "trash") }
                            .help("Delete")

                            Button {
                                pickImage(for: kind)
                            } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                            .help("Replace")

                            if let img = previews[kind] ?? loadOriginalOrProcessed(for: kind) {
                                Button {
                                    cropping = CroppingState(kind: kind, image: img)
                                } label: { Image(systemName: "crop") }
                                .help("Resize")
                            }
                        } else {
                            Button {
                                pickImage(for: kind)
                            } label: { Image(systemName: "square.and.arrow.down.on.square") }
                            .help("Import")
                        }
                    }
                    .buttonStyle(.borderless)
                    .padding(6)
                    .background(.thinMaterial)
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    Spacer()
                }
                .frame(width: kind.displaySize.width, height: kind.displaySize.height)
                .opacity(hoverKind == kind ? 1 : 0)
                .animation(.easeInOut(duration: 0.12), value: hoverKind)
                .allowsHitTesting(hoverKind == kind)
                .padding(6)
                .zIndex(1)
            }
            .onHover { inside in
                hoverKind = inside ? kind : (hoverKind == kind ? nil : hoverKind)
            }

            Text(kind.label).font(.caption)
        }
    }

    // MARK: - Pick / Drop

    private func pickImage(for kind: ImageKind) {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.image]
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        if p.runModal() == .OK, let url = p.url {
            importImage(from: url, for: kind)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], for kind: ImageKind) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else {
            return false
        }
        var handled = false
        let _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data, let img = NSImage(data: data) else { return }
            // Write temp and funnel through import path to honor naming rules
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
            do {
                try img.pngWrite(to: tmp)
                DispatchQueue.main.async {
                    importImage(from: tmp, for: kind)
                }
                handled = true
            } catch {
                handled = false
            }
        }
        return handled
    }

    private func importImage(from url: URL, for kind: ImageKind) {
        // Ensure images and originals directories exist
        let dir = imagesDirURL
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: originalsDirURL, withIntermediateDirectories: true)
        let processedDest = dir.appendingPathComponent(kind.canonicalFileName, isDirectory: false)
        let originalDest = originalsDirURL.appendingPathComponent(kind.originalFileName, isDirectory: false)
        do {
            guard let src = NSImage(contentsOf: url) else { return }
            try? FileManager.default.removeItem(at: originalDest)
            try src.pngWrite(to: originalDest)
            let processed = src.renderPanZoomCrop(outputSize: kind.outputPixelSize, aspect: kind.targetAspect, scale: 1.0, offset: .zero, circularMask: kind.isCircularMask)
            try? FileManager.default.removeItem(at: processedDest)
            try processed.pngWrite(to: processedDest)
            previews[kind] = processed
            applyProjectField(for: kind, fileName: kind.canonicalFileName)
            reconcileImagesJSON(set: [kind.jsonKey: kind.canonicalFileName])
        } catch {
            // Handle write errors gracefully (no-op, keep UI responsive)
        }
    }

    private func save(image: NSImage, for kind: ImageKind) {
        let dir = imagesDirURL
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(kind.canonicalFileName, isDirectory: false)
        do {
            try image.pngWrite(to: dest)
            previews[kind] = image
            applyProjectField(for: kind, fileName: kind.canonicalFileName)
            reconcileImagesJSON(set: [kind.jsonKey: kind.canonicalFileName])
        } catch {
            // ignore
        }
    }

    private func deleteImage(for kind: ImageKind) {
        let dest = imagesDirURL.appendingPathComponent(kind.canonicalFileName, isDirectory: false)
        try? FileManager.default.removeItem(at: dest)
        previews.removeValue(forKey: kind)
        // Remove from json if present
        reconcileImagesJSON(removeKeys: [kind.jsonKey])
        // Clear in-memory known field when applicable
        if case .thumbnail = kind {
            wiz.project.thumbnail = nil
        }
    }

    // MARK: - Existence helpers
    private func jsonImageName(for kind: ImageKind) -> String? {
        let jsonURL = projectDir.appendingPathComponent("_project.json")
        guard let data = try? Data(contentsOf: jsonURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let images = obj["images"] as? [String: Any] else { return nil }
        return images[kind.jsonKey] as? String
    }

    private func hasImage(for kind: ImageKind) -> Bool {
        if previews[kind] != nil { return true }
        if let name = jsonImageName(for: kind) {
            let url = imagesDirURL.appendingPathComponent(name)
            return FileManager.default.fileExists(atPath: url.path)
        }
        return false
    }

    private func loadImageIfExists(for kind: ImageKind) -> NSImage? {
        if let img = previews[kind] { return img }
        if let name = jsonImageName(for: kind) {
            let url = imagesDirURL.appendingPathComponent(name)
            if let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }

    private func loadOriginalOrProcessed(for kind: ImageKind) -> NSImage? {
        // Prefer original if available
        let originalURL = originalsDirURL.appendingPathComponent(kind.originalFileName)
        if FileManager.default.fileExists(atPath: originalURL.path), let img = NSImage(contentsOf: originalURL) { return img }
        return loadImageIfExists(for: kind)
    }

    // MARK: - Enhanced drop handler (accepts file URLs and images)
    private func handleDropEnhanced(_ providers: [NSItemProvider], for kind: ImageKind) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            var handled = false
            let _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data, let img = NSImage(data: data) else { return }
                let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
                do {
                    try img.pngWrite(to: tmp)
                    DispatchQueue.main.async { importImage(from: tmp, for: kind) }
                    handled = true
                } catch { handled = false }
            }
            return handled
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            var handled = false
            let _ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let s = String(data: data, encoding: .utf8), let u = URL(string: s) {
                    DispatchQueue.main.async { importImage(from: u, for: kind) }
                    handled = true
                } else if let u = item as? URL {
                    DispatchQueue.main.async { importImage(from: u, for: kind) }
                    handled = true
                }
            }
            return handled
        }
        return false
    }

    // MARK: - Reconcile

    private func primePreviewsAndReconcile() {
        for k in ImageKind.allCases {
            let url = imagesDirURL.appendingPathComponent(k.canonicalFileName, isDirectory: false)
            if FileManager.default.fileExists(atPath: url.path),
               let img = NSImage(contentsOf: url) {
                previews[k] = img
                // If file exists but project/json missing, update both
                var needJSON = false
                if case .thumbnail = k {
                    if wiz.project.thumbnail != k.canonicalFileName {
                        wiz.project.thumbnail = k.canonicalFileName
                        needJSON = true
                    }
                } else {
                    needJSON = true // we cannot rely on Project model to hold these fields
                }
                if needJSON {
                    reconcileImagesJSON(set: [k.jsonKey: k.canonicalFileName])
                }
            }
        }
    }

    private func applyProjectField(for kind: ImageKind, fileName: String) {
        // Only known typed field we can set is `thumbnail`
        if case .thumbnail = kind {
            wiz.project.thumbnail = fileName
        }
    }

    private func resolvedFileName(for kind: ImageKind) -> String? {
        let path = imagesDirURL.appendingPathComponent(kind.canonicalFileName).path
        switch kind {
        case .thumbnail:
            // Prefer the project model if set, otherwise check file existence in images folder
            if let tn = wiz.project.thumbnail { return tn }
            return FileManager.default.fileExists(atPath: path) ? kind.canonicalFileName : nil
        default:
            return FileManager.default.fileExists(atPath: path) ? kind.canonicalFileName : nil
        }
    }

    // MARK: - JSON reconciliation

    // Maintain nested `images` object in _project.json
    //
    // Save All and global state management is handled by the wizard container.
    // This view refreshes previews on projectDir changes.
    private func reconcileImagesJSON(set kv: [String: Any] = [:], removeKeys: [String] = []) {
        let jsonURL = projectDir.appendingPathComponent("_project.json")
        var obj: [String: Any] = {
            guard let data = try? Data(contentsOf: jsonURL),
                  let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
            return o
        }()

        // Extract existing images object (if any)
        var images = (obj["images"] as? [String: Any]) ?? [:]

        // Always ensure the directory name is set
        images["directory"] = imagesDirName

        // Apply removals then sets within images object
        for key in removeKeys { images.removeValue(forKey: key) }
        for (k, v) in kv { images[k] = v }

        // Write back
        obj["images"] = images

        // Keep updatedAt in sync
        obj["updatedAt"] = ISO8601DateFormatter().string(from: Date())

        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: jsonURL)
        }

        // Also keep the legacy top-level `thumbnail` in sync when applicable
        if let tn = images[ImageKind.thumbnail.jsonKey] as? String {
            wiz.project.thumbnail = tn
        }

        // Ask the wizard to persist by invoking its saveAction
        wiz.saveAction()
    }

    // Backward-compat wrapper (no-op): kept to avoid compile errors if referenced
    private func reconcileJSON(set kv: [String: Any] = [:], removeKeys: [String] = []) {
        reconcileImagesJSON(set: kv, removeKeys: removeKeys)
    }
}

// MARK: - Types

private enum ImageKind: CaseIterable, Hashable {
    case thumbnail
    case banner
    case iconSquare
    case iconCircle
    case posterLandscape
    case posterPortrait

    var label: String {
        switch self {
        case .thumbnail: return "Thumbnail"
        case .banner: return "Banner"
        case .iconSquare: return "Icon (Square)"
        case .iconCircle: return "Icon (Circle)"
        case .posterLandscape: return "Poster (Landscape)"
        case .posterPortrait: return "Poster (Portrait)"
        }
    }

    var canonicalFileName: String {
        switch self {
        case .thumbnail: return "thumbnail.png"
        case .banner: return "banner.png"
        case .iconSquare: return "icon-square.png"
        case .iconCircle: return "icon-circle.png"
        case .posterLandscape: return "poster-landscape.png"
        case .posterPortrait: return "poster-portrait.png"
        }
    }

    var originalFileName: String {
        switch self {
        case .thumbnail: return "thumbnail-original.png"
        case .banner: return "banner-original.png"
        case .iconSquare: return "icon-square-original.png"
        case .iconCircle: return "icon-circle-original.png"
        case .posterLandscape: return "poster-landscape-original.png"
        case .posterPortrait: return "poster-portrait-original.png"
        }
    }

    var jsonKey: String {
        switch self {
        case .thumbnail: return "thumbnail"
        case .banner: return "banner"
        case .iconSquare: return "iconSquare"
        case .iconCircle: return "iconCircle"
        case .posterLandscape: return "posterLandscape"
        case .posterPortrait: return "posterPortrait"
        }
    }

    // On-screen preview size
    var displaySize: CGSize {
        switch self {
        case .thumbnail: return CGSize(width: 160, height: 160)
        case .banner: return CGSize(width: 320, height: 100)
        case .iconSquare: return CGSize(width: 120, height: 120)
        case .iconCircle: return CGSize(width: 120, height: 120)
        case .posterLandscape: return CGSize(width: 240, height: 135) // 16:9
        case .posterPortrait: return CGSize(width: 135, height: 240) // 9:16
        }
    }

    // Target aspect ratio (width:height)
    var targetAspect: CGSize {
        switch self {
        case .thumbnail: return CGSize(width: 1, height: 1) // square
        case .banner: return CGSize(width: 32, height: 10) // 3.2:1
        case .iconSquare: return CGSize(width: 1, height: 1)
        case .iconCircle: return CGSize(width: 1, height: 1)
        case .posterLandscape: return CGSize(width: 16, height: 9)
        case .posterPortrait: return CGSize(width: 9, height: 16)
        }
    }

    // Suggested output pixel size
    var outputPixelSize: CGSize {
        switch self {
        case .thumbnail: return CGSize(width: 1200, height: 1200)
        case .banner: return CGSize(width: 1600, height: 500)
        case .iconSquare: return CGSize(width: 1024, height: 1024)
        case .iconCircle: return CGSize(width: 1024, height: 1024)
        case .posterLandscape: return CGSize(width: 1600, height: 900)
        case .posterPortrait: return CGSize(width: 900, height: 1600)
        }
    }

    var isCircularMask: Bool {
        switch self {
        case .iconCircle: return true
        default: return false
        }
    }
}

// MARK: - Responsive Wrap Layout

/// A simple wrapping layout that places subviews left-to-right and wraps to new lines as space runs out.
/// Keeps each subview's intrinsic size, which fits this UI since each tile defines its own preview size.
private struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                // wrap
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + (x > 0 ? spacing : 0)
        }
        y += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                // wrap
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            let origin = CGPoint(x: bounds.minX + x, y: bounds.minY + y)
            subview.place(at: origin, proposal: ProposedViewSize(width: size.width, height: size.height))

            rowHeight = max(rowHeight, size.height)
            x += size.width + (x > 0 ? spacing : 0)
        }
    }
}

// MARK: - Cropper

private struct CroppingState: Identifiable {
    let id = UUID()
    let kind: ImageKind
    let image: NSImage
}

private struct CropperSheet: View {
    let state: CroppingState
    var onDone: (NSImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        VStack(spacing: 8) {
            Text("Position & Zoom \(state.kind.label)").font(.headline)
            Text("Drag to reposition. Use trackpad pinch or the controls below to zoom.").font(.caption).foregroundStyle(.secondary)
            PanZoomCropperView(image: state.image, aspect: state.kind.targetAspect, scale: $scale, offset: $offset)
                .frame(minWidth: 420, minHeight: 320)
            HStack(spacing: 12) {
                Button { scale = max(scale * 0.8, 0.1) } label: { Image(systemName: "minus.magnifyingglass") }
                Slider(value: $scale, in: 0.5...8.0) { Text("Zoom") }
                    .frame(minWidth: 200)
                Button { scale = min(scale * 1.25, 8.0) } label: { Image(systemName: "plus.magnifyingglass") }
                Spacer()
                Button("Reset") { scale = 1.0; offset = .zero }
            }
            .padding(.horizontal, 4)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Done") {
                    let out = state.image.renderPanZoomCrop(outputSize: state.kind.outputPixelSize, aspect: state.kind.targetAspect, scale: scale, offset: offset, circularMask: state.kind.isCircularMask)
                    onDone(out)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

// Fixed-aspect pan/zoom cropper
private struct PanZoomCropperView: View {
    let image: NSImage
    let aspect: CGSize // width:height
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    @State private var currentDrag: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let containerSize = sizeFittingAspect(in: geo.size, aspect: aspect)
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                ZStack {
                    Color.black.opacity(0.06)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: containerSize.width, height: containerSize.height)
                        .scaleEffect(scale * currentScale, anchor: .center)
                        .offset(x: offset.width + currentDrag.width, y: offset.height + currentDrag.height)
                        .clipped()
                }
                .frame(width: containerSize.width, height: containerSize.height)
                .background(Color.black.opacity(0.02))
                .clipShape(Rectangle())
                .overlay(
                    Rectangle().stroke(Color.secondary.opacity(0.6), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .simultaneousGesture(dragGesture(containerSize: containerSize))
                .simultaneousGesture(magnificationGesture(containerSize: containerSize))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sizeFittingAspect(in available: CGSize, aspect: CGSize) -> CGSize {
        let target = aspect.width / aspect.height
        let avail = available.width / max(available.height, 1)
        if avail > target {
            // height-limited
            let h = available.height
            return CGSize(width: h * target, height: h)
        } else {
            // width-limited
            let w = available.width
            return CGSize(width: w, height: w / target)
        }
    }

    private func dragGesture(containerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                currentDrag = value.translation
            }
            .onEnded { _ in
                offset.width += currentDrag.width
                offset.height += currentDrag.height
                currentDrag = .zero
                constrainOffset(containerSize: containerSize)
            }
    }

    private func magnificationGesture(containerSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                currentScale = value
            }
            .onEnded { _ in
                scale *= currentScale
                currentScale = 1.0
                constrainScaleAndOffset(containerSize: containerSize)
            }
    }

    private func constrainScaleAndOffset(containerSize: CGSize) {
        // Ensure the image covers the container (no gaps)
        let baseScale = baseFitScale(containerSize: containerSize)
        let minScale = baseScale
        let maxScale = max(minScale * 8.0, minScale)
        scale = max(min(scale, maxScale), minScale)
        constrainOffset(containerSize: containerSize)
    }

    private func constrainOffset(containerSize: CGSize) {
        // Limit panning so that empty areas are not exposed
        let baseScale = baseFitScale(containerSize: containerSize)
        let effectiveScale = scale * currentScale
        let drawSize = CGSize(width: image.size.width * baseScale * effectiveScale,
                              height: image.size.height * baseScale * effectiveScale)
        let dx = max(0, (drawSize.width - containerSize.width) / 2)
        let dy = max(0, (drawSize.height - containerSize.height) / 2)
        offset.width = min(max(offset.width + currentDrag.width, -dx), dx)
        offset.height = min(max(offset.height + currentDrag.height, -dy), dy)
    }

    private func baseFitScale(containerSize: CGSize) -> CGFloat {
        let sx = containerSize.width / max(image.size.width, 1)
        let sy = containerSize.height / max(image.size.height, 1)
        return max(sx, sy)
    }
}

// MARK: - NSImage helpers

private extension NSImage {
    func pngWrite(to url: URL) throws {
        guard let tiff = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "PNGWrite", code: 1, userInfo: nil)
        }
        try data.write(to: url, options: .atomic)
    }

    func renderPanZoomCrop(outputSize: CGSize, aspect: CGSize, scale: CGFloat, offset: CGSize, offsetInProgress: CGSize = .zero, circularMask: Bool = false) -> NSImage {
        // Render the image into a fixed-aspect output using the same pan/zoom rules as the UI.
        let outSize = outputSize
        let outRect = CGRect(origin: .zero, size: outSize)

        let img = NSImage(size: outSize)
        img.lockFocusFlipped(false)
        defer { img.unlockFocus() }

        // Compute base scale to fit aspect container
        let containerSize = CGSize(width: outSize.width, height: outSize.height)
        let baseScale = max(containerSize.width / max(self.size.width, 1), containerSize.height / max(self.size.height, 1))
        let effectiveScale = baseScale * scale

        let drawSize = CGSize(width: self.size.width * effectiveScale, height: self.size.height * effectiveScale)
        let center = CGPoint(x: outRect.midX, y: outRect.midY)
        let totalOffset = CGSize(width: offset.width + offsetInProgress.width, height: offset.height + offsetInProgress.height)
        let origin = CGPoint(x: center.x - drawSize.width/2 + totalOffset.width, y: center.y - drawSize.height/2 + totalOffset.height)
        let drawRect = CGRect(origin: origin, size: drawSize)

        if circularMask {
            let radius = min(outRect.width, outRect.height) / 2
            let circle = NSBezierPath(ovalIn: outRect.insetBy(dx: (outRect.width - 2*radius)/2, dy: (outRect.height - 2*radius)/2))
            circle.addClip()
        }

        let clipRect = NSBezierPath(rect: outRect)
        clipRect.addClip()

        self.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        return img
    }
}

