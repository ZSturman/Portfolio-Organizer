////
////  StepC_SupportingFilesView.swift
////  Portfolio Organizer
////
////  Created by Zachary Sturman on 9/29/25.
////
//
//import Foundation
//import SwiftUI
//import UniformTypeIdentifiers
//
//struct StepC_SupportingFilesView: View {
//    @ObservedObject var wiz: WizardCoordinator
//    let projectDir: URL
//    @State private var moveInsteadOfCopy = false
//
//    var body: some View {
//        // Deprecated: Supporting UI now lives inside FolderPreviewView.
//        SupportingDropboxesView(rootURL: projectDir, onCreateFolder: { name in
//            try? FileManager.default.createDirectory(at: projectDir.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true)
//        }, onDropToFolder: { sub, providers in
//            let dest = projectDir.appendingPathComponent(sub, isDirectory: true)
//            try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
//            var handled = false
//            if let provider = providers.first, provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
//                _ = provider.loadObject(ofClass: URL.self) { url, _ in
//                    if let url {
//                        let target = dest.appendingPathComponent(url.lastPathComponent)
//                        try? FileManager.default.copyItem(at: url, to: target)
//                        handled = true
//                    }
//                }
//            }
//            return handled
//        })
//        .padding()
//    }
//}
