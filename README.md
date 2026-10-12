# Kanji Trainer

iOS-приложение на SwiftUI для изучения кандзи, хираганы, катаканы и японских
слов. Встроенные карточки и импортированные колоды Anki используют общую
систему интервальных повторений FSRS. Интерфейс приложения — на русском языке.

## Возможности

- **Кандзи:** значения, чтения, порядок штрихов; колоды по школьным уровням,
  JLPT, Joyo и Jinmeiyo.
- **Кана:** 114 карточек хираганы и 115 катаканы, включая маленькие символы,
  дакутэн, хандакутэн и составные сочетания. Сочетания рисуются по символам
  с переходом между ними.
- **Слова:** встроенные common-наборы из JMdict, чтения, значения и примеры.
- **Anki:** импорт локальных `.apkg` и `.colpkg`, изображения и аудио,
  отображение карточек нативно или по HTML-шаблону. При первом импорте
  приложение учитывает исходное расписание и доступную историю повторений.
- **Тренировки:** рисование с проверкой штрихов, карточки, выбор ответа,
  ввод значения и упражнения на слух. Доступные форматы зависят от материала.
- **FSRS:** дневные лимиты, настройки колод, расписание повторений и отмена
  ответа. Кастомная тренировка позволяет выбрать отдельные карточки.
- **Поиск и озвучивание:** поиск по символам и чтениям, японская системная
  озвучка с выбором голоса и скорости.

Встроенные словари, метаданные каны и образцы штрихов находятся в приложении.
Основные тренировки работают офлайн. Загрузка примеров из Tatoeba и загрузка
необходимых моделей системного перевода могут требовать интернет.

## Требования

- macOS и Xcode с iOS SDK 26.5 или новее; в CI используется Xcode 26.6.
- iPhone или iOS Simulator с iOS 26.5 или новее.
- Интернет для первоначального скачивания Swift Package Manager зависимостей.

## Запуск

```sh
git clone https://github.com/Virus3908/test_anki.git
cd test_anki
open kanji_test.xcodeproj
```

В Xcode дождитесь разрешения зависимостей, выберите схему **kanji_test**,
совместимый симулятор и нажмите **Run**. Для запуска на устройстве выберите
свою команду в **Signing & Capabilities** и при необходимости измените Bundle
Identifier.

Проект использует Swift Package Manager. Отдельная установка CocoaPods,
Carthage или настройка внешнего сервера не нужны.

Сборка без подписи:

```sh
xcodebuild \
  -project kanji_test.xcodeproj \
  -scheme kanji_test \
  -sdk iphoneos \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Тесты и CI

Тесты самостоятельного пакета импорта Anki:

```sh
swift test --package-path Packages/AnkiImport
```

Тесты приложения, включая кану, поиск, рисование, очереди SRS и интеграцию Anki:

```sh
xcodebuild test \
  -project kanji_test.xcodeproj \
  -scheme kanji_test \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:kanji_testHostedTests \
  CODE_SIGNING_ALLOWED=NO
```

Если указанного симулятора нет, замените `-destination` на доступное устройство
с iOS 26.5 или новее. Список устройств: `xcrun simctl list devices available`.

[GitHub Actions](.github/workflows/tests.yml) запускает обе группы тестов
при открытии и обновлении pull request. Результаты и логи сохраняются в
artifacts, включая `.xcresult`, который можно открыть в Xcode.
Ручной запуск доступен через **Actions → Tests → Run workflow** после появления
workflow в основной ветке. Подробности и текущее состояние UI test targets —
в [документации CI](docs/ci.md).

## Устройство проекта

```text
kanji_test/
  App/          Точка входа
  Views/        SwiftUI-экраны и компоненты
  ViewModels/   Состояние приложения, загрузка колод и тренировки
  Models/       Карточки, колоды, прогресс и адаптер FSRS
  Data/         Локальные ресурсы, загрузчики и репозитории
  Drawing/      Рисование, разбор SVG и проверка штрихов
  Services/     Anki, озвучивание, переводы и внешние источники
Packages/
  AnkiImport/   Разбор архивов, SQLite и шаблонов Anki
kanji_testHostedTests/
                Тесты приложения
.github/workflows/
                GitHub Actions
```

Основной путь данных:

```text
SwiftUI → ViewModel → модели и сервисы → репозитории и локальные ресурсы
```

Кандзи загружаются из `kanji-metadata.json`, кана — из `kana-metadata.json`,
слова — из `word-data.json`. Actor `BundledStudyData` кеширует декодированные
данные. Штрихи кандзи и каны берутся из локального архива KanjiVG.

Пользовательский прогресс, переводы и импортированные колоды хранятся локально
в Application Support. Запись JSON использует резервные копии и восстановление.
Импорт Anki сначала проходит распаковку и проверку во временном каталоге.

[ARCHITECTURE.md](ARCHITECTURE.md) содержит подробную карту подсистем,
а [AGENTS.md](AGENTS.md) — правила работы с репозиторием.

## Лицензия и источники

Собственный код и документация проекта распространяются под [MIT](LICENSE).
Copyright © 2026 Virus3908 и участники проекта.

Встроенные данные и сторонние библиотеки сохраняют свои лицензии:

| Компонент | Лицензия / источник уведомлений |
| --- | --- |
| JMdict и KANJIDIC2, EDRDG | [CC BY-SA 4.0](https://www.edrdg.org/edrdg/licence.html) |
| KanjiVG, Ulrich Apel и участники | [CC BY-SA 3.0](kanji_test/Data/KanjiVG-LICENSE.txt), [уведомление об адаптации](kanji_test/Data/KanjiVG-NOTICE.txt) |
| swift-fsrs | [MIT](kanji_test/Data/FSRS-LICENSE.txt) |
| ZIPFoundation и Zstandard | [Уведомления о лицензиях](kanji_test/Data/AnkiThirdPartyLicenses.txt) |
| SwiftSoup и его зависимости | [Уведомления о лицензиях](kanji_test/Data/AnkiHTMLParserLicenses.txt) |
| Примеры Tatoeba | Лицензия и авторство конкретного предложения |

Полная атрибуция и ссылки на источники — в [ATTRIBUTION.md](ATTRIBUTION.md).
MIT-лицензия проекта не заменяет лицензии этих данных, библиотек или
пользовательских колод Anki.
