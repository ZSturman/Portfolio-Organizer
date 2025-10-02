//
//  Project.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation

struct ResourceLink: Codable, Identifiable, Equatable {
    var id = UUID()
    var type: String; var label: String; var url: String
}

enum Reviewed: Codable, Equatable {
    case bool(Bool)
    case date(Date)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let s = try? c.decode(String.self), let d = ISO8601DateFormatter().date(from: s) { self = .date(d); return }
        self = .bool(false)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let b): try c.encode(b)
        case .date(let d): try c.encode(ISO8601DateFormatter().string(from: d))
        }
    }
}

struct Project: Codable, Equatable {
    var id: String
    var domain: String
    var title: String
    var subtitle: String
    var summary: String
    var visibility: String
    var category: String?
    var tech_category: String?
    var tech_medium: TechMedium
    var creative_genres: [String]?
    var expo_topic: String?
    var status: MainStatus
    var subStatus: String?
    var tags: [String]
    var resources: [ResourceLink]
    var thumbnail: String?
    var createdAt: Date
    var updatedAt: Date
    var reviewed: Reviewed

    struct TechMedium: Codable, Equatable { // accept string or array
        var values: [String]
        init(values: [String] = []) { self.values = values }
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) { values = s.isEmpty ? [] : [s] ; return }
            values = try c.decode([String].self)
        }
        func encode(to encoder: Encoder) throws {
            if values.count == 1 { var c = encoder.singleValueContainer(); try c.encode(values[0]); return }
            var c = encoder.singleValueContainer(); try c.encode(values)
        }
    }

    static func empty() -> Project {
        .init(id: "", domain: "", title: "", subtitle: "", summary: "", visibility: "private",
              category: nil, tech_category: nil, tech_medium: .init(),
              creative_genres: nil, expo_topic: nil,
              status: .idea, subStatus: nil, tags: [],
              resources: [], thumbnail: nil, createdAt: Date(), updatedAt: Date(),
              reviewed: .bool(false))
    }

    static func seed(domain: String, folder: String, isIdea: Bool) -> Project {
        .init(id: folder.lowercased().replacingOccurrences(of: " ", with: "_"),
              domain: domain, title: folder, subtitle: "", summary: "", visibility: "private",
              category: nil, tech_category: nil, tech_medium: .init(),
              creative_genres: nil, expo_topic: nil,
              status: isIdea ? .idea : .inProgress, subStatus: nil,
              tags: [], resources: [], thumbnail: nil, createdAt: Date(), updatedAt: Date(),
              reviewed: .bool(false))
    }
}

