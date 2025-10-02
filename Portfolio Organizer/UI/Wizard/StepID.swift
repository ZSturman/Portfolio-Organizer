//
//  StepID.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation

extension StepID {
    var title: String {
        switch self {
        case .b_general:       return "General Info"
        case .c_classification:return "Classification"
        case .d_thumb:         return "Thumbnail"
        case .e_specific:      return "Specific Info"
        case .g_resources:     return "Resources"
        case .z_review:        return "Review"
        }
    }
    
    var systemImage: String {
        switch self {
        case .b_general:       return "info.circle"
        case .c_classification:return "list.bullet.rectangle"
        case .d_thumb:         return "photo"
        case .e_specific:      return "slider.horizontal.3"
        case .g_resources:     return "link"
        case .z_review:        return "checkmark.circle"
        }
    }
}
