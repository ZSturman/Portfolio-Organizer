import Foundation
import SwiftUI

struct StepC_ClassificationView: View {
    @ObservedObject var wiz: WizardCoordinator
    let config: Config

    @State private var showDomainInfo: Bool = true

    // New Domain/Classification Helpers (mirroring StepB)
    @State private var creativeOtherCategory: String = ""
    @State private var creativeOtherGenre: String = ""
    @State private var creativeOtherMedium: String = ""
    @State private var expositoryTopicsSelection: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DisclosureGroup(isExpanded: $showDomainInfo) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Domain picker
                        let domains = Array(config.domain_categories.keys).sorted()
                        let currentDomain = wiz.project.domain
                        Picker("Domain", selection: Binding(get: {
                            domains.contains(currentDomain) ? currentDomain : (domains.first ?? currentDomain)
                        }, set: { newDomain in
                            // Reset dependent fields when domain changes
                            wiz.project.domain = newDomain
                            wiz.project.category = nil
                            wiz.project.tech_category = nil
                            wiz.project.tech_medium = .init(values: [])
                            wiz.project.creative_genres = []
                            wiz.project.expo_topic = nil
                        })) {
                            ForEach(domains, id: \.self) { d in
                                Text(d).tag(d)
                            }
                        }
                        .pickerStyle(.menu)
                        .help("Change the domain for this project.")

                        // Category + domain-specific fields
                        Group {
                            switch wiz.project.domain {
                            case "Creative":
                                creativeSection
                            case "Technology":
                                technologySection
                            case "Expository":
                                expositorySection
                            default:
                                EmptyView()
                            }
                        }
                    }
                } label: {
                    Text("Domain & Classification")
                }
            }
            .padding()
        }
    }

    // MARK: - Sections copied from StepB

    @ViewBuilder
    private var creativeSection: some View {
        // Category for Creative
        let creativeCategories = ["Story","Game","Article","Other"]
        let currentCreative = wiz.project.category ?? ""
        Picker("Category", selection: Binding(get: {
            creativeCategories.contains(currentCreative) ? currentCreative : "Other"
        }, set: { wiz.project.category = $0 })) {
            ForEach(creativeCategories, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.menu)

        if (wiz.project.category ?? "") == "Other" {
            TextField("Custom category", text: Binding(get: { creativeOtherCategory }, set: { newVal in
                creativeOtherCategory = newVal
                wiz.project.category = newVal
            }))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 420)
        }

        // Genres (multi-select)
        MultiPickerInline(title: "Genres",
                          all: config.creative_genres,
                          selection: Binding(get: { Set(wiz.project.creative_genres ?? []) }, set: { wiz.project.creative_genres = Array($0) }))
        if (wiz.project.creative_genres ?? []).contains("Other") {
            TextField("Custom genre", text: Binding(get: { creativeOtherGenre }, set: { newVal in
                creativeOtherGenre = newVal
                var current = Set(wiz.project.creative_genres ?? [])
                if !newVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    current.insert(newVal)
                    wiz.project.creative_genres = Array(current)
                }
            }))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 420)
        }

        // Mediums depend on category
        let mediums = creativeMediumsForCategory(wiz.project.category ?? "")
        MultiPickerInline(title: "Medium(s)",
                          all: mediums,
                          selection: Binding(get: { Set(wiz.project.tech_medium.values) }, set: { wiz.project.tech_medium = .init(values: Array($0)) }))
        if mediums.contains("Other") && wiz.project.tech_medium.values.contains("Other") {
            TextField("Custom medium", text: Binding(get: { creativeOtherMedium }, set: { newVal in
                creativeOtherMedium = newVal
                var current = Set(wiz.project.tech_medium.values)
                if !newVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    current.insert(newVal)
                    wiz.project.tech_medium = .init(values: Array(current))
                }
            }))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 420)
        }
    }

    @ViewBuilder
    private var technologySection: some View {
        let techCategories = config.domain_categories["Technology"] ?? []
        let currentTech = wiz.project.tech_category ?? ""
        Picker("Category", selection: Binding(get: {
            techCategories.contains(currentTech) ? currentTech : (techCategories.first ?? "")
        }, set: { wiz.project.tech_category = $0 })) {
            ForEach(techCategories, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.menu)

        let mediums = techMediumsForTechCategory(wiz.project.tech_category ?? "")
        MultiPickerInline(title: "Medium(s)",
                          all: mediums,
                          selection: Binding(get: { Set(wiz.project.tech_medium.values) }, set: { wiz.project.tech_medium = .init(values: Array($0)) }))
        if mediums.contains("Other") && wiz.project.tech_medium.values.contains("Other") {
            TextField("Custom medium", text: Binding(get: { creativeOtherMedium }, set: { newVal in
                creativeOtherMedium = newVal
                var current = Set(wiz.project.tech_medium.values)
                if !newVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    current.insert(newVal)
                    wiz.project.tech_medium = .init(values: Array(current))
                }
            }))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 420)
        }
    }

    @ViewBuilder
    private var expositorySection: some View {
        let expoCategories = config.domain_categories["Expository"] ?? []
        let currentExpo = wiz.project.category ?? ""
        Picker("Category", selection: Binding(get: {
            expoCategories.contains(currentExpo) ? currentExpo : (expoCategories.first ?? "")
        }, set: { wiz.project.category = $0 })) {
            ForEach(expoCategories, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.menu)

        // Topics multi-select; persist as comma-separated in `expo_topic` for now
        MultiPickerInline(title: "Topics",
                          all: config.expository_topics + ["Other"],
                          selection: Binding(get: { expositoryTopicsSelection }, set: { expositoryTopicsSelection = $0; wiz.project.expo_topic = expositoryTopicsSelection.sorted().joined(separator: ", ") }))
        if expositoryTopicsSelection.contains("Other") {
            TextField("Custom topic", text: Binding(get: { creativeOtherGenre }, set: { newVal in
                creativeOtherGenre = newVal
                if !newVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    expositoryTopicsSelection.insert(newVal)
                    wiz.project.expo_topic = expositoryTopicsSelection.sorted().joined(separator: ", ")
                }
            }))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 420)
        }
    }

    // MARK: - Helpers copied from StepB

    private func creativeMediumsForCategory(_ category: String) -> [String] {
        switch category {
        case "Story":
            var list = config.creative_story_mediums
            if !list.contains("Other") { list.append("Other") }
            return list
        case "Game":
            var list = config.game_mediums
            if !list.contains("Other") { list.append("Other") }
            return list
        case "Article":
            var list = config.creative_article_mediums
            if !list.contains("Other") { list.append("Other") }
            return list
        default:
            var list = config.script_mediums
            if !list.contains("Other") { list.append("Other") }
            return list
        }
    }

    private func techMediumsForTechCategory(_ techCategory: String) -> [String] {
        let baseSoftware = config.tech_mediums
        let baseHardware = config.hardware_mediums
        switch techCategory {
        case let s where s.lowercased().contains("soft"):
            var list = baseSoftware
            if !list.contains("Other") { list.append("Other") }
            return list
        case let s where s.lowercased().contains("hard"):
            var list = baseHardware
            if !list.contains("Other") { list.append("Other") }
            return list
        case let s where s.lowercased().contains("system"):
            var list = baseSoftware + baseHardware.filter { !baseSoftware.contains($0) }
            if !list.contains("Other") { list.append("Other") }
            return list
        default:
            var list = baseSoftware
            if !list.contains("Other") { list.append("Other") }
            return list
        }
    }
}
