#!/usr/bin/env python3
"""CI-only corpus, licensing, morphology and publication-boundary checks."""
import hashlib
import json
import os
import re
from pathlib import Path

if os.environ.get('GITHUB_ACTIONS') != 'true':
    raise SystemExit('CI only. Do not run this validation locally.')

from prepare import Analyzer, ROOT, COUNTS
from publish import approved_material
from compile_bank import hydrate_resource

FOLDER = Path(__file__).parent
lock = json.loads((FOLDER / 'batch-lock.json').read_text())
for name, digest in lock['files'].items():
    assert hashlib.sha256((FOLDER / name).read_bytes()).hexdigest() == digest, name
analyzer = Analyzer()
sentences = {}
allowed = {'CC-BY-2.0-FR', 'CC0-1.0', 'CC-BY-SA-4.0', 'MIT'}
for name in ('source-candidates.jsonl', 'tatoeba-candidates.jsonl'):
    local = set()
    for line in (FOLDER / name).read_text().splitlines():
        s = json.loads(line)
        assert s['id'] not in local
        local.add(s['id'])
        assert s['id'] == 'gs:' + hashlib.sha256(s['japanese'].encode()).hexdigest()[:24]
        assert s['morphology'] == analyzer.analyze(s['japanese']), s['id']
        assert s['status'] == 'algorithmicallyChecked'
        raw = s['japanese'].encode()
        offset = 0
        for token in s['morphology']:
            assert token['startUTF8'] == offset
            assert raw[offset:token['endUTF8']].decode() == token['surface']
            offset = token['endUTF8']
        assert offset == len(raw)
        proposal = s.get('readingProposal')
        if proposal is not None:
            restored = re.sub(r'\[([^\[\]|]+)\|[^\[\]]+\]', lambda m: m[1], proposal)
            assert restored.encode() == raw
        for source in s['sources']:
            assert source['license'] in allowed and source['url'] and source['sentenceID']
            if source['name'] == 'Tatoeba':
                assert source['sentenceID'].isdigit() and source['exportDate'] == '2026-10-10'
                assert source['url'] == 'https://tatoeba.org/en/sentences/show/' + source['sentenceID']
        for translation in s['translations']:
            assert translation['license'] in allowed and translation['text'] and translation['url']
            if translation['url'].startswith('https://tatoeba.org/'):
                assert translation['id'].isdigit()
        if s['id'] in sentences: assert sentences[s['id']]['japanese'] == s['japanese']
        sentences[s['id']] = s
rules = [r for level in COUNTS for r in json.loads((ROOT / 'tools/grammar/upstream' / (level.lower() + '.json')).read_text())]
approved, approved_usages, approved_exercises = approved_material()
rule_ids = {r['id'] for r in rules}
assert len(rule_ids) == 526
profiles = json.loads((FOLDER / 'profiles.json').read_text())
assert {p['ruleID'] for p in profiles} == rule_ids
for name in ('source-usages.json', 'tatoeba-usages.json'):
    usages = json.loads((FOLDER / name).read_text())
    assert len({u['id'] for u in usages}) == len(usages)
    for usage in usages:
        assert usage['ruleID'] in rule_ids and usage['sentenceID'] in sentences
        assert usage['status'] == 'candidate' and usage['eligibleForScoring'] is False
        if usage['targetSpan'] is not None:
            span = usage['targetSpan']; raw = sentences[usage['sentenceID']]['japanese'].encode()
            assert 0 <= span['startUTF8'] < span['endUTF8'] <= len(raw)
            raw[span['startUTF8']:span['endUTF8']].decode()
for level, count in COUNTS.items():
    packet = json.loads((FOLDER / (level.lower() + '-review-packet.json')).read_text())
    assert len(packet['rules']) == count
    assert all(p['level'] == level for p in packet['rules'])
    for p in packet['rules']:
        reviewed_count = len({u['sentenceID'] for u in approved_usages.values() if u['ruleID'] == p['ruleID']})
        assert p['linguisticallyReviewedContexts'] == reviewed_count
        if p['readyForScoring']: assert reviewed_count >= 5 and p['existingAuthoredExercises'] >= 4
# No guessed/spurious Tatoeba templates in the Bundle.
bank = json.loads((ROOT / 'kanji_test/Data/Grammar/grammar-sentence-bank.json').read_text())
assert len({s['id'] for s in bank['sentences']}) == len(bank['sentences'])
assert len({s['japanese'] for s in bank['sentences']}) == len(bank['sentences'])
approved, approved_usages, approved_exercises = approved_material()
for s in bank['sentences']:
    if any(source['name'] == 'Tatoeba' for source in s['sources']): assert s['id'] in approved
for level in COUNTS:
    resource = hydrate_resource(json.loads((ROOT / 'kanji_test/Data/Grammar' / ('grammar-' + level.lower() + '.json')).read_text()), bank)
    for rule in resource['rules']:
        for e in rule['exercises']:
            assert e['kind'] not in ('chooseConstruction', 'identifyConstruction')
            if e.get('sentenceID'): assert any(s['id'] == e['sentenceID'] for s in bank['sentences'])
print('526 rules batched; pinned morphology/source IDs/publication boundaries verified. Semantic approval is separate.')
