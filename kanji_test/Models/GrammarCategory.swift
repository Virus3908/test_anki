import Foundation

/// Exact OpenJLPT tag mapping, not inference from the construction's name.
nonisolated enum GrammarCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case ability, addition, advice, appearance, attempt, casual, change, command, comparison
    case completion, concession, condition, conjecture, conjugation, contrast, copula, criticism
    case decision, degree, demonstrative, desire, emotion, emphasis, example, exclamation, exclusion
    case experience, formal, hearsay, honorific, humble, intention, invitation, limitation, manner
    case means, necessity, negation, nominalization, obligation, particle, permission, politeness
    case possibility, prohibition, purpose, quantity, question, quotation, range, reason, recollection
    case regret, relation, request, result, sequence, simultaneity, standpoint, state, suggestion
    case surprise, tendency, tense, time, topic, voice, wish, written
    case givingReceiving = "giving-receiving"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ability: "Способность"
        case .addition: "Добавление"
        case .advice: "Совет"
        case .appearance: "Внешнее впечатление"
        case .attempt: "Попытка"
        case .casual: "Разговорная речь"
        case .change: "Изменение"
        case .command: "Приказ"
        case .comparison: "Сравнение"
        case .completion: "Завершённость"
        case .concession: "Уступка"
        case .condition: "Условия"
        case .conjecture: "Предположение"
        case .conjugation: "Спряжение"
        case .contrast: "Противопоставление"
        case .copula: "Связка"
        case .criticism: "Критика"
        case .decision: "Решение"
        case .degree: "Степень"
        case .demonstrative: "Указательные конструкции"
        case .desire: "Желания"
        case .emotion: "Эмоции"
        case .emphasis: "Выделение"
        case .example: "Приведение примера"
        case .exclamation: "Восклицание"
        case .exclusion: "Исключение"
        case .experience: "Опыт"
        case .formal: "Формальная речь"
        case .givingReceiving: "Передача и получение"
        case .hearsay: "Информация со слов других"
        case .honorific: "Почтительная речь"
        case .humble: "Скромная речь"
        case .intention: "Намерение"
        case .invitation: "Приглашение"
        case .limitation: "Ограничение"
        case .manner: "Способ действия"
        case .means: "Средство"
        case .necessity: "Необходимость"
        case .negation: "Отрицание"
        case .nominalization: "Номинализация"
        case .obligation: "Обязанность"
        case .particle: "Частицы"
        case .permission: "Разрешение"
        case .politeness: "Вежливость"
        case .possibility: "Возможность"
        case .prohibition: "Запрет"
        case .purpose: "Цель"
        case .quantity: "Количество"
        case .question: "Вопросы"
        case .quotation: "Цитирование"
        case .range: "Диапазон"
        case .reason: "Причина"
        case .recollection: "Воспоминание"
        case .regret: "Сожаление"
        case .relation: "Отношение"
        case .request: "Просьба"
        case .result: "Результат"
        case .sequence: "Последовательность"
        case .simultaneity: "Одновременность"
        case .standpoint: "Точка зрения"
        case .state: "Состояние"
        case .suggestion: "Предложение"
        case .surprise: "Удивление"
        case .tendency: "Тенденция"
        case .tense: "Время глагола"
        case .time: "Время"
        case .topic: "Тема"
        case .voice: "Залог"
        case .wish: "Пожелание"
        case .written: "Письменная речь"
        }
    }
}
