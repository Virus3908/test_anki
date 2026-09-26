# Custom deck practice — plan

Branch: `feature/custom-deck-training` (from `origin/main` @ 7c79d4a)

## Requirements (from user)

1. On a deck preview screen (e.g. kanji N5) the "start training" button becomes a
   split control: visually ONE oval, big left part = normal training, small right
   part = custom training entry.
2. Right part opens a card picker for that deck: user taps specific cards
   (multi-select), bottom has a Start button, then trains ONLY those cards.
3. The mini-training is ENDLESS: no day limits, no completion — runs until the
   user exits manually.
4. UNIVERSAL: works for built-in kanji, kana, word decks AND imported Anki decks.

## Strategy for the endless session (my design, to be validated against code)

- Queue = selected cards, shuffled.
- In-session Leitner-style loop: rating "again" → card returns after ~3 other
  cards; success → interval between its repetitions grows (box system). Queue
  never empties: when drained, refill (reshuffle) — endless rounds.
- NO persistence to review-memory.json / no FSRS side effects — custom practice
  must not disturb the normal SRS day queue. Ratings only reorder the in-session
  queue.
- HUD: answers count, correct %, current streak, round number.
- Exit: back button ends the session, show a small summary toast/sheet
  (answers, accuracy) — optional, keep minimal.

## Open questions (pending explore-agent reports)

- Unified card type for rendering across modes (StudyCard enum?) and catalog
  lookup API.
- Route registration mechanism (StudyNavigation) for two new screens:
  card picker + practice session.
- Whether TrainingView/TrainingSessionViewModel can be reused without SRS side
  effects, or a lightweight CustomPracticeViewModel + reused card renderers is
  cleaner (preferred: no duplication of card rendering, no persistence).
- How Anki deck preview exposes its card list for selection.

## Final UI approach (task #9: training-screen parity)

The custom practice screen now mirrors the SRS training screen instead of the
old compact preview layout. Shared view components were EXTRACTED from
TrainingView into `kanji_test/Views/TrainingDrawingPanels.swift` so both
screens render from one implementation:

- `TrainingRatingBar` — the four rating buttons (+ static `buttonColor`).
- `FeedbackInfoButton` — feedback info button + «Проверка» popover.
- `KanjiDrawingPanel<Controls>` — kanji/kana drawing panel (board, toolbar,
  no-stroke-order fallback, panel chrome). Panel-size math
  (`drawingPanelHeight`/`drawingBoardSide`) lives in the non-generic
  `TrainingDrawingPanelMetrics` enum so external call sites don't have to
  bind the generic `Controls` parameter.
- `WordDrawingPanel<Controls>` — word drawing panel (per-kanji advance icon).
- `CompletedWordStrip` — word kanji progress strip (plain data + tap callback).
- `TrainingHeaderView` — header (title/subtitle/finish/optional exclude).
- `CardContentRendering.kanjiCard(for:)` — kana→kanji card mapping.

TrainingView keeps its method names; `drawingPanel`, `kanaDrawingPanel`,
`wordDrawingPanel`, `completedWordStrip(for:)`, `reviewControls()` and
`headerControls()` now delegate to the shared structs.

`CustomTrainingView` keeps its own `CustomTrainingSession` (endless, no SRS
persistence) plus a private `DrawingSessionViewModel`. The drawing panels,
rating bar and word strip are bound to that drawing session; card flip, reveal
and rating enable/disable follow `drawingSession.isAnswerVisible`.
`submit(_:)` resets the drawing state after each answer (a single-card
requeue keeps the same card id, so reset is NOT tied to a card-id change).
Speech re-triggers per presented card via a token of card id + answers count.

Residual duplication (accepted): the flip-card shell and the card front shell
(`cardFrontShell` with footer/learning status) stay local to
`CustomTrainingView` because the training versions are bound to
TrainingView-specific state (swipe gesture, field-settings sheet placement);
their layout and strings match `trainingCardShell`/`studyCardFrontShell`.

## Status

- [x] Branch created from origin/main
- [x] 3 explore agents launched (deck preview/nav, card rendering, session/catalog)
- [x] Design finalized (CustomTrainingSession: Leitner boxes, no persistence,
      separate routes `.customCardPicker` / `.customTraining` behind
      `returnRoute`, card content rendering fully reused)
- [x] Implementation
      (`StudyNavigation`, `CustomTrainingSession`, `StudyAppViewModel+CustomTraining`,
      `CustomCardPickerView`, `CustomTrainingView`, split `previewStartButton`,
      wired into all 4 deck previews + `ContentView`)
- [x] Build + tests (`CustomTrainingSessionTests` — 10/10 pass, app builds)
- [x] Training-screen parity via shared `TrainingDrawingPanels` components
      (12 session tests, incl. selection-mode coverage)

