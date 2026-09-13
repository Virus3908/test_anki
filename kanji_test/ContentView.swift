import SwiftUI

private let canonicalSize: CGFloat = 109

private enum AppPalette {
    static let background = Color(red: 0.95, green: 0.94, blue: 0.90)
    static let surface = Color.white
    static let text = Color(red: 0.12, green: 0.11, blue: 0.09)
    static let secondaryText = Color(red: 0.42, green: 0.38, blue: 0.32)
    static let border = Color(red: 0.68, green: 0.64, blue: 0.56)
    static let ink = Color(red: 0.12, green: 0.16, blue: 0.17)
    static let accent = Color(red: 0.14, green: 0.36, blue: 0.39)
    static let correction = Color(red: 0.74, green: 0.12, blue: 0.14)
}

struct ContentView: View {
    @State private var cards = KanjiDataLoader.loadLocalCards()
    @State private var selectedDeck: KanjiDeck = .jlpt5
    @State private var isLoadingRemoteCards = false

    @State private var currentIndex = 0
    @State private var drawnStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var feedback: [String] = []
    @State private var isAnswerVisible = false

    var body: some View {
        NavigationStack {
            if let card = cards[safe: currentIndex] {
                ZStack {
                    AppPalette.background
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            headerControls()

                            if isLoadingRemoteCards {
                                ProgressView("Загружаю кандзи из интернета")
                                    .font(.footnote)
                                    .foregroundStyle(AppPalette.secondaryText)
                                    .tint(AppPalette.accent)
                            }

                            studyCard(for: card)

                            if !feedback.isEmpty {
                                section("Проверка") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(feedback.indices, id: \.self) { index in
                                            Text("\(index + 1). \(feedback[index])")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 220)
                        .foregroundStyle(AppPalette.text)
                    }
                    .background(AppPalette.background)
                }
                .safeAreaInset(edge: .bottom) {
                    drawingPanel(for: card)
                }
                .navigationTitle("Kanji Trainer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppPalette.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
                .task {
                    await loadRemoteCards()
                }
                .onChange(of: selectedDeck) {
                    Task {
                        await loadRemoteCards()
                    }
                }
            } else {
                ContentUnavailableView("Нет карточек", systemImage: "character.book.closed", description: Text("Проверь kanji-data.json в bundle приложения."))
                    .foregroundStyle(AppPalette.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppPalette.background.ignoresSafeArea())
            }
        }
    }

    private func headerControls() -> some View {
        HStack(spacing: 12) {
            Picker("Словарь", selection: $selectedDeck) {
                ForEach(KanjiDeck.allCases) { deck in
                    Text(deck.title).tag(deck)
                }
            }
            .pickerStyle(.menu)
            .tint(AppPalette.accent)

            Spacer()

            Button("", systemImage: "chevron.left") {
                moveToPreviousCard()
            }
            .disabled(currentIndex == 0)

            Text("\(currentIndex + 1) / \(cards.count)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.secondaryText)
                .frame(minWidth: 56)

            Button("", systemImage: "chevron.right") {
                moveToNextCard()
            }
            .disabled(currentIndex >= cards.count - 1)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }

    private func studyCard(for card: KanjiCard) -> some View {
        ZStack {
            cardFront(for: card)
                .opacity(isAnswerVisible ? 0 : 1)
                .rotation3DEffect(.degrees(isAnswerVisible ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            cardBack(for: card)
                .opacity(isAnswerVisible ? 1 : 0)
                .rotation3DEffect(.degrees(isAnswerVisible ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.24)) {
                isAnswerVisible.toggle()
            }
        }
    }

    private func cardFront(for card: KanjiCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Значение")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            Text(card.meanings.joined(separator: ", "))
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 16)

            Text("Нарисуй кандзи в правильном порядке черт.")
                .foregroundStyle(AppPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func cardBack(for card: KanjiCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 18) {
                    Text(card.kanji)
                        .font(.system(size: 82, weight: .regular, design: .serif))
                        .frame(width: 112, height: 112)
                        .background(AppPalette.surface)
                        .border(AppPalette.border.opacity(0.65))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Кандзи")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppPalette.secondaryText)
                            .textCase(.uppercase)
                        Text(card.kanji)
                            .font(.title2.weight(.bold))
                        Text("Все значения: \(card.meanings.joined(separator: ", "))")
                        Text("Все онъёми: \(card.onyomi.joined(separator: ", "))")
                        Text("Все кунъёми: \(card.kunyomi.joined(separator: ", "))")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                if !card.examples.isEmpty {
                    section("Примеры") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(card.examples) { example in
                                Text("\(example.word) (\(example.reading)) — \(example.meaning)")
                            }
                        }
                    }
                }

                section("Правильный порядок") {
                    StrokeOrderView(strokes: card.strokes)
                        .frame(width: 260, height: 260)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func drawingPanel(for card: KanjiCard) -> some View {
        VStack(spacing: 12) {
            DrawingBoard(
                drawnStrokes: $drawnStrokes,
                currentStroke: $currentStroke
            )
            .frame(width: 190, height: 190)

            HStack(spacing: 14) {
                Button {
                    _ = drawnStrokes.popLast()
                    updateFeedback(for: card, reveal: false)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(drawnStrokes.isEmpty)

                Button {
                    resetCurrentAnswer()
                } label: {
                    Image(systemName: "trash")
                }

                Spacer(minLength: 24)

                Button {
                    updateFeedback(for: card, reveal: true)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.accent)
            .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(AppPalette.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppPalette.border.opacity(0.65))
                .frame(height: 1)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func loadRemoteCards() async {
        guard !isLoadingRemoteCards else {
            return
        }

        isLoadingRemoteCards = true
        let loadedCards = await KanjiDataLoader.loadCards(deck: selectedDeck)
        isLoadingRemoteCards = false

        guard !loadedCards.isEmpty else {
            return
        }

        cards = loadedCards
        currentIndex = 0
        resetCurrentAnswer()
    }

    private func moveToPreviousCard() {
        guard currentIndex > 0 else {
            return
        }

        currentIndex -= 1
        resetCurrentAnswer()
    }

    private func moveToNextCard() {
        guard currentIndex < cards.count - 1 else {
            return
        }

        currentIndex += 1
        resetCurrentAnswer()
    }

    private func resetCurrentAnswer() {
        drawnStrokes.removeAll()
        currentStroke.removeAll()
        feedback.removeAll()
        isAnswerVisible = false
    }

    private func updateFeedback(for card: KanjiCard, reveal: Bool) {
        feedback = StrokeEvaluator.evaluate(actual: drawnStrokes, expected: card.strokes)

        if reveal {
            withAnimation(.easeInOut(duration: 0.24)) {
                isAnswerVisible = true
            }
        }
    }
}

struct DrawingBoard: View {
    @Binding var drawnStrokes: [[CGPoint]]
    @Binding var currentStroke: [CGPoint]

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                drawGuides(in: &context, size: size)
                let scale = size.width / canonicalSize
                context.scaleBy(x: scale, y: scale)

                for stroke in drawnStrokes {
                    context.stroke(path(for: stroke), with: .color(AppPalette.ink), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                }

                context.stroke(path(for: currentStroke), with: .color(AppPalette.accent), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            }
            .background(AppPalette.surface)
            .border(AppPalette.border.opacity(0.65))
            .gesture(dragGesture(size: proxy.size))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if currentStroke.isEmpty {
                    currentStroke.append(normalized(value.startLocation, in: size))
                }

                currentStroke.append(normalized(value.location, in: size))
            }
            .onEnded { _ in
                if currentStroke.count > 2 {
                    drawnStrokes.append(simplified(currentStroke))
                }

                currentStroke.removeAll()
            }
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let side = max(size.width, 1)
        return CGPoint(
            x: min(max(point.x / side * canonicalSize, 0), canonicalSize),
            y: min(max(point.y / side * canonicalSize, 0), canonicalSize)
        )
    }

    private func simplified(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []

        for index in stride(from: 0, to: points.count, by: 3) {
            result.append(points[index])
        }

        if result.last != points.last, let last = points.last {
            result.append(last)
        }

        return result
    }

    private func path(for points: [CGPoint]) -> Path {
        var path = Path()

        guard let first = points.first else {
            return path
        }

        path.move(to: first)

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        return path
    }

    private func drawGuides(in context: inout GraphicsContext, size: CGSize) {
        var guides = Path()
        guides.move(to: CGPoint(x: size.width / 2, y: 0))
        guides.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        guides.move(to: CGPoint(x: 0, y: size.height / 2))
        guides.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(guides, with: .color(AppPalette.border.opacity(0.35)), lineWidth: 1)
    }
}

struct StrokeOrderView: View {
    let strokes: [KanjiStroke]

    var body: some View {
        Canvas { context, size in
            drawGuides(in: &context, size: size)
            let scale = min(size.width, size.height) / canonicalSize
            context.scaleBy(x: scale, y: scale)

            for stroke in strokes {
                context.stroke(SVGPathParser.path(from: stroke.pathData), with: .color(AppPalette.ink), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                context.draw(Text("\(stroke.order)").font(.caption.bold()).foregroundStyle(AppPalette.correction), at: CGPoint(x: stroke.startPoint.x - 4, y: stroke.startPoint.y - 7))
            }
        }
        .background(AppPalette.surface)
        .border(AppPalette.border.opacity(0.65))
    }

    private func drawGuides(in context: inout GraphicsContext, size: CGSize) {
        var guides = Path()
        guides.move(to: CGPoint(x: size.width / 2, y: 0))
        guides.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        guides.move(to: CGPoint(x: 0, y: size.height / 2))
        guides.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(guides, with: .color(AppPalette.border.opacity(0.35)), lineWidth: 1)
    }
}

enum StrokeEvaluator {
    static func evaluate(actual: [[CGPoint]], expected: [KanjiStroke]) -> [String] {
        guard !actual.isEmpty else {
            return ["Пока нет штрихов. Нарисуй кандзи, потом нажми «Проверить»."]
        }

        var messages: [String] = []

        if actual.count == expected.count {
            messages.append("Количество штрихов похоже на правильное.")
        } else {
            messages.append("Нужно \(expected.count) штриха, сейчас распознано \(actual.count).")
        }

        for (index, expectedStroke) in expected.enumerated() {
            guard index < actual.count else {
                messages.append("Штрих \(index + 1): не найден.")
                continue
            }

            messages.append("Штрих \(index + 1): \(evaluateStroke(actual[index], expected: expectedStroke))")
        }

        if actual.count > expected.count {
            messages.append("Есть лишние штрихи после \(expected.count)-го.")
        }

        return messages
    }

    private static func evaluateStroke(_ points: [CGPoint], expected: KanjiStroke) -> String {
        guard let start = points.first, let end = points.last else {
            return "не найден."
        }

        let forwardDistance = start.distance(to: expected.startPoint) + end.distance(to: expected.endPoint)
        let reverseDistance = start.distance(to: expected.endPoint) + end.distance(to: expected.startPoint)
        let directionOK = forwardDistance <= reverseDistance
        let shapeOK = strokeShapeLooksRight(points, axis: expected.axis)
        let placementOK = forwardDistance < 34

        if directionOK && shapeOK && placementOK {
            return "хорошо."
        }

        var problems: [String] = []

        if !directionOK {
            problems.append("направление похоже обратное")
        }

        if !shapeOK {
            problems.append("форма штриха отличается")
        }

        if !placementOK {
            problems.append("штрих далеко от нужного места")
        }

        return "\(problems.joined(separator: ", "))."
    }

    private static func strokeShapeLooksRight(_ points: [CGPoint], axis: StrokeAxis) -> Bool {
        let box = boundingBox(for: points)
        let width = box.width
        let height = box.height

        switch axis {
        case .horizontal:
            return width > height * 1.5
        case .vertical:
            return height > width * 1.5
        case .corner:
            return width > 18 && height > 24
        }
    }

    private static func boundingBox(for points: [CGPoint]) -> CGRect {
        guard let first = points.first else {
            return .zero
        }

        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { box, point in
            box.union(CGRect(origin: point, size: .zero))
        }
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
