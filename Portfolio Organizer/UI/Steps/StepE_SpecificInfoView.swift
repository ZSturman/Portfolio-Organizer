// StepE_SpecificInfoView.swift (deprecated)
// This view has been merged into StepB_GeneralInfoView and is no longer used.

import Foundation
import SwiftUI

struct StepE_SpecificInfoView: View {
    @ObservedObject var wiz: WizardCoordinator
    let config: Config
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Specific Info has moved to General Info", systemImage: "info.circle")
            Text("You can remove this file safely if desired. It is no longer presented in the wizard.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
