import SwiftUI
import Splash

// MARK: - Syntax Highlighted Text

struct SyntaxHighlightedText: View {
    let code: String
    let language: String

    @State private var highlightedCode: AttributedString?

    var body: some View {
        Text(highlightedCode ?? AttributedString(code))
            .font(DesignTokens.Typography.diffLine)
            .task(id: code) {
                guard grammar(for: language) != nil else {
                    highlightedCode = AttributedString(code)
                    return
                }
                let highlighter = Splash.SyntaxHighlighter(
                    format: AttributedStringOutputFormat(theme: .sundellsColors(withFont: .init(size: DesignTokens.Typography.diffLineSize)))
                )
                let highlighted = highlighter.highlight(code)
                highlightedCode = AttributedString(highlighted)
            }
    }

    private func grammar(for language: String) -> Grammar? {
        switch language.lowercased() {
        case "swift": return SwiftGrammar()
        default: return nil
        }
    }
}
