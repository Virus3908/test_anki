#!/usr/bin/env bash
# Regenerates ui-test-deck.apkg: legacy Anki package (collection.anki2),
# one deck "UI Test Deck", Basic note type, 3 new cards. Mirrors the schema
# used by Packages/AnkiImport/Tests/AnkiImportTests/AnkiImportTests.swift.
set -euo pipefail

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$FIXTURES_DIR/ui-test-deck.apkg"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

MODELS='{"20":{"id":20,"name":"Basic","type":0,"css":".card { font-size: 32px; text-align: center; }","flds":[{"name":"Front","ord":0},{"name":"Back","ord":1}],"tmpls":[{"name":"Card 1","ord":0,"qfmt":"{{Front}}","afmt":"{{FrontSide}}<hr id=answer>{{Back}}"}]}}'
DECKS='{"40":{"id":40,"name":"UI Test Deck"}}'
SEP=$'\x1f'

sqlite3 "$WORK_DIR/collection.anki2" <<SQL
CREATE TABLE col(crt INTEGER, models TEXT, decks TEXT);
CREATE TABLE notes(id INTEGER PRIMARY KEY, guid TEXT, mid INTEGER, flds TEXT, tags TEXT);
CREATE TABLE cards(id INTEGER PRIMARY KEY, nid INTEGER, did INTEGER, ord INTEGER, type INTEGER, queue INTEGER, due INTEGER, ivl INTEGER, factor INTEGER, reps INTEGER, lapses INTEGER, left INTEGER, odue INTEGER, odid INTEGER, flags INTEGER);
CREATE TABLE revlog(id INTEGER PRIMARY KEY, cid INTEGER, usn INTEGER, ease INTEGER, ivl INTEGER, lastIvl INTEGER, factor INTEGER, time INTEGER, type INTEGER);
INSERT INTO col VALUES(1700000000, '$MODELS', '$DECKS');
INSERT INTO notes VALUES
  (101, 'uitest-yama', 20, '山${SEP}mountain', ''),
  (102, 'uitest-kawa', 20, '川${SEP}river', ''),
  (103, 'uitest-hi',   20, '日${SEP}sun', '');
INSERT INTO cards VALUES
  (201, 101, 40, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0),
  (202, 102, 40, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0),
  (203, 103, 40, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0);
SQL

printf '{}' > "$WORK_DIR/media"
rm -f "$OUTPUT"
(cd "$WORK_DIR" && zip -q -X "$OUTPUT" collection.anki2 media)
echo "Wrote $OUTPUT"
