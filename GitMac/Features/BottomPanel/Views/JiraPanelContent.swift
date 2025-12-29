//
//  JiraPanelContent.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

struct JiraPanelContent: View {
    @State private var dummyHeight: CGFloat = 300

    var body: some View {
        JiraPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
