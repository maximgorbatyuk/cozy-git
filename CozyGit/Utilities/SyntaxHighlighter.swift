//
//  SyntaxHighlighter.swift
//  CozyGit
//

import SwiftUI

/// Basic syntax highlighter for common programming languages
struct SyntaxHighlighter {

    // MARK: - Language Detection

    /// Language type based on file extension
    enum Language: String {
        case swift
        case javascript
        case typescript
        case python
        case ruby
        case go
        case rust
        case java
        case kotlin
        case csharp
        case cpp
        case c
        case objectiveC
        case html
        case css
        case json
        case yaml
        case markdown
        case shell
        case sql
        case xml
        case unknown

        static func from(extension ext: String) -> Language {
            switch ext.lowercased() {
            case "swift": return .swift
            case "js", "jsx", "mjs": return .javascript
            case "ts", "tsx": return .typescript
            case "py": return .python
            case "rb": return .ruby
            case "go": return .go
            case "rs": return .rust
            case "java": return .java
            case "kt", "kts": return .kotlin
            case "cs": return .csharp
            case "cpp", "cc", "cxx", "hpp": return .cpp
            case "c", "h": return .c
            case "m", "mm": return .objectiveC
            case "html", "htm": return .html
            case "css", "scss", "sass", "less": return .css
            case "json": return .json
            case "yml", "yaml": return .yaml
            case "md", "markdown": return .markdown
            case "sh", "bash", "zsh": return .shell
            case "sql": return .sql
            case "xml", "plist": return .xml
            default: return .unknown
            }
        }
    }

    // MARK: - Token Types

    enum TokenType {
        case keyword
        case string
        case comment
        case number
        case type
        case function
        case property
        case `operator`
        case punctuation
        case plain

        var color: Color {
            switch self {
            case .keyword: return Color(red: 0.8, green: 0.2, blue: 0.5)      // Pink
            case .string: return Color(red: 0.8, green: 0.4, blue: 0.2)       // Orange
            case .comment: return Color(red: 0.5, green: 0.5, blue: 0.5)      // Gray
            case .number: return Color(red: 0.2, green: 0.6, blue: 0.8)       // Blue
            case .type: return Color(red: 0.4, green: 0.7, blue: 0.4)         // Green
            case .function: return Color(red: 0.6, green: 0.4, blue: 0.8)     // Purple
            case .property: return Color(red: 0.4, green: 0.6, blue: 0.8)     // Light Blue
            case .operator: return .primary
            case .punctuation: return .secondary
            case .plain: return .primary
            }
        }
    }

    // MARK: - Keywords by Language

    private static let swiftKeywords: Set<String> = [
        "import", "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
        "if", "else", "switch", "case", "default", "for", "while", "repeat", "in", "return",
        "break", "continue", "guard", "defer", "throw", "throws", "try", "catch", "do",
        "public", "private", "internal", "fileprivate", "open", "static", "final", "override",
        "init", "deinit", "self", "Self", "super", "nil", "true", "false", "as", "is", "any",
        "some", "where", "typealias", "associatedtype", "async", "await", "actor", "nonisolated",
        "@State", "@Binding", "@Published", "@Observable", "@MainActor", "@Environment"
    ]

    private static let javascriptKeywords: Set<String> = [
        "const", "let", "var", "function", "return", "if", "else", "for", "while", "do",
        "switch", "case", "default", "break", "continue", "class", "extends", "new", "this",
        "super", "import", "export", "from", "async", "await", "try", "catch", "finally",
        "throw", "typeof", "instanceof", "in", "of", "true", "false", "null", "undefined",
        "yield", "static", "get", "set", "constructor"
    ]

    private static let pythonKeywords: Set<String> = [
        "def", "class", "if", "elif", "else", "for", "while", "try", "except", "finally",
        "with", "as", "import", "from", "return", "yield", "break", "continue", "pass",
        "raise", "assert", "lambda", "and", "or", "not", "in", "is", "True", "False", "None",
        "global", "nonlocal", "del", "async", "await", "self", "cls"
    ]

    private static let goKeywords: Set<String> = [
        "package", "import", "func", "var", "const", "type", "struct", "interface", "map",
        "chan", "if", "else", "for", "range", "switch", "case", "default", "select",
        "break", "continue", "return", "goto", "defer", "go", "fallthrough", "nil", "true", "false"
    ]

    // MARK: - Highlighting

    /// Highlight a line of code
    static func highlight(_ text: String, language: Language) -> AttributedString {
        var result = AttributedString(text)

        // Simple token-based highlighting
        let tokens = tokenize(text, language: language)

        for token in tokens {
            if let range = result.range(of: token.text, options: [], locale: nil) {
                result[range].foregroundColor = token.type.color
            }
        }

        return result
    }

    /// Highlight for SwiftUI Text view
    static func highlightedText(_ text: String, language: Language) -> Text {
        let tokens = tokenize(text, language: language)

        var result = Text("")
        var lastIndex = text.startIndex

        for token in tokens {
            if let tokenRange = text.range(of: token.text, range: lastIndex..<text.endIndex) {
                // Add plain text before token
                if tokenRange.lowerBound > lastIndex {
                    let prefix = String(text[lastIndex..<tokenRange.lowerBound])
                    result = result + Text(prefix)
                }

                // Add highlighted token
                result = result + Text(token.text).foregroundColor(token.type.color)

                lastIndex = tokenRange.upperBound
            }
        }

        // Add remaining text
        if lastIndex < text.endIndex {
            let suffix = String(text[lastIndex...])
            result = result + Text(suffix)
        }

        return result
    }

    // MARK: - Tokenization

    private struct Token {
        let text: String
        let type: TokenType
    }

    private static func tokenize(_ text: String, language: Language) -> [Token] {
        var tokens: [Token] = []

        let keywords = keywords(for: language)

        // Simple regex-based tokenization
        let patterns: [(String, TokenType)] = [
            // Comments
            (#"//.*$"#, .comment),
            (#"#.*$"#, .comment),
            (#"/\*.*?\*/"#, .comment),

            // Strings
            (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, .string),
            (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, .string),
            (#"`[^`]*`"#, .string),

            // Numbers
            (#"\b\d+\.?\d*\b"#, .number),
            (#"\b0x[0-9a-fA-F]+\b"#, .number),

            // Words (potential keywords/identifiers)
            (#"\b[a-zA-Z_@][a-zA-Z0-9_]*\b"#, .plain),
        ]

        for (pattern, defaultType) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, options: [], range: range)

                for match in matches {
                    if let matchRange = Range(match.range, in: text) {
                        let matchText = String(text[matchRange])

                        var tokenType = defaultType
                        if defaultType == .plain && keywords.contains(matchText) {
                            tokenType = .keyword
                        }

                        tokens.append(Token(text: matchText, type: tokenType))
                    }
                }
            }
        }

        return tokens
    }

    private static func keywords(for language: Language) -> Set<String> {
        switch language {
        case .swift, .objectiveC:
            return swiftKeywords
        case .javascript, .typescript:
            return javascriptKeywords
        case .python:
            return pythonKeywords
        case .go:
            return goKeywords
        default:
            return []
        }
    }
}

// MARK: - View Extension

extension Text {
    /// Apply syntax highlighting to a code line
    func syntaxHighlighted(language: SyntaxHighlighter.Language) -> Text {
        self
    }
}
