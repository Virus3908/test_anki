#!/usr/bin/env python3
"""Grammar integrity and release acceptance checks. Execute only in GitHub Actions."""
import argparse
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'kanji_test/Data/Grammar'

def nonempty(value):
    return isinstance(value, str) and bool(value.strip())

def check(release=False):
    pin = json.loads((ROOT / 'tools/grammar/snapshot.json').read_text())
    errors, pending, all_rules = [], [], []
    exercise_ids = set()
    typed_kinds = {'chooseConstruction', 'fillBlank', 'identifyConstruction', 'chooseCorrectSentence', 'transformSentence'}
    type_counts = {kind: 0 for kind in sorted(typed_kinds)}
    counts = {}
    for level, expected in pin['counts'].items():
        filename = level.lower() + '.json'
        source_path = ROOT / 'tools/grammar/upstream' / filename
        raw = source_path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        assert digest == pin['sourceSHA256'][filename], f'Changed pinned source: {level}'
        source = json.loads(raw)
        resource = json.loads((DATA / ('grammar-' + filename)).read_text())
        rules = resource['rules']
        counts[level] = len(rules)
        assert resource['schemaVersion'] == 1
        metadata = resource['metadata']
        assert metadata['commit'] == pin['commit'] and metadata['sourceSHA256'] == digest
        assert metadata['license'] == 'CC-BY-SA-4.0' and metadata['authors']
        assert len(rules) == expected == len(source), f'Incomplete {level}'
        assert [r['id'] for r in rules] == [r['id'] for r in source], f'Changed stable IDs/order: {level}'
        for rule, original in zip(rules, source):
            assert rule['level'] == level
            for key in ('id', 'pattern', 'meaning', 'formation'):
                assert nonempty(rule[key]), f'Empty {key}: {rule["id"]}'
            # Every source field survives unchanged, including absent optional notes.
            for key, value in original.items():
                if key == 'examples':
                    assert len(rule[key]) == len(value)
                    for example, original_example in zip(rule[key], value):
                        assert all(example.get(k) == v for k, v in original_example.items())
                        assert nonempty(example['ja']) and nonempty(example['en'])
                else:
                    assert rule.get(key) == value, f'Lost source {key}: {rule["id"]}'
            localization = rule.get('localization')
            missing = []
            if not localization:
                missing.append('Russian localization')
            else:
                for key in ('meaningRU', 'formationRU', 'formationNotesRU', 'explanationRU', 'reviewer'):
                    if not nonempty(localization.get(key)):
                        errors.append(f'Empty {key}: {rule["id"]}')
                if not all(nonempty(e.get('ru')) for e in rule['examples']):
                    errors.append(f'Incomplete example translations: {rule["id"]}')
            exercises = rule.get('exercises', [])
            if len(exercises) < 3:
                missing.append('three reviewed exercises')
            local_ids = set()
            for exercise in exercises:
                eid = exercise['id']
                assert nonempty(eid) and eid not in exercise_ids and eid not in local_ids
                exercise_ids.add(eid); local_ids.add(eid)
                assert exercise['ruleID'] == rule['id']
                assert exercise['kind'] in typed_kinds
                type_counts[exercise['kind']] += 1
                assert all(nonempty(exercise.get(k)) for k in ('promptRU', 'explanationRU', 'reviewer'))
                options = exercise['options']
                ids = {o['id'] for o in options}
                assert len(ids) == len(options) >= 2
                assert all(nonempty(o['id']) and nonempty(o['text']) for o in options)
                assert len({o['text'].strip() for o in options}) == len(options)
                accepted = set(exercise['acceptedOptionIDs'])
                assert accepted and accepted < ids, f'Invalid answer key: {eid}'
                assert isinstance(exercise['difficulty'], int)
            if missing:
                pending.append({'id': rule['id'], 'level': level, 'missing': missing})
        all_rules.extend(rules)
    assert len(all_rules) == 526 and len({r['id'] for r in all_rules}) == 526
    ids = {rule['id'] for rule in all_rules}
    for rule in all_rules:
        links = rule.get('relations', [])
        assert len({link['ruleID'] for link in links}) == len(links)
        assert all(link['ruleID'] in ids and link['ruleID'] != rule['id'] for link in links)
        assert all(nonempty(link.get('explanationRU')) for link in links)
    for name in ('OpenJLPT-LICENSE.txt', 'OpenJLPT-NOTICE.txt', 'Grammar-NOTICE.txt'):
        assert nonempty((DATA / name).read_text())
    assert 'CC-BY-SA-4.0' in (DATA / 'Grammar-NOTICE.txt').read_text() or 'CC BY-SA 4.0' in (DATA / 'Grammar-NOTICE.txt').read_text()
    if release and pending:
        errors.append(f'{len(pending)} rules lack required localized/reviewed learning content')
    if release:
        for kind in ('chooseConstruction', 'fillBlank', 'identifyConstruction', 'chooseCorrectSentence'):
            if type_counts[kind] == 0:
                errors.append(f'Missing required exercise kind: {kind}')
    report = {'commit': pin['commit'], 'counts': counts, 'rules': len(all_rules),
              'examples': sum(len(r['examples']) for r in all_rules),
              'exercisesByKind': type_counts, 'pendingRules': pending, 'errors': errors,
              'manualLinguisticReviewClaimed': False, 'releaseReady': not pending and not errors}
    artifacts = ROOT / 'artifacts'
    artifacts.mkdir(exist_ok=True)
    (artifacts / 'grammar-quality.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f'526 source rules preserved. Pending release content: {len(pending)} rules.')
    for error in errors:
        print('ERROR:', error)
    return 1 if errors else 0

if __name__ == '__main__':
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise SystemExit('This is a CI-only test/check. Do not execute locally.')
    parser = argparse.ArgumentParser()
    parser.add_argument('--release', action='store_true')
    raise SystemExit(check(parser.parse_args().release))
