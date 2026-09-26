# Custom training UI parity (task #9) — source of truth

User request: «Сама тренировка должна быть такой же как по сути при обычной
тренировке (чтобы можно было рисовать, в целом интерфейс хотелось бы такой же)»
+ «по максимуму переиспользовал компоненты обычного training UI».
Keep context tight: read this file, not the whole repo.

## Architecture (decided)

CustomTrainingView keeps its own `CustomTrainingSession` (endless, no SRS
persistence) and a private `@State var drawingSession = DrawingSessionViewModel()`.
It must NOT reuse `TrainingSessionViewModel` (submit persists to SRS and
rebuilds via engine — would break the endless queue). Reuse happens at the
VIEW layer: the drawing panels / rating bar / word strip / headers are
extracted from TrainingView into shared structs used by both screens.

## New file: `kanji_test/Views/TrainingDrawingPanels.swift`

All `@MainActor`, `StudyViewStyling` where convenient. Xcode 16
file-sync groups: new files are auto-included in the target.

1. `struct TrainingRatingBar: View` — the rating row extracted from the
   second HStack of `reviewControls()` in `TrainingView+DrawingControls.swift`
   (keep that HStack's body verbatim: ForEach(ReviewRating.allCases),
   caption.bold title, optional interval caption2, minHeight 30,
   .borderedProminent, .controlSize(.small), disabled(!isAnswerVisible || isPreparingCard)).
   Props: `isAnswerVisible: Bool`, `isPreparingCard: Bool = false`,
   `intervalLabel: (ReviewRating) -> String = { _ in "" }`,
   `onRate: (ReviewRating) -> Void`.
   Add `static func buttonColor(for rating: ReviewRating) -> Color` moved from
   `ratingButtonColor(for:hasFeedback:isAnswered:)` colorful branch
   (again=correction, hard=warning, good=success, easy=accent; muted otherwise).

2. `struct KanjiDrawingPanel<Controls: View>: View` — extracted from
   `drawingPanel(for:panelHeight:)` in `TrainingView+KanjiDrawingPanel.swift`
   (the kana panel in `TrainingView+KanaDrawingPanel.swift` is the same shape —
   after extraction both delegate here with `expectedCard = kanjiCard(for:)`).
   Props: `drawingSession`, `expectedCard: KanjiCard`, `panelHeight: CGFloat`,
   `isGuided: Bool = false`, `onStrokeFinished: () -> Void`,
   `onReveal: () -> Void` (no-strokes «Ответ» button), `onAdvance: () -> Void`
   (check button), `@ViewBuilder controls: () -> Controls`.
   - body: `@Bindable var drawingSession` wrapper; boardSide computed with the
     hasStrokeOrder−48 rule; DrawingBoard bound to drawnStrokes/currentStroke,
     expectedStrokes = `drawingSession.expectedStrokes(for: expectedCard, isGuided: isGuided)`,
     feedback, onStrokeFinished.
   - toolbar: trash / feedback info / undo / checkmark — READ
     `TrainingView+DrawingLogic.swift` wrappers first: if they are pure
     forwards to DrawingSessionViewModel, call the session directly;
     otherwise take closures. Extract the feedback info button + popover
     (from `feedbackInfoButton`/`feedbackInfoPopover` in +DrawingControls.swift)
     into a shared `struct FeedbackInfoButton: View` (items + binding).
   - keep the no-strokes fallback row verbatim
     («Для этого кандзи нет образца черт. Оцените ответ самостоятельно.» + «Ответ»).
   - controls() at the bottom, panel chrome (height/padding/surface/top border) verbatim.
   - move `drawingPanelHeight(for:)` and `drawingBoardSide(for:)` here as
     static funcs; delete from `TrainingView+DrawingControls.swift`.

3. `struct WordDrawingPanel<Controls: View>: View` — extracted from
   `TrainingView+WordDrawingPanel.swift` (read it + `+WordDrawingLogic.swift`):
   same chrome, board uses `drawingSession.expectedWordStrokes(...)` /
   `currentWordFeedback` / `advanceWordKanjiOrCheck` equivalents. The advance
   button icon logic: index < wordCard.kanjiCards.count - 1 ?
   "arrow.right.circle.fill" : "checkmark.circle.fill".

4. `struct CompletedWordStrip: View` — extracted `completedWordStrip(for:)` +
   `completedWordItems` from `TrainingView+WordTraining.swift`; plain data +
   `onSelectKanji(at:)` callback props.

5. Move `kanjiCard(for kanaCard:)` (Kana→KanjiCard mapping) from
   `TrainingView+DrawingLogic.swift` to a `CardContentRendering` extension —
   both screens need it.

## TrainingView refactor (keep ALL method names + call sites)

- `drawingPanel`, kana panel, `wordDrawingPanel`, `completedWordStrip(for:)`
  bodies delegate to the shared structs.
- `reviewControls()`: keep the first HStack (undo / guided nav / answer label —
  TrainingView-specific), replace the rating HStack with `TrainingRatingBar`.
- Delete moved helpers from `TrainingView+DrawingControls.swift`.
- `TrainingHeaderView` (private in `TrainingView+TrainingHeader.swift`):
  make it internal in the new shared file, generalize props so the custom
  screen can show its own stats subtitle; TrainingView constructs it as before.

## CustomTrainingView rewrite (`kanji_test/Views/CustomTrainingView.swift`)

Keep the public initializer used by ContentView.swift:
(session:settings:translationState:coordinator:reviewStore:onExit:).
Keep deckID/practiceMode/speech/field-settings states; ADD
`@State var drawingSession = DrawingSessionViewModel()` (verify init signature
in `ViewModels/DrawingSessionViewModel.swift`).

Body while `session.isRunning` mirrors `TrainingView+Layout.swift`
trainingView/wordTrainingView structure: GeometryReader → panelHeight →
ZStack { background; VStack(spacing: 0) { ScrollView { header; cardArea } ;
drawingArea(panelHeight) } }.

- header: shared TrainingHeaderView; title = deck title; subtitle =
  «Круг N · Ответов N · Точность X% · Серия N»; finish button → onExit.
- card area per mode:
  - kanji/kana/words: the existing flip-card shell (front/back ScrollViews,
    rotation3D, appSurfaceCard, tap to flip) but bound to
    `drawingSession.isAnswerVisible` instead of `session.isAnswerVisible`.
    Front shell: extend the local `cardFrontShell` with `footerText` +
    `learningStatusLabel(forReviewKey:)` parity with `studyCardFrontShell`
    in `TrainingView+CardTemplate.swift` (extract to a shared struct ONLY if
    bindings stay clean; otherwise keep the local shell and note the residual
    duplication in docs).
  - anki: `AnkiCardContentView(card:answer: drawingSession.isAnswerVisible, ...)`
    + reveal-toggle button + TrainingRatingBar wrapped in appSurfaceCard,
    like `TrainingView+AnkiTraining.swift` (no drawing, no auto-speech).
- drawingArea per mode:
  - kanji → KanjiDrawingPanel(expectedCard: currentKanjiCard, controls: rating)
  - kana → KanjiDrawingPanel(expectedCard: kanjiCard(for: currentKanaCard))
  - words → WordDrawingPanel + CompletedWordStrip overlay
    (.padding(.bottom, panelHeight + 10).zIndex(2)) with
    `drawingSession.selectWordKanji(at:in:)`.
- rating: `TrainingRatingBar(isAnswerVisible: drawingSession.isAnswerVisible,
  intervalLabel: { _ in "" }) { submit($0) }` (no intervals in custom mode).
- `submit(_:)`: speech.stop(); withAnimation(.easeInOut(duration: 0.24))
  { session.submit(rating) }; then `drawingSession.resetCurrentAnswer()` +
  `drawingSession.resetWordDrawingState(resetKanjiIndex: true)`
  (verify exact signatures; single-card endless requeue keeps the same id —
  do NOT rely on onChange(of: currentID) for the reset).
- local thin wrappers (isGuided always false):
  `revealDrawingAnswer()`, `advanceStrokeOrReveal(card)`,
  word equivalents — see `TrainingView+GuidedDrawingLogic.swift` and
  `+WordDrawingLogic.swift` for the exact wrapper shape.
- speech: `.task(id: token)` where token combines current card id +
  `session.answersCount` so each newly presented card speaks (incl. requeue);
  guard settings.speechEnabled; skip for anki (same as training view).
- keep applySpeechSettings/onDisappear{speech.stop()}/stoppedView as now.

## Verification / guardrails

- Build: `xcodebuild -project kanji_test.xcodeproj -scheme kanji_test -sdk
  iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build` (grep
  "error:|BUILD").
- `kanji_testHostedTests/CustomTrainingSessionTests.swift` (10 tests) must
  stay green; add isSelecting/toggle/setSelection/cancelSelection coverage.
- Update `docs/custom-training-plan.md` with the final UI approach.
- DO NOT commit; DO NOT touch/commit `kanji_test.xcodeproj/project.pbxproj`
  (local uncommitted signing changes must stay uncommitted).
- Don't rewrite unrelated TrainingView behavior; panels move, not change.
