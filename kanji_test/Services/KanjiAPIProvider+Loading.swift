import Foundation

extension KanjiAPIProvider {
    func loadCards(deck: KanjiDeck) async throws -> [KanjiCard] {
        let kanjiList = try await loadKanjiList(deck: deck)
        return try await loadCards(for: kanjiList)
    }

    func loadCards(for kanjiList: [String]) async throws -> [KanjiCard] {
        var cards: [KanjiCard] = []
        var nextIndex = 0
        let maxConcurrentRequests = 16

        await withTaskGroup(of: KanjiCard?.self) { group in
            func enqueueNextCard() {
                guard nextIndex < kanjiList.count else {
                    return
                }

                let kanji = kanjiList[nextIndex]
                nextIndex += 1
                group.addTask {
                    try? await loadCard(for: kanji)
                }
            }

            for _ in 0..<min(maxConcurrentRequests, kanjiList.count) {
                enqueueNextCard()
            }

            for await card in group {
                if let card {
                    cards.append(card)
                }

                enqueueNextCard()
            }
        }

        return cards.sorted { $0.kanji < $1.kanji }
    }

    func loadCardsStream(for kanjiList: [String]) -> AsyncStream<[KanjiCard]> {
        AsyncStream { continuation in
            let task = Task {
                var batch: [KanjiCard] = []
                var didYieldFirstCard = false
                var nextIndex = 0
                let maxConcurrentRequests = 8

                await withTaskGroup(of: KanjiCard?.self) { group in
                    func enqueueNextCard() {
                        guard nextIndex < kanjiList.count else {
                            return
                        }

                        let kanji = kanjiList[nextIndex]
                        nextIndex += 1
                        group.addTask {
                            try? await loadCard(for: kanji)
                        }
                    }

                    for _ in 0..<min(maxConcurrentRequests, kanjiList.count) {
                        enqueueNextCard()
                    }

                    for await card in group {
                        guard !Task.isCancelled else {
                            return
                        }

                        if let card {
                            if didYieldFirstCard {
                                batch.append(card)
                            } else {
                                continuation.yield([card])
                                didYieldFirstCard = true
                            }
                        }

                        if batch.count >= 8 {
                            continuation.yield(batch)
                            batch.removeAll(keepingCapacity: true)
                        }

                        enqueueNextCard()
                    }
                }

                if !batch.isEmpty {
                    continuation.yield(batch)
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
