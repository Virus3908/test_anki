#!/usr/bin/env python3
"""Verify actual Tatoeba IDs, unchanged text, direct links, owner and per-ID license."""
import argparse
import json
import os
from pathlib import Path

if os.environ.get('GITHUB_ACTIONS') != 'true': raise SystemExit('CI only; do not run checks locally.')
from prepare import detailed, rows

parser = argparse.ArgumentParser()
parser.add_argument('--snapshot-dir', required=True)
args = parser.parse_args()
dump = Path(args.snapshot_dir)
records = [json.loads(line) for line in Path(__file__).with_name('tatoeba-candidates.jsonl').read_text().splitlines()]
japanese_ids = {int(source['sentenceID']) for record in records for source in record['sources']}
translation_ids = {int(t['id']) for record in records for t in record['translations']}
japanese = detailed(dump / 'jpn_sentences_detailed.tsv.bz2', japanese_ids)
translations = {}
for lang in ('eng', 'rus'):
    translations.update(detailed(dump / (lang + '_sentences_detailed.tsv.bz2'), translation_ids))
required_links = {(t['sourceSentenceID'], t['id']) for record in records for t in record['translations']}
actual_links = set()
for row in rows(dump / 'links.tar.bz2'):
    pair = tuple(row[:2])
    if pair in required_links: actual_links.add(pair)
assert actual_links == required_links
cc0 = {r[0] for r in rows(dump / 'sentences_CC0.tar.bz2') if r and r[0].isdigit() and int(r[0]) in japanese_ids | translation_ids}
for record in records:
    for source in record['sources']:
        row = japanese[int(source['sentenceID'])]
        assert row['text'] == record['japanese'] and row['author'] == source['author']
        assert source['license'] == ('CC0-1.0' if source['sentenceID'] in cc0 else 'CC-BY-2.0-FR')
    for translation in record['translations']:
        row = translations[int(translation['id'])]
        assert row['text'] == translation['text'] and row['author'] == translation['author']
        assert row['language'] == translation['language']
        assert translation['license'] == ('CC0-1.0' if translation['id'] in cc0 else 'CC-BY-2.0-FR')
print(f'{len(records)} selected Tatoeba sentences verified against actual official batch IDs and linked translations.')
