# Тесты в GitHub Actions

Workflow: `.github/workflows/tests.yml` (название **Tests**).

Запускается при открытии pull request, обновлении его ветки и повторном
открытии PR, а также вручную через **Actions → Tests → Run workflow**.
Новый запуск отменяет предыдущий для той же Git ref. Обычный push без PR
не запускает тесты.

Две независимые задачи выполняются на `macos-26` с Xcode 26.6:

- **AnkiImport package tests**: `swift test --package-path Packages/AnkiImport`.
- **iOS hosted tests**: `xcodebuild test` со схемой `kanji_test`, только
  `kanji_testHostedTests`, на iPhone 17 / iOS 26.5. Запускаются все hosted-тесты,
  включая кану, поиск, рисование, SRS и интеграцию Anki.

Подпись приложения отключена; сертификаты и дополнительные secrets не нужны.
Для приложения используются версии зависимостей из закоммиченного
`kanji_test.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
Bash сохраняет ненулевой exit code тестовой команды даже при выводе через `tee`.

Логи обеих задач и `.xcresult` iOS-тестов публикуются как artifacts даже при
ошибке тестов и хранятся 14 дней. `.xcresult` можно скачать и открыть в Xcode.

Targets для файлов `kanji_testUITests` и старой схемы `kanji_testUnitTests`
в текущем `project.pbxproj` отсутствуют. Эти схемы не используются в CI;
добавление полноценного UI test target — отдельная задача.

При обновлении минимальной версии iOS или образа GitHub нужно проверить
`DEVELOPER_DIR` и `-destination` в workflow. Список установленных инструментов:
https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md
