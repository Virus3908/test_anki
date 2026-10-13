import Foundation

nonisolated enum GrammarCompetency: String, Codable, Sendable {
    case formation, application, context, meaning, contrast, correction
}

/// Explicit per-ID resource metadata. Source tags describe semantics; they do not prove lesson readiness.
nonisolated struct GrammarPracticeMetadata: Codable, Sendable {
    let categories: [GrammarCategory]
    let plannedKinds: [GrammarExerciseKind]
    let availableKinds: [GrammarExerciseKind]
    let algorithmicForms: [GrammarConjugationEngine.Form]
    let sourceExampleCount: Int
    let status: String
    let basis: String
    let limitationRU: String?
}
