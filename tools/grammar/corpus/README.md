# Grammar corpus preparation and publication

This is a preparation toolchain, not a second exercise engine or SRS. It processed
all 526 immutable OpenJLPT IDs in five level batches. **The full course is not
ready**: harvested candidates never become scored exercises by a morphological
match or automatically claimed linguistic review.

## Pinned inputs

- OpenJLPT 0d1d3410bec90bd4098a7c72de820543cb4f707c, 81/98/101/123/123 rules,
  1526 original examples; original input stays in ../upstream.
- Tatoeba official 2026-10-10 export: Japanese/English/Russian detailed sentences,
  direct links, Japanese indices and CC0 IDs. snapshot.json pins URLs, dates,
  byte counts and SHA-256. Six bulk files, no per-sentence crawl and no audio.
- Nihongo Mono ec0ba4a0ce1611c568b0e4f8a223eb8029249a25, original grammar only.
  Exact unique title/slug matches plus the five existing explicit mappings:
  355 mappings, all candidate associations. nihongo-source-lock.json pins files.
- SudachiPy 0.6.11, SudachiDict-core 20250129, split mode A. Token surface,
  dictionary form, POS, conjugation type/form, reading, OOV and UTF-8 positions
  are retained. Reading proposals flag ambiguous/OOV tokens and require review.

See NOTICE.md. Each Japanese source and each linked translation has its own
license/author/URL/ID. CC0 is assigned only through the official CC0 file.
Never treat all sources as relicensed under one common license.

## Preparation commands (not tests)

Use a separate Python 3.12 venv OUTSIDE the app/repository, e.g. /private/tmp.
These commands prepare resources; local test/check scripts remain prohibited.

```sh
python3.12 -m venv /private/tmp/grammar-corpus-env
/private/tmp/grammar-corpus-env/bin/pip install -r tools/grammar/corpus/requirements.txt
/private/tmp/grammar-corpus-env/bin/python tools/grammar/corpus/download.py \
  --destination /private/tmp/grammar-tatoeba-2026-10-10
/private/tmp/grammar-corpus-env/bin/python tools/grammar/corpus/prepare.py \
  --snapshot-dir /private/tmp/grammar-tatoeba-2026-10-10 --export-date 2026-10-10
/private/tmp/grammar-corpus-env/bin/python tools/grammar/corpus/import_sources.py \
  --nihongo-directory /private/tmp
python3 tools/grammar/generate.py
/private/tmp/grammar-corpus-env/bin/python tools/grammar/corpus/freeze.py
```

The Nihongo staging directory contains nihongo-n5.json through nihongo-n1.json
from the exact pinned src/data/grammar paths. Input hashes must match the lock.
The downloader refuses a changed weekly export. Tatoeba's public URLs are rolling:
retain exact pinned archives outside Git/Bundle for long-term reproducibility.
When they are no longer served, deliberately re-pin a new batch; never silently
replace old IDs/texts/hash metadata. CI fetching a changed export fails explicitly.

## Outputs and limits

- source-candidates.jsonl / tatoeba-candidates.jsonl: one immutable sentence per
  content ID per harvested source set. Duplicate text across sets merges by ID.
  Token metadata and source ownership remain preparation data, outside Bundle.
- source-usages.json / tatoeba-usages.json: rule/sentence links and candidate
  spans, never semantic approval. Japanese indices supply existing word-usage
  annotations and prioritize indexed contexts; they are not semantic judges.
- profiles.json: all 526 discovery profiles, surface probes plus lemma/POS
  sequences. Dependent verb forms are analyzed with an explicit carrier; these
  are recall-oriented candidate probes, not complete grammar recognition. No
  substring-only match is promoted. Unhandled probes remain a review deficit.
- nN-review-packet.json: all rules, meanings/formulas, candidate usage IDs,
  candidate counts, missing theory/translations/segments/exercise requirements.
- coverage-report.json: candidate coverage versus actual teaching readiness.
- excluded-from-scoring.json: candidate usage IDs blocked from scored publication.
- batch-lock.json: exact extracted candidate batch hashes/tool versions.

Candidate semantic segments remain empty. Splitting every token into a sentence
assembly would create bad pedagogy; a reviewer explicitly supplies meaningful
constituents, target boundaries, permitted alternative orders and errors.
Existing authored assembly chunks are retained with UTF-8 spans. Original bytes
must reconstruct exactly. Morphology is not proof of meaning or translation.

## Review -> existing exercise engine

review.json is empty until genuine review decisions exist. It separates:

1. sentenceReviews: unchanged Japanese, reviewer/rationale, reviewed Russian
   translation and optional approved bracket readings;
2. usageReviews: exact rule, semantic evidence, usage restrictions, difficulty,
   target span and meaningful segments;
3. exercises: existing GrammarExercise-compatible payload, usage ID and a
   diagnostic criterion for every rejected option/extra assembly element.

publish.py refuses missing review evidence, unknown senses/rules, missing
translations, invalid UTF-8 boundaries, title-recognition questions and unexplained
wrong options. It never fills reviewer names or decides semantics with an LLM.
Required comparison prerequisites are explicit. Rule introduction/theory must
also be authored in ../lessons.json; having reviewed exercises alone is not a
complete lesson. Release gate requires substantive lessons plus five reviewed
contexts per rule. Nothing in this batch satisfies that new semantic gate.

compile_bank.py stores sentences once, interns remaining text fragments and
writes compact templates. Rule resources use exampleReferences and
exerciseTemplateIDs. GrammarDataLoader resolves them into existing GrammarRule /
GrammarExercise values. Legacy inline resources still decode. No Python/Sudachi
runtime, corpus downloader, full dumps or review packets are app resources.
Existing editorial eligibility of 83 authored exercises is preserved without
claiming independent linguistic review; no harvested candidate is scored.

## CI only

validate_corpus_ci.py, validate_provenance_ci.py and quality_tests_ci.py may run
only in GitHub Actions. CI re-analyzes pinned records, checks actual source IDs,
direct translation links and per-ID licenses against official exports, verifies
spans/readings/references and tests the publication boundary. Hosted tests cover
bank resolution, alternative answers, semantic chunks and context selection.
Old FSRS/Undo/progress/mixed/UI jobs remain. No local test invocation is permitted.
