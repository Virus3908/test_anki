## Dictionary Data

This project uses dictionary data derived from JMdict and KANJIDIC.

JMdict and KANJIDIC are provided by the Electronic Dictionary Research and Development Group (EDRDG).

The dictionary files are licensed under the Creative Commons Attribution-ShareAlike 4.0 International License, unless otherwise stated by EDRDG.

Project website: https://www.edrdg.org/

License: https://www.edrdg.org/edrdg/licence.html

JMdict project: https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project

KANJIDIC project: https://www.edrdg.org/wiki/index.php/KANJIDIC_Project

The JMdict-derived files in this project include:

- `kanji_test/Data/word-data.json`

## Example Sentences

This project may load Japanese example sentences and translations from Tatoeba.

Tatoeba sentence data is provided by the Tatoeba community.

Tatoeba uses Creative Commons Attribution 2.0 France as the default license for
textual sentences. Individual sentences may use CC0 or another compatible
license. Reuse must preserve the license and author attribution applicable to
each sentence.

Project website: https://tatoeba.org/

Terms of use: https://tatoeba.org/en/terms_of_use

Using Tatoeba data: https://en.wiki.tatoeba.org/articles/show/terms-of-use

Example sentence data may be cached locally by the app after being loaded.
Each displayed remote sentence includes a link to its Tatoeba page, sentence
ID, owner username when required by its license, and the sentence's license.

## Kanji API

This project may load kanji metadata from kanjiapi.dev.

kanjiapi.dev provides an API over open Japanese dictionary and kanji datasets. Source data keeps its original licenses.

Project website: https://kanjiapi.dev/

Source repository: https://github.com/onlyskin/kanjiapi.dev

## Anki Import Libraries

Native Anki field parsing uses SwiftSoup 2.11.2 (MIT), with LRUCache (MIT) and
Swift Atomics (Apache-2.0 with Swift Runtime Library Exception).
Full notices are bundled in `kanji_test/Data/AnkiHTMLParserLicenses.txt`.

Anki package import uses ZIPFoundation 0.9.20 (MIT, Thomas Zoechling) and
Zstandard 1.5.7 (BSD-3-Clause, Meta Platforms, Inc. and affiliates).
Full license notices are bundled in `kanji_test/Data/AnkiThirdPartyLicenses.txt`
and displayed in the application's Sources screen.

- https://github.com/weichsel/ZIPFoundation
- https://github.com/facebook/zstd

## Scheduling Library

The application uses swift-fsrs for FSRS scheduling. The dependency is pinned
to revision `4fbaf20184d62f82a9f44f343337c61a2c5483e9` and is licensed under the
MIT License, Copyright (c) 2023 Ben Smiley.

The complete, unmodified notice from that dependency revision is bundled in
`kanji_test/Data/FSRS-LICENSE.txt` and displayed in the application's Sources
and Licenses screen.

Source repository: https://github.com/open-spaced-repetition/swift-fsrs

## System Translation

This project may use Apple system translation APIs to translate English meanings into Russian for display.

Apple Translation is a system framework provided by Apple.

Documentation: https://developer.apple.com/documentation/translation

Generated translations are cached locally by the app for performance and offline reuse.
