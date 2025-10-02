//
//  PortfolioScanner.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation

enum PortfolioScanner {
    static func listDomains(at root: URL) throws -> [URL] {
        let accessed = root.startAccessingSecurityScopedResource()
        defer { if accessed { root.stopAccessingSecurityScopedResource() } }
        
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            .filter { try ($0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false) }
            .filter { DomainRules.isDomainFolder($0.lastPathComponent) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func listProjects(in domain: URL) throws -> [String] {
        let accessed = domain.startAccessingSecurityScopedResource()
        defer { if accessed { domain.stopAccessingSecurityScopedResource() } }
        
        return try FileManager.default.contentsOfDirectory(at: domain, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            .filter { try ($0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false) }
            .map { $0.lastPathComponent }
            .sorted()
    }

    static func listProjectsIncludingIdeas(in domainURL: URL) -> [AppState.ProjectRef] {
        var out: [AppState.ProjectRef] = []
        let fm = FileManager.default
        if let kids = try? fm.contentsOfDirectory(at: domainURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for k in kids where ((try? k.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false) {
                if k.lastPathComponent == "_IDEAS_" {
                    if let ideas = try? fm.contentsOfDirectory(at: k, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                        for p in ideas where ((try? p.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false) {
                            out.append(.init(domainURL: k, name: p.lastPathComponent))
                        }
                    }
                } else {
                    out.append(.init(domainURL: domainURL, name: k.lastPathComponent))
                }
            }
        }
        return out.sorted()
    }
}

