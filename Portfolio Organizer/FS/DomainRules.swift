//
//  DomainRules.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation

enum DomainRules {
    static func isIgnored(_ name: String) -> Bool { name.hasPrefix("_") && name.hasSuffix("_") }
    static func isDomainFolder(_ name: String) -> Bool { !name.hasPrefix("_") }
    static func ideasFolder(in domain: URL) -> URL { domain.appendingPathComponent("_IDEAS_", isDirectory: true) }
}
