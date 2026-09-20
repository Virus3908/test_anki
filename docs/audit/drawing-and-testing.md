# Audit: Drawing subsystem, tests and configuration

Phase 2 (AUDIT) findings. Read-only pass; no source was modified.
Baseline verified: `swift test --package-path Packages/AnkiImport` passes
(14 XCTest cases + 1 swift-testing suite with 0 tests).

Line numbers verified by reading at audit time.

---

# Drawing

## DRAW-01 — unchecked array subscripts on network-sourced stroke data
**critical** — `kanji_test/Models/KanjiStroke.swift:28,32`

`startPoint`/`endPoint` index `start[0]`, `start[1]`, `end[0]`, `end[1]`
directly. `KanjiStroke` is `Codable` and stroke geometry reaches the app
through `KanjiAPIProvider+Mapping.swift:10` and the on-disk cache decoded at
`kanji_test/Data/KanjiDeckCacheRepository.swift:15`. `kanji_test/Data/kanji-data.json`
is 3 bytes (`[]`), so **all** kanji stroke content is remote or cached —
there is no bundled fallback. A short `start`/`end` array from a changed API
response or a truncated cache file traps at runtime.

Cost: **correctness** (crash on untrusted input) and **security** (remote
input controls an index). The decode boundary does not validate arity.

## DRAW-02 — `StrokeEvaluator` has zero tests despite owning all matching policy
**critical** — `kanji_test/Drawing/StrokeFeedback.swift:4`

`StrokeEvaluator` is the entire correctness core of the drawing feature and is
referenced from three places (`DrawingSessionViewModel.swift:81,90,194`). No
test file instantiates it (verified: `StrokeEvaluator` appears nowhere in
`kanji_testHostedTests/`). Every tolerance below could be changed to an
arbitrary value and the suite would stay green.

Cost: **testability** and **correctness** — the tuning constants in DRAW-03
are unprotected, so any future adjustment is unfalsifiable.

## DRAW-03 — unnamed tuning constants scattered through stroke matching
**major** — `kanji_test/Drawing/StrokeFeedback.swift:113,117,131`

The scoring thresholds are bare literals inside the comparison logic:
`34` (good/degraded distance cutoff, `:113`), `54` (minor-vs-major cutoff,
`:117`), and `18`/`24` (the width/height gate that classifies a stroke's
axis, `:131`). They are in canonical stroke units — `DrawingBoard.swift:15` scales by
`size.width / canonicalSize`, so the numbers only make sense relative to
`canonicalSize`, which is not stated at the point of use.

These are a coherent set of tuning parameters for one algorithm and belong in
one named place next to the evaluator.

Cost: **maintainability** — tuning requires reading the whole function to find
every coupled literal; **correctness** — the implicit coordinate-space
contract is undocumented, so a change to `canonicalSize` silently invalidates
all four values.

## DRAW-04 — kanji and kana drawing panels are byte-identical
**major** — `kanji_test/Views/TrainingView+KanjiDrawingPanel.swift` vs
`kanji_test/Views/TrainingView+KanaDrawingPanel.swift`

`diff` of the two files differs only in the card parameter type and
indentation; the view bodies are otherwise the same. `TrainingView+WordDrawingPanel.swift`
is a third near-copy with word-specific index handling.

Cost: **maintainability** — a fix to the drawing panel must be applied two to
three times, and drift between them is invisible without diffing.

## DRAW-05 — verbatim duplicated SVG tokenizer
**major** — `kanji_test/Drawing/SVGPathParser.swift:76` and
`kanji_test/Drawing/SVGStrokeExtractor.swift`

The `segments(in:)` tokenizer, the number scanner and the token-append helper
exist in identical form in both files. Two copies of the same hand-rolled
parser will diverge.

Cost: **maintainability**, and **correctness** if only one copy is fixed.

## DRAW-06 — SVG parser silently drops unsupported path commands
**major** — `kanji_test/Drawing/SVGPathParser.swift:68`

The `switch` at `:33` handles only `M m L l C c`. The `default` case at `:68`
discards anything else with no diagnostic. Real KanjiVG-style path data uses
`S`, `s`, `Q`, `q`, `T`, `t`, `A`, `a`, `H`, `h`, `V`, `v` and `Z`. Malformed
or merely unsupported input produces a silently incomplete path rather than an
error, and `summarize(pathData:)` at `SVGStrokeExtractor.swift:36` returns
`nil` on failure with the reason discarded.

Cost: **correctness** — strokes render and are scored against geometry that
partially parsed; **maintainability** — a swallowed error gives no signal
about which glyph failed.

## DRAW-07 — six dead forwarding functions
**minor** — `kanji_test/Views/TrainingView+GuidedDrawingLogic.swift:4,19`;
`kanji_test/Views/TrainingView+WordDrawingLogic.swift:19,23,27,39`

`guidedExpectedStrokes(for:)`, `nextGuidedStrokeLimit(for:)`,
`saveCurrentWordDrawing()`, `evaluateWordParts(_:)`,
`flattenedWordFeedback(for:)` and `storeCurrentWordFeedback(_:in:)` have no
references outside their own definitions. Each is a one-line forward to
`DrawingSessionViewModel`.

(`selectWordKanji(at:in:)` at `TrainingView+WordDrawingLogic.swift:11` is
still referenced and is not dead.)

Cost: **maintainability** — dead indirection inflates the apparent API of the
view layer and misleads readers about where drawing logic lives.

## DRAW-08 — `drawGuides` duplicated across two Canvas views
**minor** — `kanji_test/Drawing/DrawingBoard.swift:126` and
`kanji_test/Drawing/StrokeStepStrip.swift:52`

Two private copies of the same guide-drawing routine.

Cost: **maintainability** — guide appearance can drift between the main board
and the step strip.

## DRAW-09 — repeated unnamed layout literals in the step strip
**minor** — `kanji_test/Drawing/StrokeStepStrip.swift:9,17`

The cell size `41` is repeated three times across `GridItem(.adaptive(minimum:maximum:))`
and `.frame(width:height:)`, with `2.2`/`2.4` line widths duplicated between
`StrokeStepStrip.swift:38` and `DrawingBoard.swift:27,31`.

Cost: **maintainability** — a sizing change must be made in several places to
stay consistent.

---

# Tests-and-Config

## CFG-01 — no CI whatsoever
**critical** — repository root

No `.github/`, no `fastlane/`, no `Makefile`, no `scripts/`, no
`.gitlab-ci.yml`. Nothing runs the build or either test suite
automatically. The documented commands in `AGENTS.md` are manual-only.

Cost: **correctness** — regressions reach `main` undetected; the existing
good tests (see CFG-06) provide value only when someone remembers to run
them. This is the single highest-leverage gap in the whole audit.

## CFG-02 — app test suite covers a small slice of ~12.7k lines of app Swift
**critical** — `kanji_testHostedTests/`

Four files, 28 test functions, 110 assertions total. By types actually
instantiated, the tests reach `StudyProgressStore`, `AnkiSchedulingMigrator`,
`TrainingSessionViewModel`, `StudyCardCatalog`, `TrainingSessionEngine`,
`DrawingSessionViewModel`, `AnkiLibraryViewModel` and `StudyScheduler` (once).
Everything else is untested — see the coverage table.

Cost: **testability** and **correctness** — whole subsystems including all
persistence, all networking, translation and TTS can break silently.

## CFG-03 — shared scheme references a target that does not exist
**major** — `kanji_test.xcodeproj/xcshareddata/xcschemes/kanji_testUnitTests.xcscheme:23`

The scheme declares a testable `kanji_testUnitTests.xctest`. The string
`kanji_testUnitTests` appears **zero** times in `project.pbxproj` and no
`kanji_testUnitTests/` directory exists. The scheme is stale and will fail if
selected.

Cost: **maintainability** — a broken checked-in scheme is a trap for CI setup
(CFG-01) and for new contributors.

## CFG-04 — two conflicting DEVELOPMENT_TEAM values in one project file
**major** — `kanji_test.xcodeproj/project.pbxproj:247,313` (`56X328PYCN`) vs
`:343,376` (`A24JC9X7D2`)

The app target and the test target are signed against different teams.
Bundle identifiers also diverge in style: `com.sashapin.kanjI-test` (`:357`,
note the stray capital `I`) versus `com.lomach.kanji-test.integration-tests`
(`:407`) — two unrelated reverse-domain prefixes.

Cost: **maintainability** — signing breaks per-machine depending on which
team the developer belongs to; the typo'd identifier is baked into the
shipping app.

## CFG-05 — contradictory orientation configuration
**major** — `kanji_test/App/kanji_testApp.swift` (AppDelegate orientation lock)
vs `project.pbxproj:350,351,383,384`

The `AppDelegate` pins supported orientations to portrait while
`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` and `_iPad` declare
landscape variants. Two sources of truth disagree; the code wins at runtime
and the declared capability is a lie.

Cost: **maintainability** — the build setting suggests landscape is
supported, so a future change to the AppDelegate silently ships an untested
landscape layout.

## CFG-06 — `SWIFT_VERSION = 5.0` on all app targets while the package is on tools 6.0
**major** — `project.pbxproj:364,397,409,422` vs
`Packages/AnkiImport/Package.swift:1`

The app compiles in Swift 5 language mode; the local package declares
`swift-tools-version: 6.0`. `SWIFT_STRICT_CONCURRENCY` is not set anywhere in
the project file. `AGENTS.md` documents careful `@MainActor`/actor boundaries,
but nothing enforces them on the app side — only
`SWIFT_APPROACHABLE_CONCURRENCY = YES` (`:360`) and
`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` (`:363`) are enabled, and
only on one configuration pair.

Cost: **correctness** — the concurrency invariants the architecture depends on
are unchecked by the compiler; **maintainability** — the app/package language
split means package code cannot be moved into the app without new errors.

## CFG-07 — warnings are not errors anywhere
**minor** — `project.pbxproj` (no `SWIFT_TREAT_WARNINGS_AS_ERRORS`, no
`GCC_TREAT_WARNINGS_AS_ERRORS`)

Neither setting appears in the file. Combined with no CI (CFG-01), warnings
accumulate unobserved.

Cost: **maintainability** — the compiler's own dead-code and unused-value
diagnostics, which would have flagged DRAW-07, are advisory only.

## CFG-08 — `IPHONEOS_DEPLOYMENT_TARGET = 26.5` excludes the package's stated floor
**minor** — `project.pbxproj:265,325` vs `Packages/AnkiImport/Package.swift:5`

The app requires iOS 26.5 while the package advertises `.iOS(.v17)`. The
package's platform floor is therefore untested and misleading.

Cost: **maintainability** — the package manifest implies portability the app
never exercises.

## CFG-09 — `.build` is correctly ignored (no defect)
**minor / informational** — `.gitignore`

`git check-ignore` confirms `Packages/AnkiImport/.build/` is matched, and
`git ls-files` reports zero tracked paths under `.build/`. The vendored
checkouts on disk are local artifacts only. **No action needed** — recorded
because it was explicitly in scope.

## Coverage table

| Subsystem | ~Lines | Test files touching it | Verdict |
|---|---|---|---|
| Anki import/parsing (`Packages/AnkiImport`) | ~3.6k | `AnkiImportTests.swift`, `AnkiWebRenderingTests.swift` (335 lines, 14 cases) | adequate |
| Anki study/SRS integration | ~1.5k | `AnkiStudyIntegrationTests.swift` (11 cases, 62 asserts) | adequate |
| Card search | — | `CardSearchTests.swift` (12 cases, 31 asserts) | adequate |
| Training queue/engine | ~800 | `TrainingSessionEngineTests.swift` (2 cases, 8 asserts) | thin |
| Drawing session orchestration | ~235 | `DrawingSessionViewModelTests.swift` (3 cases, 9 asserts) | thin |
| `StrokeEvaluator` / stroke scoring | ~150 | — | **none** |
| SVG parsing + stroke extraction | ~284 | — | **none** |
| Kana stroke presets | ~263 | — | **none** |
| `StudyScheduler` (FSRS adapter) | — | referenced once, incidentally | **none** (no direct interval tests) |
| Persistence: `JSONFileStore`, `ReviewRepository` | — | — | **none** |
| Translation subsystem + `TranslationRepository` | ~600 | — | **none** |
| Remote kanji provider / API mapping | ~400 | — | **none** |
| Caches (`KanjiDeckCache`, `KanaSVGCache`, `WordExampleCache`) | — | — | **none** |
| Speech / TTS (`SpeechService`) | — | — | **none** |
| `AnkiCardRenderer`, `AnkiMediaService`, `AnkiAudioPlayback` | — | — | **none** |
| Word/kanji/kana data loaders | — | — | **none** |
| All SwiftUI views | ~4k | — | none (acceptable) |

### Subsystems with literally zero coverage

`StrokeEvaluator`; SVG parsing/extraction; kana stroke presets;
`StudyScheduler` intervals; `JSONFileStore`; `ReviewRepository`; translation
(`TranslationViewModel`, `TranslationRepository`,
`RussianMeaningTranslator`, `SystemTranslationClient`); remote kanji
(`RemoteKanjiProvider`, `KanjiAPIProvider+Loading/+Mapping`); all three cache
repositories; `SpeechService`; `AnkiCardRenderer`; `AnkiMediaService`;
`AnkiAudioPlayback`; `AnkiSchedulingMigrator` beyond its integration path;
data loaders.

## Test quality note

The tests that exist are **good** and this should be said plainly: they are
behavioral, not smoke tests. `DrawingSessionViewModelTests` asserts
progressive stroke reveal and kanji advancement with real expected values;
`AnkiStudyIntegrationTests` averages ~5.6 assertions per case. No `sleep`
calls, no assertion-free tests, no obvious order dependence or shared mutable
fixtures were found. They would fail if the code under test were deleted.

The problem is **breadth, not depth**. The existing suite is a good template
to extend, not something to rewrite.

## Uncommitted `project.pbxproj` change

`git diff --stat` shows the working-tree modification is confined to
`project.pbxproj`. It registers the new speech files
(`Services/Speech/SpeechService.swift` and the related training/settings wiring)
into the app target's build phase and file references — the membership
bookkeeping for the already-committed speech feature described in `AGENTS.md`.
It changes no build settings, no signing, no deployment target. It should be
committed as-is; leaving it uncommitted means the speech feature's target
membership exists only on this machine.

## What good looks like here

This is a single-developer hobby-scale app. Full TDD would be wrong. A
realistic minimum:

1. **CI that runs what already exists.** One GitHub Actions workflow on push:
   `swift test --package-path Packages/AnkiImport` plus the documented
   `xcodebuild` build. That alone converts the existing 28 app tests and 14
   package tests from "run when remembered" to a real gate. Highest value,
   near-zero risk.
2. **Pure-logic tests only, and only where a bug would be silent.** Stroke
   scoring, SVG parsing, and FSRS interval calculation are deterministic
   functions with no UI or I/O — they are cheap to test and currently
   unprotected. Characterization tests here (pin current behavior, including
   quirks) are the prerequisite for touching DRAW-03.
3. **No view tests.** Snapshot/UI testing at this scale costs more than it
   returns. The ~4k lines of SwiftUI views are acceptably untested provided
   logic keeps moving out of them (DRAW-07 shows the pattern is already
   understood).
4. **Warnings as errors, once the existing warnings are cleared.** Cheap
   permanent guard against the dead-code class of defect.
5. **One source of truth per setting.** Resolve CFG-04 and CFG-05 rather than
   documenting the contradiction.

Explicitly *not* recommended for this project: dependency-injection
frameworks, mocking libraries, coverage thresholds, or a test-per-file
convention. The architecture in `AGENTS.md` is already sound; the gap is
enforcement, not design.
