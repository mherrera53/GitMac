import SwiftUI
import Splash

// MARK: - Syntax Highlighted Text

struct SyntaxHighlightedText: View {
    let code: String
    let language: String

    private var highlightedCode: AttributedString {
        guard grammar(for: language) != nil else {
            return AttributedString(code)
        }

        let highlighter = Splash.SyntaxHighlighter(
            format: AttributedStringOutputFormat(theme: .sundellsColors(withFont: .init(size: 12)))
        )

        let highlighted = highlighter.highlight(code)
        return AttributedString(highlighted)
    }

    var body: some View {
        Text(highlightedCode)
            .font(.system(.body, design: .monospaced))
    }

    private func grammar(for language: String) -> Grammar? {
        switch language.lowercased() {
        case "swift": return SwiftGrammar()
        default: return nil
        }
    }
}
