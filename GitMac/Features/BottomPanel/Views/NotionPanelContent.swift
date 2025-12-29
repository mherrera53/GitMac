//
//  NotionPanelContent.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

struct NotionPanelContent: View {
    @State private var dummyHeight: CGFloat = 300

    var body: some View {
        NotionPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
