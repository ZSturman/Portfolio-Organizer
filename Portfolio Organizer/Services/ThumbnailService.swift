//
//  ThumbnailService.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation
import AppKit

enum ThumbnailService {
    static func copyThumbnail(from src: URL, toProjectDir dir: URL) throws -> String {
        let ext = src.pathExtension
        let dst = dir.appendingPathComponent("thumbnail.\(ext)")
        if FileManager.default.fileExists(atPath: dst.path) { try? FileManager.default.removeItem(at: dst) }
        try FileManager.default.copyItem(at: src, to: dst)
        return dst.lastPathComponent
    }
}
