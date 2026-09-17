import Foundation

nonisolated extension KanjiReviewStore {
    func orderedCards(_ cards: [KanjiCard], now: Date = Date()) -> [KanjiCard] {
        cards.sorted { left, right in
            let leftDate = records[left.kanji]?.dueDate ?? .distantPast
            let rightDate = records[right.kanji]?.dueDate ?? .distantPast
            let leftDue = Calendar.current.startOfDay(for: leftDate) <= Calendar.current.startOfDay(for: studyDate(now: now))
            let rightDue = Calendar.current.startOfDay(for: rightDate) <= Calendar.current.startOfDay(for: studyDate(now: now))

            if leftDue != rightDue {
                return leftDue
            }

            if leftDate != rightDate {
                return leftDate < rightDate
            }

            return left.kanji < right.kanji
        }
    }

    func learningCards(
        from cards: [KanjiCard],
        newCardLimit: Int,
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [KanjiCard] {
        dueReviewCards(
            from: cards,
            learningSuccessTarget: learningSuccessTarget,
            now: now
        ) + newLearningCards(
            from: cards,
            newCardLimit: newCardLimit,
            learningSuccessTarget: learningSuccessTarget,
            now: now
        )
    }

    func dueReviewItems<Item>(
        from items: [Item],
        key: (Item) -> String,
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [Item] {
        return items
            .filter { item in
                guard let record = records[key(item)] else {
                    return false
                }

                return record.state == .review && isDue(record, now: now)
            }
            .sorted { left, right in
                let leftDate = records[key(left)]?.dueDate ?? .distantPast
                let rightDate = records[key(right)]?.dueDate ?? .distantPast

                if leftDate != rightDate {
                    return leftDate < rightDate
                }

                return key(left) < key(right)
            }
    }

    func dueReviewItems<Item: StudyItem>(
        from items: [Item],
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [Item] {
        dueReviewItems(
            from: items,
            key: \.reviewKey,
            learningSuccessTarget: learningSuccessTarget,
            now: now
        )
    }

    func newLearningItems<Item>(
        from items: [Item],
        key: (Item) -> String,
        newCardLimit: Int,
        now: Date = Date()
    ) -> [Item] {
        let inProgressItems = items
            .filter { item in
                guard let record = records[key(item)] else {
                    return false
                }

                return record.state != .review && isDue(record, now: now)
            }
            .sorted { left, right in
                let leftDate = records[key(left)]?.dueDate ?? .distantPast
                let rightDate = records[key(right)]?.dueDate ?? .distantPast

                if leftDate != rightDate {
                    return leftDate < rightDate
                }

                return key(left) < key(right)
            }

        let startedWithoutAnswer = items.filter { records[key($0)] == nil && firstShownAt[key($0)] != nil }
        let newItems = items
            .filter { records[key($0)] == nil && firstShownAt[key($0)] == nil }
            .prefix(remainingNewCards(limit: newCardLimit, now: now))
        return inProgressItems + startedWithoutAnswer + Array(newItems)
    }

    func newLearningItems<Item: StudyItem>(
        from items: [Item],
        newCardLimit: Int,
        now: Date = Date()
    ) -> [Item] {
        newLearningItems(
            from: items,
            key: \.reviewKey,
            newCardLimit: newCardLimit,
            now: now
        )
    }

    func dueReviewCards(
        from cards: [KanjiCard],
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [KanjiCard] {
        dueReviewItems(
            from: cards,
            key: \.kanji,
            learningSuccessTarget: learningSuccessTarget,
            now: now
        )
    }

    func newLearningCards(
        from cards: [KanjiCard],
        newCardLimit: Int,
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [KanjiCard] {
        newLearningItems(
            from: cards,
            key: \.kanji,
            newCardLimit: newCardLimit,
            now: now
        )
    }
}
