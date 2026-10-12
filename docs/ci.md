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

`scripts/ci-select-simulator.py` выбирает доступный iPhone с установленным
runtime iOS >= 26.5. Если подходящего устройства нет, job явно падает;
он не скачивает дополнительные runtime. Скрипт предназначен только для CI.

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
