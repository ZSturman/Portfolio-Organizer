//
//  Status.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation

enum MainStatus: String, Codable, CaseIterable {
    case idea = "idea"
    case inProgress = "in_progress"
    case done = "done"
    case archived = "archived"
}

enum StepID: String, CaseIterable {
    case b_general, c_classification, d_thumb, e_specific, g_resources, z_review
}

struct StepPlan {
    static func steps(for status: MainStatus) -> [StepID] {
        return StepID.allCases
    }
}
