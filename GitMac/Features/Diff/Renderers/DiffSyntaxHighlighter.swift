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

        // Nota: Splash usa su propio tipo Font, inicializamos con el tamaño de DesignTokens
        let highlighter = Splash.SyntaxHighlighter(
            format: AttributedStringOutputFormat(theme: .sundellsColors(withFont: .init(size: DesignTokens.Typography.diffLineSize)))
        )

        let highlighted = highlighter.highlight(code)
        return AttributedString(highlighted)
    }

    var body: some View {
        Text(highlightedCode)
            .font(DesignTokens.Typography.diffLine)
    }

    private func grammar(for language: String) -> Grammar? {
        switch language.lowercased() {
        case "swift": return SwiftGrammar()
        default: return nil
        }
    }
}
