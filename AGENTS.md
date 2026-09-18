# AGENTS.md

## Purpose

This repository is an iOS SwiftUI application for studying kanji, kana,
Japanese vocabulary, and imported Anki decks. Use this file as the first
map of the codebase before exploring files.

## Token / context rules

-   **Do not read or dump `kanji_test/Data/word-data.json` into model
    context.** It is a large bundled dictionary dataset (\~60,000 lines)
    and is normally irrelevant to implementation work.
-   Treat `word-data.json` as opaque application data. Inspect only a
    tiny sample when a task explicitly concerns word-data parsing,
    malformed records, ordering, or dataset contents.
-   Do not recursively inspect imported/generated Anki content in
    Application Support; work from models/repository/parser code unless
    a concrete imported package is part of the task.
-   Prefer targeted symbol/search navigation over scanning the whole
    repository.
-   Start from the subsystem listed below and expand only to direct
    dependencies.
-   Do not inspect `Assets.xcassets` unless the task concerns assets,
    icons, or colors.
-   Do not inspect `Packages/AnkiImport/Tests` unless the task concerns
    Anki import/rendering or a regression needs a package-level test.

## Current shape

The app currently has roughly 154 Swift files and \~10k lines of Swift
in `kanji_test`, plus the local `Packages/AnkiImport` Swift package.

Main flow:

`SwiftUI Views -> @Observable ViewModels/coordinators -> domain Models/engines -> repositories/loaders/services`

Imported Anki content joins the same training/SRS pipeline as built-in
cards, but package parsing/storage is kept in a separate subsystem.

## App entry and composition

-   `kanji_test/App/kanji_testApp.swift` --- app entry point.
-   `kanji_test/Views/ContentView.swift` --- root `NavigationStack`,
    lifecycle hooks, loading/error UI and route switching.
-   `kanji_test/ViewModels/StudyAppViewModel.swift` --- composition
    root. Owns settings, catalog, navigation, deck preview, coordinator,
    training session, translations and Anki library.
-   `StudyAppViewModel+Lifecycle.swift` --- saved-state/app lifecycle
    work.
-   `StudyAppViewModel+ScreenActions.swift` --- route/screen actions,
    including Anki navigation.
-   `StudyAppViewModel+TrainingStart.swift`, `+TrainingFlow.swift` ---
    training startup and flow.
-   `StudyNavigation.swift` --- application route state.
-   `StudyCoordinator*.swift` --- selected built-in decks/cards and
    preview presentation.

## Training and scheduling

Start here for queue/review/session behavior: -
`kanji_test/ViewModels/TrainingSessionViewModel.swift` --- observable
session orchestration, submit/undo/exclude/rebuild/day rollover. -
`kanji_test/Models/TrainingSessionEngine.swift` --- builds the current
study plan. - `kanji_test/Models/TrainingSessionState.swift` --- active
queue, `todayIDs`, current index, undo state, `nextLearningDate`, hidden
reviews. - `kanji_test/Models/StudyProgressStore.swift` and
`StudyProgressStore+*.swift` --- persisted progress, due checks, limits,
selection and schedule helpers. - `StudyReviewRecord.swift`,
`StudyReviewLog.swift`, `ReviewRating.swift` --- app-owned review
state/history. - `StudyScheduler.swift` --- **adapter around external
FSRS**. - `DeckOptions.swift` --- per-deck scheduling options. -
`Data/ReviewRepository.swift` --- review persistence facade. -
`Data/JSONFileStore.swift` --- generic JSON persistence with
backup/recovery. - `ViewModels/TrainingPresentation.swift` ---
presentation helpers such as interval labels.

### Queue semantics

Keep these concepts distinct: - `StudyQueue.ids` /
`StudyQueuePlan.readyIDs` --- cards that can be shown by the active
queue. - `TrainingSessionState.todayIDs` / `StudyQueuePlan.todayIDs` ---
snapshot of cards that still belong to the current study day, including
cards waiting for a later learning step. - `nextLearningDate` --- next
waiting learning/relearning due time. - `hiddenReviews` --- reviews
hidden by the daily review limit.

`TrainingSessionState.rebuild(...)` calls
`TrainingSessionEngine.plan(...)`, replaces the active queue and
refreshes `todayIDs`. `TrainingSessionViewModel.submitReview(...)`
rebuilds after each answer.

Do not derive "cards remaining today" from `readyIDs.count` if waiting
learning cards must be counted; use the day-level state (`todayIDs`) or
the appropriate plan field.

Important: queue policy and FSRS scheduling are separate concerns. A
change to which due/waiting card is shown next usually belongs in
`TrainingSessionEngine`; a change to interval calculation belongs in
`StudyScheduler`.

## Built-in decks and content

-   `ViewModels/StudyCardCatalog.swift` --- central in-memory catalog
    for kanji/kana/word/**Anki** study cards.
-   `ViewModels/DeckPreviewViewModel.swift` and `+Kana/+Kanji/+Word` ---
    built-in deck loading/preview.
-   `Models/StudyDeck.swift`, `KanjiDeck.swift`, `KanaDeck.swift`,
    `WordFrequencyDeck.swift` --- deck definitions.
-   `Models/KanjiCard.swift`, `KanaStudyCard.swift`,
    `WordStudyCard.swift` --- built-in card models.
-   `Data/BundledStudyData.swift` --- cached decoding of bundled JSON.
-   `Data/KanjiDataLoader*.swift`, `KanaDataLoader.swift`,
    `WordDataLoader*.swift` --- content loading.
-   `Data/kanji-data.json` --- bundled kanji data.
-   `Data/word-data.json` --- large bundled vocabulary data; ignore by
    default.

## Anki import and study

Anki support is now a first-class subsystem. Start with
`docs/anki-import.md` for behavior and format support.

### Local package: `Packages/AnkiImport`

This package owns package-format parsing and template/content
processing: - `AnkiPackageParser.swift` --- extracts `.apkg` /
`.colpkg`. - `AnkiDatabase.swift` --- reads supported SQLite collection
formats. - `AnkiProtobuf.swift` --- modern protobuf metadata/media
handling. - `AnkiModels.swift` --- imported collection/deck/note/card
models. - `AnkiContent.swift`, `AnkiContentParser.swift` --- parsed
field/content representation. - `AnkiTemplateRenderer.swift` --- Anki
template rendering. - Package dependencies: ZIPFoundation 0.9.20, zstd
1.5.7, SwiftSoup 2.11.2; SQLite is linked system-side. -
`Packages/AnkiImport/Tests` --- parser/rendering regression tests.

Keep raw Anki parsing concerns in this package instead of moving them
into app UI/ViewModels.

### App-side Anki subsystem

-   `Data/AnkiRepository.swift` --- imports packages, SHA-256
    deduplication, staging/publish, library index and imported content
    access.
-   `Models/AnkiLibrary.swift` --- imported deck/card wrappers used by
    the app.
-   `Models/AnkiFieldDisplayPreferences.swift` --- Anki field/card
    display preferences.
-   `ViewModels/AnkiLibraryViewModel.swift` --- imported library UI
    state.
-   `ViewModels/TranslationViewModel+Anki.swift` --- translations for
    Anki content.
-   `Services/AnkiCardRenderer.swift` --- card/template rendering
    bridge.
-   `Services/AnkiMediaService.swift` --- local media resolution.
-   `Services/AnkiAudioPlayback.swift` --- imported Anki audio playback.
-   `Views/AnkiLibraryView.swift` --- imported library UI.
-   `Views/AnkiDeckPreviewView.swift` --- imported deck preview.
-   `Views/AnkiCardContentView.swift`, `AnkiNativeContentView.swift`,
    `AnkiHTMLView.swift` --- native/template card presentation.
-   `Views/TrainingView+AnkiTraining.swift` --- Anki training
    integration.

Anki decks use the same `TrainingSessionViewModel`,
`TrainingSessionEngine`, `StudyScheduler` and `ReviewRepository` as
built-in decks. Imported Anki scheduling/history is preserved in the
imported source database but is **not migrated into the app's FSRS
state**; imported cards start app-owned SRS from zero.

Stable app review keys are namespaced with `anki:` so they do not
collide with built-in content.

## Anki storage and safety

`AnkiRepository` stores its index in `anki-library.json` through
`JSONFileStore`.

Imported package content is stored under the app's Application Support
Anki directory. Import uses a staging directory and only publishes after
successful extraction/validation. Identical package files are detected
by SHA-256.

Do not casually weaken path validation, archive limits, media
validation, staging/atomicity, or security-scoped URL handling. See
`docs/anki-import.md` before changing import behavior.

## Drawing / stroke checking

-   `ViewModels/DrawingSessionViewModel.swift` --- drawing-session
    state/orchestration.
-   `Drawing/DrawingBoard.swift` --- drawing surface.
-   `Drawing/StrokeFeedback.swift` --- `StrokeEvaluator`.
-   `Drawing/StrokeFeedbackModels.swift` --- evaluation/feedback models.
-   `Drawing/SVGStrokeExtractor.swift`, `SVGPathParser.swift` --- SVG
    stroke extraction/parsing.
-   `Drawing/KanaStrokePresets.swift` --- kana presets.
-   `Models/KanjiStroke.swift` --- stroke/source domain models.
-   `Views/TrainingView+*Drawing*.swift` --- training integration.

For drawing correctness bugs, inspect `DrawingSessionViewModel`,
`StrokeEvaluator`, then the relevant drawing integration file.

## Translation and examples

-   `ViewModels/TranslationViewModel.swift` and extensions ---
    translation/example request state, including `+Anki`.
-   `Data/TranslationRepository.swift` --- translation persistence.
-   `Models/TranslationModels.swift` --- persisted translation models.
-   `Services/RussianMeaningTranslator.swift` --- translation
    orchestration.
-   `Services/SystemTranslationClient.swift` --- system translation
    integration.
-   `Services/RussianMeaningDictionary.swift` --- local Russian
    meanings.
-   Tatoeba files in `Data/` --- remote word examples.
-   `Data/WordExampleCacheRepository.swift` --- example cache.

## Remote kanji data

-   `Services/RemoteKanjiProvider.swift` --- provider protocol/default
    implementation.
-   `Services/KanjiAPIProvider+Loading.swift`, `+Mapping.swift` ---
    loading/mapping.
-   `Services/KanjiAPIEndpoint.swift`, `KanjiAPIModels.swift` ---
    endpoint/transport models.
-   `Data/KanjiDeckCacheRepository.swift` --- cached kanji decks.
-   `Data/KanaSVGCacheRepository.swift` --- cached kana SVG.

## UI map

-   `Views/StartView*.swift` --- mode/deck start screen, including Anki
    entry.
-   `Views/DeckPreviewView*.swift` --- built-in deck preview/schedule.
-   `Views/Anki*.swift` --- imported Anki library/deck/card UI.
-   `Views/TrainingView*.swift` --- training screen split by
    mode/feature.
-   `Views/CardContentRendering*.swift` --- reusable built-in card
    rendering.
-   `Views/SettingsView*.swift` --- settings, including Anki display
    settings.
-   `Views/StudyDayCompleteSheet.swift` --- end-of-day/add-more-cards
    UI.
-   `Support/AppStyle.swift` --- shared styling.

## Persistence map

Review progress:
`TrainingSessionViewModel -> ReviewPersisting -> ReviewRepository -> JSONFileStore -> review-memory.json`

Translations:
`TranslationViewModel -> TranslationRepository -> translations.json`

Anki library index/content:
`AnkiLibraryViewModel -> AnkiRepository -> JSONFileStore(anki-library.json) + imported package directories`

Caches have their own repositories. Do not introduce a second
persistence path without a clear reason.

## Concurrency / state conventions

-   UI/application state is generally `@MainActor` and uses Observation
    (`@Observable`).
-   Repository/cache implementations may be actors.
-   Heavy Anki archive parsing/hashing runs off MainActor.
-   Preserve actor/MainActor boundaries; do not add unsafe cross-actor
    access merely to silence compiler errors.

## Tests and verification

Useful commands: - App build:
`xcodebuild -project kanji_test.xcodeproj -scheme kanji_test -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build` -
Anki package tests: `swift test --package-path Packages/AnkiImport` -
App-hosted Anki/SRS integration tests:
`kanji_testHostedTests/AnkiStudyIntegrationTests.swift` via the
`kanji_test` test scheme on iOS Simulator.

When changing scheduling/queue behavior, add or update focused
integration/unit tests rather than relying only on UI testing.

## Change workflow

1.  Identify the user-visible subsystem from this map.
2.  Read the smallest relevant ViewModel/domain file(s).
3.  Follow only direct dependencies needed to explain the behavior.
4.  Make the smallest coherent change.
5.  Build and run the focused tests available for that subsystem.
6.  Fix compiler errors/warnings caused by the change; avoid unrelated
    cleanup.
7.  Summarize changed behavior and anything not verified.

## Guardrails

-   Do not rewrite architecture merely because another pattern is
    possible.
-   Do not change FSRS formulas casually.
-   Do not confuse queue policy with interval calculation.
-   Do not count only `readyIDs` when the UI means "remaining today".
-   Do not modify bundled datasets for unrelated work.
-   Preserve JSON backup/recovery behavior and Codable compatibility.
-   Preserve Anki import staging/validation/security boundaries.
-   Avoid duplicating card loading, scheduling, translation, rendering
    or stroke evaluation in views.
-   When requirements are ambiguous, infer from existing
    behavior/tests/code before inventing semantics.

## Large-file exclusion

`kanji_test/Data/word-data.json` is intentionally excluded from normal
agent exploration because its \~60k lines consume context without
helping most coding tasks. This is a **model-context rule**, not a Git
ignore rule: the file is required as an app resource and should remain
versioned unless the user explicitly decides otherwise.
