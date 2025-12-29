//
//  BottomPanelTab.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import Foundation

struct BottomPanelTab: Identifiable, Equatable, Codable {
    let id: UUID
    let type: BottomPanelType
    var customTitle: String?

    init(id: UUID = UUID(), type: BottomPanelType, customTitle: String? = nil) {
        self.id = id
        self.type = type
        self.customTitle = customTitle
    }

    var displayTitle: String {
        customTitle ?? type.displayName
    }

    static func == (lhs: BottomPanelTab, rhs: BottomPanelTab) -> Bool {
        lhs.id == rhs.id
    }
}
