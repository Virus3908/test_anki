import SwiftUI

/// Контент карточки обратной тренировки, нормализованный по типам контента
/// (кандзи/слова/кана). Компоненты ниже не знают о сессии и тренировке —
/// фронт самодостаточен, ответы уходят наружу через `onRate`.
struct RecallCardContent: Equatable, Sendable {
    let cardID: String
    let type: TrainingCardType
    /// Кандзи/слово/кана — то, что показываем и озвучиваем.
    let promptText: String
    /// Чтение рядом с промптом; для каны это ответ, поэтому не подсказываем.
    let reading: String?
    /// Значения карточки — эталон для проверки ввода и теста.
    let targetMeanings: [String]

    var speechText: String { promptText }
    var expectedAnswer: String { targetMeanings.joined(separator: " / ") }
}

extension RecallCardContent {
    init(card: KanjiCard, type: TrainingCardType) {
        let readings = (card.onyomi + card.kunyomi).filter { !$0.isEmpty }
        self.init(
            cardID: card.id,
            type: type,
            promptText: card.kanji,
            reading: readings.isEmpty ? nil : readings.joined(separator: ", "),
            targetMeanings: card.meanings
        )
    }

    init(card: WordStudyCard, type: TrainingCardType) {
        self.init(
            cardID: card.id,
            type: type,
            promptText: card.word,
            reading: card.reading.isEmpty ? nil : card.reading,
            targetMeanings: [card.meaning]
        )
    }

    /// Для каны чтение — это и есть ответ, поэтому на фронт не подсказываем.
    init(card: KanaStudyCard, type: TrainingCardType) {
        self.init(
            cardID: card.id,
            type: type,
            promptText: card.character,
            reading: nil,
            targetMeanings: [card.reading]
        )
    }
}

/// Фронт «вспомни значение»: крупный символ, чтение, озвучка.
struct RecallCardFront: View {
    let content: RecallCardContent
    let onSpeak: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RecallCardHeader(title: "Вспомни значение", onSpeak: onSpeak)
            promptPanel
            if let reading = content.reading {
                Text(reading)
                    .font(.title3)
                    .foregroundStyle(AppPalette.secondaryText)
            }
        }
    }

    private var promptPanel: some View {
        Text(content.promptText)
            .font(.system(size: 64, weight: .regular, design: .serif))
            .minimumScaleFactor(0.35)
            .lineLimit(1)
            .foregroundStyle(AppPalette.text)
            .padding(.horizontal, 20)
            .padding(.vertical, 26)
            .frame(minWidth: 112, minHeight: 96, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(AppPalette.surface)
            .border(AppPalette.border.opacity(0.65))
    }
}

/// Фронт «на слух»: только звук; текст — запасной вариант без озвучки.
struct RecallAudioFront: View {
    let content: RecallCardContent
    let isSpeechAvailable: Bool
    let onReplay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RecallCardHeader(title: "Прослушай и вспомни значение", onSpeak: onReplay)
            if isSpeechAvailable {
                replayButton
            } else {
                Text(content.promptText)
                    .font(.system(size: 64, weight: .regular, design: .serif))
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)
                    .foregroundStyle(AppPalette.text)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 26)
                    .frame(minWidth: 112, minHeight: 96, alignment: .center)
                    .frame(maxWidth: .infinity)
                    .background(AppPalette.surface)
                    .border(AppPalette.border.opacity(0.65))
            }
        }
    }

    private var replayButton: some View {
        Button(action: onReplay) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(AppPalette.text)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 148)
                .background(AppPalette.surface)
                .border(AppPalette.border.opacity(0.65))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Training.speak)
        .accessibilityLabel("Прослушать")
    }
}

/// Заголовок карточки + кнопка озвучки.
private struct RecallCardHeader: View {
    let title: String
    let onSpeak: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
            Spacer()
            CardHeaderActionButton(
                title: "Озвучить",
                systemImage: "speaker.wave.2.fill",
                accessibilityIdentifier: AccessibilityID.Training.speak,
                action: onSpeak
            )
        }
    }
}

/// Тест: вертикальные кнопки со значениями; после тапа — подсветка
/// верно/неверно и авто-переход.
struct RecallChoicePanel: View {
    let options: [String]
    let correctOption: String
    let onRate: (ReviewRating) -> Void

    @State private var selectedOption: String?
    @State private var appearedAt = Date()

    /// Время на уверенный ответ; дольше — «трудно».
    private static let confidentAnswerInterval: TimeInterval = 8
    /// Пауза с подсветкой до перехода к следующей карточке.
    private static let revealDelay: Duration = .seconds(1.2)

    var body: some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                optionButton(option)
            }
        }
    }

    private func optionButton(_ option: String) -> some View {
        Button {
            pick(option)
        } label: {
            Text(option)
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .foregroundStyle(optionForeground(option))
                .background(optionBackground(option))
        }
        .buttonStyle(.plain)
        .disabled(selectedOption != nil)
        .accessibilityIdentifier(AccessibilityID.Training.choiceOption)
    }

    private func pick(_ option: String) {
        guard selectedOption == nil else { return }
        selectedOption = option
        let rating = rating(for: option)
        Task {
            try? await Task.sleep(for: Self.revealDelay)
            onRate(rating)
        }
    }

    private func rating(for option: String) -> ReviewRating {
        guard option == correctOption else { return .again }
        return abs(appearedAt.timeIntervalSinceNow) <= Self.confidentAnswerInterval ? .good : .hard
    }

    private func optionForeground(_ option: String) -> Color {
        guard selectedOption != nil else { return AppPalette.text }
        return option == correctOption ? AppPalette.success : AppPalette.text
    }

    private func optionBackground(_ option: String) -> Color {
        guard let selectedOption else { return AppPalette.surface }
        if option == correctOption { return AppPalette.success.opacity(0.25) }
        return option == selectedOption ? AppPalette.correction.opacity(0.3) : AppPalette.surface
    }
}

/// Ввод значения: свободный ответ, нечёткая проверка, подтверждение при
/// почти-совпадении.
struct RecallTypedPanel: View {
    let content: RecallCardContent
    let onRate: (ReviewRating) -> Void

    @State private var input = ""
    @State private var phase: Phase = .answering
    @FocusState private var isInputFocused: Bool

    enum Phase: Equatable {
        case answering
        /// Ввод близок к правильному — просим подтвердить.
        case confirming(input: String)
        /// Ответ дан или «не помню» — показываем эталон и уходим дальше.
        case revealed(isCorrect: Bool)
    }

    /// Пауза с показанным эталоном до перехода к следующей карточке.
    private static let revealDelay: Duration = .seconds(1.6)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch phase {
            case .answering:
                TextField("Значение", text: $input)
                    .focused($isInputFocused)
                    .submitLabel(.done)
                    .onSubmit(answer)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .foregroundStyle(AppPalette.text)
                    .background(AppPalette.surface)
                    .border(AppPalette.border.opacity(0.65))
                    .accessibilityIdentifier(AccessibilityID.Training.typedField)
                HStack(spacing: 12) {
                    Button("Ответить", action: answer)
                        .buttonStyle(.borderedProminent)
                        .disabled(trimmedInput.isEmpty)
                        .accessibilityIdentifier(AccessibilityID.Training.typedSubmit)
                    Button("Не помню", action: giveUp)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(AccessibilityID.Training.typedDontKnow)
                }
            case .confirming(let typed):
                comparison(title: "Проверь себя", typed: typed)
                HStack(spacing: 12) {
                    Button("Верно") {
                        onRate(.good)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(AccessibilityID.Training.typedConfirmCorrect)
                    Button("Неверно") {
                        phase = .revealed(isCorrect: false)
                        submitAfterDelay(.again, .seconds(1.2))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(AccessibilityID.Training.typedConfirmWrong)
                }
            case .revealed(let isCorrect):
                VStack(alignment: .leading, spacing: 6) {
                    Text(isCorrect ? "Верно" : "Ответ")
                        .font(.headline)
                        .foregroundStyle(isCorrect ? AppPalette.success : AppPalette.correction)
                    Text(content.expectedAnswer)
                        .font(.body)
                        .foregroundStyle(AppPalette.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func comparison(title: String, typed: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.warning)
            Text("Твой ввод: \(typed)")
                .font(.body)
                .foregroundStyle(AppPalette.text)
            Text("Ожидание: \(content.expectedAnswer)")
                .font(.body)
                .foregroundStyle(AppPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func answer() {
        guard phase == .answering, !trimmedInput.isEmpty else { return }
        switch MeaningMatcher.outcome(for: trimmedInput, meanings: content.targetMeanings) {
        case .exact:
            phase = .revealed(isCorrect: true)
            submitAfterDelay(.good, .seconds(0.8))
        case .nearMiss:
            phase = .confirming(input: trimmedInput)
        case .none:
            phase = .revealed(isCorrect: false)
            submitAfterDelay(.again, Self.revealDelay)
        }
    }

    private func giveUp() {
        guard phase == .answering else { return }
        phase = .revealed(isCorrect: false)
        submitAfterDelay(.again, Self.revealDelay)
    }

    private func submitAfterDelay(_ rating: ReviewRating, _ delay: Duration) {
        Task {
            try? await Task.sleep(for: delay)
            onRate(rating)
        }
    }
}
