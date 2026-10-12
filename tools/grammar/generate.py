#!/usr/bin/env python3
"""Offline, deterministic import of the vendored OpenJLPT snapshot. Not a test runner."""
import hashlib
import json
import re
from author_exercises import authored
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tools/grammar/upstream'
OUTPUT = ROOT / 'kanji_test/Data/Grammar'
SHA = '0d1d3410bec90bd4098a7c72de820543cb4f707c'
COUNTS = {'N5': 81, 'N4': 98, 'N3': 101, 'N2': 123, 'N1': 123}

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def generate():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    pin = json.loads((SOURCE.parent / 'snapshot.json').read_text())
    if pin['commit'] != SHA or pin['counts'] != COUNTS:
        raise ValueError('Snapshot metadata changed; pin a reviewed source version explicitly')
    seen = set()
    hashes = {}
    examples = 0
    imported = []
    all_rules = [rule for level in COUNTS
                 for rule in json.loads((SOURCE / (level.lower() + '.json')).read_text())]
    patterns = {}
    for rule in all_rules:
        patterns.setdefault(rule['pattern'], []).append(rule['id'])
    for level, count in COUNTS.items():
        path = SOURCE / (level.lower() + '.json')
        raw = path.read_bytes()
        hashes[path.name] = hashlib.sha256(raw).hexdigest()
        if hashes[path.name] != pin['sourceSHA256'][path.name]:
            raise ValueError(f'Source differs from pinned snapshot: {path.name}')
        rules = json.loads(raw)
        overlay_path = SOURCE.parent / 'localization' / (level.lower() + '.json')
        overlay = json.loads(overlay_path.read_text()) if overlay_path.exists() else {}
        if set(overlay) - {r['id'] for r in rules}:
            raise ValueError(f'Localization references unknown source IDs: {level}')
        if len(rules) != count:
            raise ValueError(f'{level}: source count changed; inspect snapshot before importing')
        for rule in rules:
            if rule['id'] in seen or rule['level'] != level:
                raise ValueError(f'Invalid source identity: {rule["id"]}')
            seen.add(rule['id'])
            for field in ('pattern', 'meaning', 'formation', 'romaji'):
                if not rule.get(field, '').strip():
                    raise ValueError(f'Missing source {field}: {rule["id"]}')
            if not rule.get('examples'):
                raise ValueError(f'Missing source examples: {rule["id"]}')
            examples += len(rule['examples'])
            # Only exact, unambiguous mentions explicitly present in source notes.
            # These are references, not claims of equivalence or inferred prerequisites.
            relations = []
            for pattern, ids in patterns.items():
                if len(ids) != 1 or ids[0] == rule['id'] or not re.fullmatch(r'〜[ぁ-ヿ一-龯]{2,}', pattern):
                    continue
                if re.search(re.escape(pattern) + r'(?![ぁ-ヿ一-龯])', rule.get('notes', '')):
                    relations.append({'ruleID': ids[0], 'kind': 'sourceMention',
                        'explanationRU': 'Конструкция прямо упомянута в исходном примечании. Связь не означает равнозначность.'})
            rule["exercises"] = authored(rule, all_rules)
            if relations:
                rule['relations'] = relations
            if rule['id'] in overlay:
                adaptation = overlay[rule['id']]
                localization = adaptation['localization']
                if not all(isinstance(localization.get(k), str) and localization[k].strip()
                           for k in ('meaningRU', 'formationRU', 'formationNotesRU', 'explanationRU', 'reviewer')):
                    raise ValueError(f'Incomplete Russian lesson: {rule["id"]}')
                translations = adaptation['exampleTranslations']
                if set(translations) != {e['ja'] for e in rule['examples']} or not all(
                        isinstance(value, str) and value.strip() for value in translations.values()):
                    raise ValueError(f'Incomplete source-aligned example translations: {rule["id"]}')
                rule['localization'] = localization
                for example in rule['examples']:
                    example['ru'] = translations[example['ja']]
                rule['exercises'] = adaptation['exercises']
                if len(rule['exercises']) < 3:
                    raise ValueError(f'At least three authored exercises required: {rule["id"]}')
                # Curated relations may distinguish meaning/register/contrast/prerequisites.
                source_ids = {relation['ruleID'] for relation in relations}
                rule['relations'] = relations + [relation for relation in adaptation.get('relations', [])
                                                if relation['ruleID'] not in source_ids]
        imported.extend(rules)
        # Original texts stay byte-for-byte recoverable in upstream/. No invented translations.
        write(OUTPUT / f'grammar-{level.lower()}.json', {
            'schemaVersion': 1,
            'metadata': {'source': 'OpenJLPT', 'repository': 'https://github.com/evanclan/OpenJLPT',
                         'commit': SHA, 'version': '0.3.0', 'license': 'CC-BY-SA-4.0',
                         'authors': ['OpenJLPT contributors', 'Evan Clan'],
                         'modifications': 'Resource envelope, explicit source-note reference links, and any separately authored Russian adaptations; stable source IDs and original texts retained.',
                         'sourceSHA256': hashes[path.name]},
            'rules': rules,
        })
    write(OUTPUT / 'grammar-manifest.json', {'schemaVersion': 1, 'commit': SHA,
        'counts': COUNTS, 'sourceSHA256': hashes,
        'totalRules': len(seen), 'totalExamples': examples,
        'localizedRules': sum('localization' in r for r in imported),
        'sourceAlignedExercises': sum(len(r.get('exercises', [])) for r in imported),
        'exercisesByKind': {kind: sum(e['kind'] == kind for r in imported for e in r.get('exercises', []))
            for kind in ('chooseConstruction','fillBlank','identifyConstruction','chooseCorrectSentence','transformSentence')},
        'translationPolicy': 'on-device-en-ru',
        'releaseReady': all(len(r.get('exercises', [])) >= 3 for r in imported),
        'manualLinguisticReviewClaimed': False})
    print(f'Imported {len(seen)} rules / {examples} examples from {SHA}. Check manifest for localization coverage.')

if __name__ == '__main__':
    generate()
