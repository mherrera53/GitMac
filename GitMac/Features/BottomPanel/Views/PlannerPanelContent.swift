//
//  PlannerPanelContent.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

struct PlannerPanelContent: View {
    @State private var dummyHeight: CGFloat = 300

    var body: some View {
        PlannerTasksPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
