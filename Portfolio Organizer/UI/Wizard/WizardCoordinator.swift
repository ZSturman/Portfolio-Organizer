//
//  WizardCoordinator.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation
import SwiftUI
import Combine

final class WizardCoordinator: ObservableObject {
    let original: Project
    @Published var project: Project
    @Published var steps: [StepID]
    @Published var index: Int = 0
    let config: Config
    let saveAction: () -> Void

    var isDirty: Bool { project != original }

    init(project: Project, config: Config = .default(), saveAction: @escaping () -> Void) {
        self.original = project
        self.project = project
        self.config = config
        self.steps = StepPlan.steps(for: project.status)
        self.saveAction = saveAction
    }

    func updateStatus(_ s: MainStatus) {
        project.status = s
        steps = StepPlan.steps(for: s)
        index = 0
    }

    func committedProject() -> Project {
        var p = project
        p.updatedAt = Date()
        return p
    }

    func next() { index = min(index+1, steps.count-1) }
    func prev() { index = max(index-1, 0) }

    // Allow views to request a save of the working project immediately.
    func saveNow() { saveAction() }
}
