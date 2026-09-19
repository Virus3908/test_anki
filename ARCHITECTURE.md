# ARCHITECTURE.md

# Kanji Trainer --- актуальная карта проекта

Этот файл объясняет устройство текущей версии приложения без
необходимости знать Swift.

## 1. Что сейчас представляет собой приложение

Приложение уже не только тренажёр кандзи. Сейчас в нём четыре режима
учебного материала:

-   кандзи;
-   слова;
-   кана;
-   импортированные колоды Anki.

В `kanji_test` сейчас примерно **154 Swift-файла и \~10 000 строк
Swift**, плюс отдельный локальный Swift Package `Packages/AnkiImport`,
который отвечает за разбор файлов Anki.

Общая схема:

`Экран -> ViewModel/состояние -> доменная логика -> репозиторий/сервис -> данные`

Для встроенных карточек и Anki используется одна общая система
тренировки и FSRS.

## 2. Точка входа и главный объект

`App/kanji_testApp.swift` запускает `ContentView`.

`ContentView` создаёт `StudyAppViewModel`. Это composition root
приложения: он связывает между собой крупные подсистемы.

`StudyAppViewModel` владеет:

-   `StudyPreferences` --- настройками;
-   `StudyNavigation` --- навигацией;
-   `StudyCardCatalog` --- каталогом карточек;
-   `DeckPreviewViewModel` --- просмотром встроенных колод;
-   `StudyCoordinator` --- выбранными встроенными карточками/колодами;
-   `TrainingSessionViewModel` --- текущей тренировкой;
-   `TranslationViewModel` --- переводами и примерами;
-   `AnkiLibraryViewModel` --- импортированными Anki-колодами.

Логика `StudyAppViewModel` дополнительно разнесена по `+Lifecycle`,
`+ScreenActions`, `+TrainingStart`, `+TrainingFlow`.

## 3. Навигация

Основные маршруты хранятся в `StudyNavigation`.

`ContentView` переключает:

-   `StartView` --- стартовый экран;
-   `DeckPreviewView` --- просмотр встроенной колоды;
-   `AnkiDeckPreviewView` --- просмотр импортированной Anki-колоды;
-   `TrainingView` --- обучение.

Таким образом Anki имеет отдельный путь загрузки/просмотра, но после
запуска тренировки входит в общую тренировочную систему.

## 4. Каталог карточек и режимы

`PracticeMode` сейчас содержит:

-   `.kanji`;
-   `.words`;
-   `.kana`;
-   `.anki`.

`StudyCardCatalog` --- центральное место, через которое тренировочная
часть получает конкретные карточки разных типов.

Ключи прогресса разделены по namespace:

-   кандзи используют собственный ID;
-   слова имеют `word:...`;
-   кана --- `kana:...`;
-   Anki --- `anki:...`.

Это не даёт прогрессу разных типов карточек пересекаться.

## 5. Встроенные колоды

Основные модели:

-   `KanjiCard`;
-   `KanaStudyCard`;
-   `WordStudyCard`;
-   `KanjiDeck`;
-   `KanaDeck`;
-   `WordFrequencyDeck`.

Загрузка:

-   `KanjiDataLoader...`;
-   `KanaDataLoader`;
-   `WordDataLoader...`;
-   `BundledStudyData`.

`Data/word-data.json` --- большой словарный ресурс примерно на 60 тысяч
строк. Он нужен приложению, но Codex не должен читать его целиком при
обычных задачах.

## 6. Как теперь устроена тренировка

Главные файлы:

`TrainingView` → `TrainingSessionViewModel` → `TrainingSessionState` →
`TrainingSessionEngine` → `StudyProgressStore / StudyScheduler`

`TrainingSessionViewModel` управляет жизненным циклом сессии: старт,
ответ, undo, исключение карточки, переход дня, перестроение очереди и
сохранение.

После обычного ответа `submitReview(...)`:

1.  оценка применяется к `StudyProgressStore`;
2.  сохраняется undo-запись;
3.  вызывается `rebuild`;
4.  `TrainingSessionEngine.plan(...)` заново строит план;
5.  текущая очередь заменяется;
6.  текущая карточка помечается показанной;
7.  прогресс сохраняется через `ReviewRepository`.

То есть очередь пересчитывается после каждого ответа.

## 7. Важное разделение: очередь сейчас и карточки на сегодня

В текущей архитектуре это **два разных понятия**.

`StudyQueue.ids` / `StudyQueuePlan.readyIDs` --- карточки, которые
попали в активную очередь показа.

`TrainingSessionState.todayIDs` / `StudyQueuePlan.todayIDs` ---
карточки, которые всё ещё относятся к текущему учебному дню, в том числе
learning/relearning, время следующего шага которых ещё не наступило.

Это разделение специально описано прямо в `TrainingSessionState`:

> `todayIDs` --- snapshot карточек текущего учебного дня, отдельно от
> `queue`, которая содержит карточки, доступные сейчас.

Также состояние хранит:

-   `nextLearningDate` --- ближайшее время ожидающего
    learning/relearning;
-   `hiddenReviews` --- review-карточки, скрытые дневным лимитом;
-   `sessionCompletedCards`;
-   `undoHistory`.

Поэтому надпись вроде «осталось карточек сегодня» не должна
автоматически считаться как `readyIDs.count`: ожидающие карточки могут
отсутствовать в `readyIDs`, но оставаться в `todayIDs`.

## 8. Где решается, какую карточку показать

`Models/TrainingSessionEngine.swift`.

Именно здесь карточки разделяются на категории вроде:

-   learning/relearning, которые уже due;
-   review;
-   начатые новые карточки;
-   полностью новые карточки;
-   learning/relearning, ожидающие своего времени сегодня.

Затем применяется дневной лимит review/new и формируется
`StudyQueuePlan`.

Это **политика очереди**, а не сам алгоритм FSRS.

Если задача звучит:

> «Карточка с повторением через 5 минут должна вклиниться, когда её
> время наступило»

или:

> «Если больше ничего нет, разрешить показать ожидающую карточку раньше»

сначала нужно смотреть `TrainingSessionEngine` и перестроение
`TrainingSessionState`.

Если задача звучит:

> «После Good FSRS рассчитывает неправильный интервал»

тогда смотреть `StudyScheduler`.

## 9. FSRS

`Models/StudyScheduler.swift` --- адаптер между приложением и внешним
пакетом `swift-fsrs`.

Остальной код работает с собственными:

-   `StudyReviewRecord`;
-   `StudyReviewLog`;
-   `ReviewRating`;
-   `StudyProgressStore`.

Эта граница важна: изменение порядка карточек не должно случайно
превращаться в изменение математического расписания FSRS.

## 10. Сохранение прогресса

Путь:

`TrainingSessionViewModel` → `ReviewRepository` → `JSONFileStore` →
`review-memory.json`

`JSONFileStore` также обеспечивает backup/recovery.

Изменения Codable-моделей прогресса нужно делать осторожно: существующие
данные пользователя должны продолжать читаться.

## 11. Импорт Anki --- новая крупная подсистема

Поддержка Anki разделена на две части:

1.  независимый пакет `Packages/AnkiImport`;
2.  интеграция импортированных данных в основное приложение.

Подробная спецификация уже находится в `docs/anki-import.md`.

## 12. `Packages/AnkiImport`

Пакет отвечает за понимание форматов Anki, а не за UI приложения.

Основные файлы:

-   `AnkiPackageParser.swift` --- распаковка `.apkg` / `.colpkg`;
-   `AnkiDatabase.swift` --- чтение SQLite;
-   `AnkiProtobuf.swift` --- современные protobuf-структуры;
-   `AnkiModels.swift` --- модели импортированной коллекции;
-   `AnkiContent.swift`;
-   `AnkiContentParser.swift` --- разбор содержимого полей;
-   `AnkiTemplateRenderer.swift` --- обработка шаблонов карточек.

Зависимости пакета:

-   ZIPFoundation 0.9.20;
-   zstd 1.5.7;
-   SwiftSoup 2.11.2;
-   системный SQLite.

Пакет имеет собственные тесты в `Packages/AnkiImport/Tests`.

## 13. Какие Anki-файлы поддерживаются

Текущая реализация умеет работать как со старыми ZIP/SQLite пакетами
Anki, так и с современным форматом с `collection.anki21b`, Zstandard и
protobuf-метаданными.

Сохраняются, среди прочего:

-   заметки и карточки;
-   исходные поля;
-   типы заметок;
-   шаблоны;
-   CSS;
-   cloze;
-   подколоды;
-   медиа;
-   исходная SQLite-база и история Anki.

Подробные ограничения, лимиты и поддерживаемые template-функции описаны
в `docs/anki-import.md`.

## 14. Anki внутри приложения

Главные файлы:

-   `Data/AnkiRepository.swift` --- импорт и хранение;
-   `Models/AnkiLibrary.swift` --- app-side модели колод/карточек;
-   `Models/AnkiFieldDisplayPreferences.swift` --- настройки
    отображения;
-   `ViewModels/AnkiLibraryViewModel.swift` --- состояние библиотеки;
-   `Views/AnkiLibraryView.swift` --- библиотека;
-   `Views/AnkiDeckPreviewView.swift` --- просмотр колоды;
-   `Views/AnkiCardContentView.swift` --- содержимое карточки;
-   `Views/AnkiNativeContentView.swift` --- нативный SwiftUI-рендер;
-   `Views/AnkiHTMLView.swift` --- WebKit-режим;
-   `Views/TrainingView+AnkiTraining.swift` --- Anki в тренировке;
-   `Services/AnkiCardRenderer.swift`;
-   `Services/AnkiMediaService.swift`;
-   `Services/AnkiAudioPlayback.swift`;
-   `Services/AnkiSchedulingMigrator.swift` --- bootstrap истории и
    расписания Anki в app-owned FSRS;
-   `TranslationViewModel+Anki.swift`.

## 15. Как хранится импорт Anki

`AnkiRepository` использует существующий `JSONFileStore` для индекса:

`anki-library.json`

Сам контент импорта хранится отдельно в Application Support в каталоге
Anki.

Импорт устроен через staging:

`выбранный файл -> проверка/распаковка во временный каталог -> валидация -> перенос в постоянный каталог -> запись в индекс`

Поэтому неудачный импорт не должен портить уже существующие колоды.

Для идентичных файлов используется SHA-256.

Импорт выполняет тяжёлую работу вне MainActor.

## 16. Anki и SRS приложения

После импорта Anki-карточки используют **тот же**:

-   `TrainingSessionViewModel`;
-   `TrainingSessionEngine`;
-   `StudyScheduler`;
-   `ReviewRepository`.

`AnkiDatabase` читает `revlog` одним проходом и связывает строки с
карточками. `AnkiSchedulingMigrator` сортирует историю, отображает Anki
ease 1/2/3/4 в Again/Hard/Good/Easy и воспроизводит ответы через FSRS-6.
Полученные stability/difficulty сохраняются в обычном `StudyReviewRecord`,
а исторические строки --- в `StudyReviewLog` без расходования дневного
лимита и без участия в undo текущей сессии.

Текущий Anki due сохраняется как первый app-owned due. Для intraday
learning это Unix timestamp; для review/day-learning --- номер дня от
`col.crt`; для filtered deck используется `odue`. Learning и relearning
остаются соответствующими состояниями, поэтому существующая политика
очереди управляет due и waiting steps.

Bootstrap применяется только если для стабильного `anki:` review key ещё
нет app-owned record. Версия миграции отмечается в `anki-library.json`, а
сам прогресс остаётся в `review-memory.json`. Повторный импорт не создаёт
историю второй раз и не перезаписывает ответы, сделанные в приложении.
Обратные/cloze-карточки по-прежнему имеют независимые ключи.

Replay старых SM-2/Anki scheduler histories создаёт согласованное состояние
FSRS-6, но не восстанавливает неизвестные исходные FSRS parameters или
memory states, которых нет в старом `revlog`.

## 17. Два режима отображения Anki

Anki может показываться:

-   нативно через SwiftUI;
-   через исходный Anki HTML/CSS в WebKit.

Переключение хранится в настройках.

Нативный режим использует структурированное содержимое полей и локальные
медиа. HTML-режим лучше подходит для сложной раскладки шаблона.

JavaScript и сетевые ресурсы намеренно не являются частью обычного
рендера.

## 18. Перевод Anki

`TranslationViewModel+Anki.swift` подключает Anki к существующей системе
переводов.

Перевод не меняет:

-   исходные поля;
-   импортированные медиа;
-   SRS;
-   исходную базу Anki.

Он использует существующий `TranslationRepository` и общий механизм
переводчика.

## 19. Рисование

Система рисования по-прежнему отделена:

`DrawingSessionViewModel` → `DrawingBoard` → `StrokeEvaluator` →
`SVGStrokeExtractor / SVGPathParser`

Интеграция с тренировкой находится в `TrainingView+...Drawing...`.

Для ошибок распознавания штриха сначала смотреть `StrokeEvaluator`, а не
UI.

## 20. Переводы и примеры встроенных карточек

Главные компоненты:

-   `TranslationViewModel` и extensions;
-   `TranslationRepository`;
-   `RussianMeaningTranslator`;
-   `SystemTranslationClient`;
-   `RussianMeaningDictionary`;
-   Tatoeba-компоненты для примеров слов.

Anki теперь подключён к этой же подсистеме отдельным extension.

## 21. Сетевые данные кандзи

Абстракция:

`RemoteKanjiProvider`

Основная реализация:

`KanjiAPIProvider`

Код разделён на endpoint, transport models, loading и mapping.

Кэши находятся в отдельных repository-классах.

## 22. Почему Views разбиты на много файлов

Большие SwiftUI-экраны разнесены по feature extensions.

Например `TrainingView` имеет отдельные файлы для:

-   кандзи;
-   каны;
-   слов;
-   Anki;
-   рисования;
-   layout;
-   header;
-   шаблона карточки.

При UI-баге нужно искать максимально конкретный `+Feature.swift`, а не
начинать с переписывания основного `TrainingView.swift`.

## 23. Куда смотреть по симптомам

Если неправильно переключается экран: `ContentView`, `StudyNavigation`,
`StudyAppViewModel+ScreenActions`.

Если неправильно запускается тренировка:
`StudyAppViewModel+TrainingStart`, `TrainingSessionViewModel`,
`TrainingSessionState`.

Если карточка появляется слишком рано/поздно: `TrainingSessionEngine`,
затем `StudyProgressStore+Schedule`.

Если неправильный FSRS-интервал: `StudyScheduler`.

Если неправильное число «осталось сегодня»: сначала проверить различие
`todayIDs` и активной `queue/readyIDs`.

Если не сохраняется прогресс:
`TrainingSessionViewModel -> ReviewRepository -> JSONFileStore`.

Если Anki-файл не импортируется: `docs/anki-import.md`, затем
`Packages/AnkiImport` и `AnkiRepository`.

Если Anki импортировался, но колода/карточка не отображается:
`AnkiLibraryViewModel`, `AnkiLibrary`, `AnkiDeckPreviewView`,
`StudyCardCatalog`.

Если Anki-шаблон отображается неправильно: `AnkiTemplateRenderer`,
`AnkiCardRenderer`, `AnkiHTMLView`/`AnkiNativeContentView`.

Если Anki-медиа не работает: `AnkiMediaService`, `AnkiAudioPlayback`,
затем импортированная media map.

Если проблема с рисованием: `DrawingSessionViewModel`,
`StrokeEvaluator`, SVG parser/extractor.

Если проблема с переводом: `TranslationViewModel...`,
`RussianMeaningTranslator`, `TranslationRepository`.

## 24. Что особенно важно не сломать

Осторожно менять:

-   `StudyScheduler` --- влияет на интервалы;
-   `TrainingSessionEngine` --- влияет на порядок/доступность карточек;
-   `todayIDs` vs `readyIDs` --- влияет на завершение дня и счётчики;
-   `StudyProgressStore` --- пользовательский прогресс;
-   `JSONFileStore` --- persistence и recovery;
-   Codable-форматы --- обратная совместимость;
-   `AnkiRepository` --- атомарность импорта;
-   `Packages/AnkiImport` --- безопасность архивов и совместимость
    форматов;
-   `StrokeEvaluator` --- распознавание штрихов.

## 25. Проверка изменений

Сборка приложения:

`xcodebuild -project kanji_test.xcodeproj -scheme kanji_test -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build`

Тесты парсера Anki:

`swift test --package-path Packages/AnkiImport`

Интеграционные тесты Anki + общего SRS:

`kanji_testHostedTests/AnkiStudyIntegrationTests.swift`

Они запускаются через Test схемы `kanji_test` на iOS Simulator.

## 26. Как ставить задачи Codex

Лучше описывать наблюдаемое поведение, а не просить «посмотреть весь
проект».

Например:

> После Good карточка получает повтор через 10 минут. Пока есть другие
> карточки, она не должна показываться раньше due. Когда due наступил,
> она должна получить приоритет. Если других карточек больше нет, её
> можно показать досрочно. Счётчик оставшихся карточек сегодня должен
> учитывать ожидающие learning-карточки.

По `AGENTS.md` Codex должен понять, что здесь нужны:

`TrainingSessionEngine + TrainingSessionState + TrainingSessionViewModel`

и что нельзя автоматически лезть в `StudyScheduler`, пока не доказано,
что проблема именно в расчёте FSRS.

Главная задача архитектурных файлов --- позволить агенту быстро найти
нужную подсистему без чтения всего репозитория и огромных data-файлов.
