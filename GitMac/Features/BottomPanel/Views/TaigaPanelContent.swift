//
//  TaigaPanelContent.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

struct TaigaPanelContent: View {
    @State private var dummyHeight: CGFloat = 300

    var body: some View {
        // Use the original panel with dummy bindings
        // The resizer won't do anything since UnifiedBottomPanel manages the height
        // The close button won't do anything since tabs handle closing
        TaigaTicketsPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
