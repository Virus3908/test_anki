import Foundation

/// Selected original MIT grammar only. Upstream inventory levels never replace OpenJLPT levels.
nonisolated struct GrammarSupplement: Codable, Sendable {
    struct Example: Codable, Sendable { let ja: String; let en: String }
    let repository: String
    let commit: String
    let path: String
    let license: String
    let summary: String
    let structure: [String]
    let pitfalls: [String]
    let examples: [Example]
}
