import Foundation
import SwiftUI

struct StepZ_ReviewView: View {
    @ObservedObject var wiz: WizardCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    Text("Review Changes").font(.title2)
                    if wiz.isDirty {
                        Text("You have unsaved changes.").foregroundColor(.orange)
                    } else {
                        Text("No changes since last save.").foregroundColor(.secondary)
                    }
                }
                Divider()
                section(title: "Basics") {
                    LabeledContent("Title", value: wiz.project.title)
                    LabeledContent("Summary", value: wiz.project.summary)
                    LabeledContent("Visibility", value: wiz.project.visibility)
                    LabeledContent("Status", value: wiz.project.status.rawValue)
                }
                section(title: "Classification") {
                    LabeledContent("Domain", value: wiz.project.domain)
                    if let c = wiz.project.category { LabeledContent("Category", value: c) }
                    if let t = wiz.project.tech_category { LabeledContent("Tech Category", value: t) }
                    if !wiz.project.tech_medium.values.isEmpty { LabeledContent("Tech Medium", value: wiz.project.tech_medium.values.joined(separator: ", ")) }
                    if let g = wiz.project.creative_genres, !g.isEmpty { LabeledContent("Genres", value: g.joined(separator: ", ")) }
                    if let e = wiz.project.expo_topic { LabeledContent("Expository Topic", value: e) }
                }
                section(title: "Resources") {
                    if wiz.project.resources.isEmpty {
                        Text("No resources added.").foregroundColor(.secondary)
                    } else {
                        ForEach(wiz.project.resources) { r in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.label.isEmpty ? r.url : r.label).font(.headline)
                                Text("\(r.type) • \(r.url)").font(.caption).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Spacer(minLength: 20)
            }
            .padding()
        }
    }

    @ViewBuilder
    func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
            Divider()
        }
    }
}

struct ProjectSummaryView: View {
    @ObservedObject var wiz: WizardCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Summary").font(.largeTitle).bold()
            if wiz.isDirty {
                Text("⚠️ You have unsaved changes.").foregroundColor(.red).bold()
            } else {
                Text("All changes are saved.").foregroundColor(.green).bold()
            }
            Divider()
            Text("Title: \(wiz.project.title)").font(.headline)
            if !wiz.project.summary.isEmpty {
                Text("Summary: \(wiz.project.summary)").font(.body)
            }
            HStack {
                Text("Visibility:").bold()
                Text(wiz.project.visibility)
            }
            HStack {
                Text("Status:").bold()
                Text(wiz.project.status.rawValue)
            }
            Divider()
            Text("Classification").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Domain: \(wiz.project.domain)")
                if let c = wiz.project.category { Text("Category: \(c)") }
                if let t = wiz.project.tech_category { Text("Tech Category: \(t)") }
                if !wiz.project.tech_medium.values.isEmpty {
                    Text("Tech Medium: \(wiz.project.tech_medium.values.joined(separator: ", "))")
                }
                if let g = wiz.project.creative_genres, !g.isEmpty {
                    Text("Genres: \(g.joined(separator: ", "))")
                }
                if let e = wiz.project.expo_topic { Text("Expository Topic: \(e)") }
            }
            Divider()
            Text("Resources").font(.headline)
            if wiz.project.resources.isEmpty {
                Text("No resources added.")
            } else {
                ForEach(wiz.project.resources) { r in
                    VStack(alignment: .leading) {
                        Text(r.label.isEmpty ? r.url : r.label).font(.subheadline).bold()
                        Text("\(r.type) • \(r.url)").font(.caption)
                    }
                }
            }
        }
        .padding()
    }
}
