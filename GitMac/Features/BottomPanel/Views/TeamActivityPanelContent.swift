//
//  TeamActivityPanelContent.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

struct TeamActivityPanelContent: View {
    @State private var dummyHeight: CGFloat = 400

    var body: some View {
        TeamActivityPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
