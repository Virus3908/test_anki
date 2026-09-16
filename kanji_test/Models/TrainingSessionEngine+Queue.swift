import Foundation

extension TrainingSessionEngine {
    static func applyQueueDecision<Item>(
        _ decision: ReviewQueueDecision,
        item: Item,
        key: String,
        currentIndex: Int,
        items: inout [Item],
        keyFor: (Item) -> String
    ) {
        switch decision.repeatPlacement {
        case .none:
            if decision.shouldRemoveFutureRepeats {
                removeFutureRepeats(after: currentIndex, key: key, items: &items, keyFor: keyFor)
            }
        case .after(let offset):
            removeFutureRepeats(after: currentIndex, key: key, items: &items, keyFor: keyFor)
            insertRepeat(item, after: offset, currentIndex: currentIndex, items: &items)

            if let additionalRepeatOffset = decision.additionalRepeatOffset {
                insertRepeat(item, after: additionalRepeatOffset, currentIndex: currentIndex, items: &items)
            }
        case .atEnd:
            removeFutureRepeats(after: currentIndex, key: key, items: &items, keyFor: keyFor)
            items.append(item)
        }
    }

    static func applyQueueDecision<Item: StudyItem>(
        _ decision: ReviewQueueDecision,
        item: Item,
        key: String,
        currentIndex: Int,
        items: inout [Item]
    ) {
        applyQueueDecision(
            decision,
            item: item,
            key: key,
            currentIndex: currentIndex,
            items: &items,
            keyFor: \.reviewKey
        )
    }

    static func removeFutureRepeats<Item>(
        after index: Int,
        key: String,
        items: inout [Item],
        keyFor: (Item) -> String
    ) {
        guard index + 1 < items.count else {
            return
        }

        for itemIndex in items.indices.reversed() where itemIndex > index && keyFor(items[itemIndex]) == key {
            items.remove(at: itemIndex)
        }
    }

    static func removeFutureRepeats<Item: StudyItem>(
        after index: Int,
        key: String,
        items: inout [Item]
    ) {
        removeFutureRepeats(
            after: index,
            key: key,
            items: &items,
            keyFor: \.reviewKey
        )
    }

    private static func insertRepeat<Item>(
        _ item: Item,
        after offset: Int,
        currentIndex: Int,
        items: inout [Item]
    ) {
        let insertIndex = min(currentIndex + offset, items.count)
        items.insert(item, at: insertIndex)
    }
}
