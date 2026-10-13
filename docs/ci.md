# Тесты в GitHub Actions

Workflow [Tests](https://github.com/Virus3908/test_anki/actions/workflows/tests.yml)
запускается для `pull_request`, `push` в `main` и `workflow_dispatch`.
Новый запуск отменяет старый только для того же события и Git ref;
разные ветки и PR не делят concurrency group.

Три независимых job на `macos-26`, Xcode 26.6:

- **AnkiImport package tests** — все тесты `Packages/AnkiImport`.
- **iOS hosted tests** — только `kanji_testHostedTests`: поиск, bundled-данные,
  рисование, SRS, Anki, кеши, фуригана и дневные разрешения.
- **iOS UI tests** — только `kanji_testUITests`: запуск, разделы и колоды,
  поиск/просмотр, тренировка, рисование, озвучивание, фуригана/настройка,
  импорт небольшой локальной Anki-фикстуры, сохранение прогресса и завершение дня.

Дополнительно два job на Ubuntu: **Grammar source integrity** проверяет pinned
OpenJLPT snapshot, исходные ID/порядок/поля, JSON, атрибуцию, ссылки и
воспроизводимость; **Grammar Russian content readiness** требует русские уроки
и английскую основу для системного перевода на телефоне, минимум четыре прикладных задания/два
типа у каждого из 526 правил, уникальные варианты и источник ключей.
Дополнительно проверяются метаданные всех ID, MIT-выборка Nihongo Mono, её hash
и отсутствие полного ответа в условии. Hosted проверяет ключи спряжений,
исключения, ввод каны/кандзи и взвешенную оценку. Это
изменение модели перевода следует уточнению пользователя; job не отключён,
порог упражнений не уменьшен. Оба сохраняют
grammar-quality.json. validate_ci.py предназначен только для GitHub Actions.
В hosted/UI targets добавлены GrammarDataTests, GrammarPracticeTests,
GrammarStudyIntegrationTests и GrammarUITests. См. [грамматику](grammar.md).

`scripts/ci-select-simulator.py` выбирает доступный iPhone с установленным
runtime iOS >= 26.5. Если подходящего устройства нет, job явно падает;
он не скачивает дополнительные runtime. UI job передаёт --compact для выбора
наиболее компактного доступного iPhone с актуальным runtime. Скрипт только для CI.

iOS jobs сначала выполняют `build-for-testing`, ждут загрузки выбранного устройства
через `simctl bootstatus -b`, затем выполняют `test-without-building`. Подготовка
ОС симулятора не входит в измерение запуска приложения в UI-тесте.
Сборки используют закреплённые SPM-зависимости. Code signing отключён,
секреты не нужны. `set -euo pipefail` сохраняет ошибку `xcodebuild`/`swift`
при выводе через `tee`. Таймауты: 20 минут для package, 30 для hosted,
40 для UI. Test jobs не дублируют группы тестов.

UI target использует `-ui-testing`, offline providers, чистое состояние перед
каждым сценарием и локальную `ui-test-deck.apkg`. Relaunch-тесты явно сохраняют
это состояние. Ожидания проверяют элементы/состояние через XCTest predicates;
фиксированных `sleep` нет. Приложение завершается в `tearDown`.
UI-режим и очистка тестового состояния доступны только в Debug.
Тесты ждут доступности элементов для нажатия и явно закрывают уведомление
об импорте фикстуры. При сбое ожидания сохраняются screenshot и accessibility tree.

## Результаты и повторный запуск

Откройте PR → **Checks**, затем нужный job. В summary запуска доступны artifacts:

- `anki-import-test-log`;
- `ios-hosted-test-results`: `hosted-build.log`, `hosted-tests.log`,
  `hosted-tests.xcresult`;
- `grammar-ui-screenshots`: экспортированные screenshot attachments этапов урока
  (главная, N5, объяснение, задание, правильный/ошибочный ответ, результат),
  включая отдельный сценарий с accessibility3 Dynamic Type;
- `ios-ui-test-results`: `ui-build.log`, `ui-tests.log`, `ui-tests.xcresult`.

В iOS artifacts также включён отдельный `*-simulator-boot.log`.

Artifacts загружаются даже при падении и хранятся 14 дней. Скачанный
`.xcresult` можно открыть в Xcode для просмотра failures, timings и вложений.
Для повтора используйте **Re-run failed jobs** либо **Actions → Tests → Run
workflow**, выбрав feature-ветку. При обновлении runner проверьте путь
`DEVELOPER_DIR` и доступность runtime.

## Ограничение локального окружения

Для этой работы все package, hosted и UI tests выполняются **только в CI**.
Codex не запускает локально XCTest, `swift test`, `xcodebuild test` или Simulator.
Разрешены статические проверки и сборки:

```sh
xcodebuild -project kanji_test.xcodeproj -scheme kanji_test \
  -configuration Debug -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
swift build --package-path Packages/AnkiImport -j 2
git diff --check
```

Успешная локальная сборка не подтверждает прохождение тестов.

## Архитектурные регрессии после PR #21

В существующий hosted target включены `AnkiBatchMigrationTests`, расширенные
`AnkiSearchIndexTests` и `AdditionalCardsTests`: пакетная история, идемпотентность,
совместимость JSON/дневных индексов, ошибки производного кеша, частичный поиск,
локальные ошибки карточек, один активный импорт, отмена и эффективные лимиты.
Управляемые actor gates синхронизируют асинхронные сценарии без случайных задержек.
`testLargeSyntheticMigrationPerformance` измеряет синтетическую историю через
XCTest measure в hosted job без произвольного порога времени. Он выполняется
только на GitHub; локально тесты и Simulator не запускаются. Новые Swift-файлы
автоматически включаются через PBXFileSystemSynchronizedRootGroup. Все три
существующих jobs сохранены.

Смешанная грамматика: GrammarMixedSessionTests и GrammarFuriganaTests запускаются
в прежнем hosted job. validate_ci.py проверяет 526 записей grammar-audit.json и
точное восстановление текстов ruby; release job по-прежнему требует полноценные
уроки всего корпуса. GrammarUITests сохраняет дополнительные screenshots ввода,
смешанного вопроса, переключения фуриганы, ошибки и результата; экспорт прежний.

Corpus job устанавливает закреплённые SudachiPy/core, повторяет разбор извлечённой
выборки, проверяет source/translation IDs и direct links по официальному pinned
Tatoeba snapshot. При смене еженедельной выгрузки downloader явно отказывается
подменять данные; нужен сохранённый архив или осознанный repin. Publication-boundary
regressions и GrammarSentenceBankTests выполняются только в Actions. Release gate
дополнен пятью семантически проверенными контекстами на правило. Coverage/review
packets сохраняются в grammar-corpus-coverage. [Корпус](grammar-corpus.md).
