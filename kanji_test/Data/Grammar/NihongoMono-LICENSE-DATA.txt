# Data licensing

The source code of nihongo mono is MIT-licensed (see [LICENSE](LICENSE)).
The dictionary data files committed to this repository and served by the
app are **generated from third-party sources and remain under those
sources' licences**, which are share-alike where noted. Redistributions or
derivatives of these files must comply with the licence of the matching
source, including attribution.

| Path | Derived from | Licence |
| --- | --- | --- |
| `src/data/verbs/`, `src/data/vocab/`, `public/data/jlpt/verbs-*`, `public/data/jlpt/vocab-*`, `public/data/verbs-ext/`, `public/data/vocab-ext/` | [JMdict](https://www.edrdg.org/jmdict/j_jmdict.html) (EDRDG), with [JmdictFurigana](https://github.com/Doublevil/JmdictFurigana) segmentation | [CC BY-SA 4.0 under the EDRDG licence](https://www.edrdg.org/edrdg/licence.html) |
| `src/data/kanji/`, `public/data/jlpt/kanji-core.json.gz`, `public/data/kanji-ext/` | [KANJIDIC2](https://www.edrdg.org/wiki/index.php/KANJIDIC_Project) and [KRADFILE](https://www.edrdg.org/krad/kradinf.html) (EDRDG) | [CC BY-SA 4.0 under the EDRDG licence](https://www.edrdg.org/edrdg/licence.html) |
| `public/data/names/` | [JMnedict/ENAMDICT](https://www.edrdg.org/enamdict/enamdict_doc.html) (EDRDG) | [CC BY-SA 4.0 under the EDRDG licence](https://www.edrdg.org/edrdg/licence.html) |
| `public/data/strokes/` | [KanjiVG](https://kanjivg.tagaini.net/) © Ulrich Apel | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `src/data/grammar/`, `public/data/jlpt/grammar-*` | Original content written for this project (explanations, structures, example sentences); the inventory of which grammar points exist per JLPT level was cross-referenced against public JLPT study lists | [MIT](LICENSE), same as the source code |
| `public/ocr/models/` | Japanese + English recognition models from [tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast) (Tesseract project), redistributed unmodified apart from gzip | [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0) |

Content embedded inside the word-entry files above (attribution-only
licences, compatible with inclusion in the CC BY-SA files):

- **Example sentences** from the Tanaka Corpus via
  [Tatoeba](https://tatoeba.org/) —
  [CC BY 2.0 FR](https://creativecommons.org/licenses/by/2.0/fr/).
- **JLPT level tags** from community lists
  ([stephenmk/yomitan-jlpt-vocab](https://github.com/stephenmk/yomitan-jlpt-vocab),
  [elzup/jlpt-word-list](https://github.com/elzup/jlpt-word-list)), based on
  Jonathan Waller's lists — [CC BY](http://www.tanos.co.uk/jlpt/sharing/).
- **Example-sentence furigana** was generated at build time with
  [kuromoji](https://github.com/takuyaa/kuromoji.js) (Apache-2.0) and its
  bundled IPADIC dictionary. The sentence parser's optional "Accurate
  Parsing" mode additionally serves that IPADIC dictionary to the browser
  (copied from the npm package into `public/kuromoji/` by
  `scripts/copy-kuromoji.ts`; gitignored here, shipped by deployments).
  IPADIC is distributed under its own permissive licence — the required
  notice travels with the data at `public/kuromoji/NOTICE.md` and is
  linked from the About page.
- **On-device OCR** (the parser's opt-in "Scan Image") is powered by
  [tesseract-wasm](https://github.com/robertknight/tesseract-wasm)
  (BSD-2-Clause, embedding the Apache-2.0 Tesseract engine and the
  Leptonica library), copied from the npm package into
  `public/ocr/engine/` by `scripts/copy-tesseract.ts` (gitignored here,
  shipped by deployments). The combined notice travels with the data at
  `public/ocr/NOTICE.md` and is linked from the About page.

The EDRDG-derived files and the KanjiVG-derived files are kept in separate
files/directories precisely so each stays under its own share-alike licence
(CC BY-SA 4.0 vs 3.0) without mixing.

User-facing attribution lives on the app's About page
(`src/routes/about.tsx`) together with the dataset generation date — keep
both this file and that page accurate when adding a source.
