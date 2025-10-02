//
//  ProjectStore.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation

enum ProjectStore {
    static func path(in dir: URL) -> URL { dir.appendingPathComponent("_project.json") }

    static func load(from dir: URL) throws -> Project? {
        let url = path(in: dir)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONCoding.decoder.decode(Project.self, from: data)
    }

    static func save(_ project: Project, to dir: URL) throws {
        var p = project
        let now = Date()
        p.updatedAt = now
        if p.status == .idea { p.reviewed = .bool(false) }
        else { p.reviewed = .date(now) }

        // Ensure directory exists
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Prepare encoded project as dictionary
        let encodedData = try JSONCoding.encoder.encode(p)
        guard var newObj = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any] else {
            // Fallback: write raw encoded data if conversion fails
            try encodedData.write(to: path(in: dir), options: .atomic)
            return
        }

        // Load existing JSON if present to preserve non-Project fields (e.g., images object)
        let url = path(in: dir)
        if FileManager.default.fileExists(atPath: url.path),
           let existingData = try? Data(contentsOf: url),
           let existingObj = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
            if let images = existingObj["images"] as? [String: Any] {
                newObj["images"] = images
            }
            if let planning = existingObj["planning"] as? [String: Any] {
                newObj["planning"] = planning
            }
        }

        // Serialize merged object with pretty formatting
        let outData = try JSONSerialization.data(withJSONObject: newObj, options: [.prettyPrinted, .sortedKeys])
        try outData.write(to: url, options: .atomic)
    }
}

