#!/usr/bin/env python3
"""Prepare all OpenJLPT examples and explicitly matched original Nihongo Mono entries.

Produces candidates, not scored questions or expert-review claims.
"""
import argparse
import json
import re
from pathlib import Path
from prepare import Analyzer, ROOT, PIN, MONO_PIN, COUNTS, sha, write, profiles, matches


def title_key(text):
    return re.sub(r'[〜～~\s]', '', text)


def prepare(directory, output):
    analyzer = Analyzer()
    rules = [r for level in COUNTS for r in json.loads((ROOT / 'tools/grammar/upstream' / (level.lower() + '.json')).read_text())]
    specifications = {p['ruleID']: p for p in profiles(rules, analyzer)}
    mono = []
    pin = json.loads((Path(__file__).parent / 'nihongo-source-lock.json').read_text())
    for level in COUNTS:
        path = directory / ('nihongo-' + level.lower() + '.json')
        if pin['commit'] != MONO_PIN or sha(path.read_bytes()) != pin['files'][level.lower() + '.json']:
            raise ValueError('Nihongo material differs from the pinned original-grammar snapshot')
        for record in json.loads(path.read_text()): mono.append((level.lower(), record))
    by_title, by_slug = {}, {}
    for level, record in mono:
        by_title.setdefault(title_key(record['title']), []).append((level, record))
        by_slug.setdefault(record['slug'], []).append((level, record))
    selected, usages, source_map = {}, [], {}
    explicit = json.loads((ROOT / 'tools/grammar/nihongo-mono.json').read_text())

    def add(rule, example, source, status='candidate'):
        text = example['ja']; sid = 'gs:' + sha(text.encode())[:24]
        if sid not in selected:
            tokens = analyzer.analyze(text)
            selected[sid] = {'id': sid, 'japanese': text, 'sources': [], 'translations': [],
                'morphology': tokens, 'readingProposal': analyzer.proposal(tokens), 'status': 'algorithmicallyChecked'}
        sentence = selected[sid]
        sentence['sources'].append(source)
        sentence['translations'].append({'id': source['sentenceID'] + ':en', 'language': 'eng',
            'text': example['en'], 'license': source['license'], 'url': source['url'],
            'author': source['author'], 'status': status})
        span = matches(sentence['morphology'], specifications[rule['id']])
        usages.append({'id': rule['id'] + ':' + sid, 'ruleID': rule['id'], 'sentenceID': sid,
            'targetSpan': span, 'grammaticalMeaning': rule['meaning'], 'difficulty': None,
            'segments': [], 'status': 'candidate', 'eligibleForScoring': False,
            'evidence': 'Explicit source entry plus morphological candidate; meaning/span need review'})

    for rule in rules:
        for index, example in enumerate(rule['examples']):
            add(rule, example, {'name': 'OpenJLPT', 'sentenceID': rule['id'] + ':example:' + str(index),
                'author': 'OpenJLPT contributors / Evan Clan', 'license': 'CC-BY-SA-4.0', 'commit': PIN,
                'url': 'https://github.com/evanclan/OpenJLPT/tree/' + PIN, 'sourceRuleID': rule['id'], 'exampleIndex': index})
        # Exact title or exact slug only; ambiguous matches are left unresolved.
        candidates = by_title.get(title_key(rule['pattern']), []) or by_slug.get(rule['id'], [])
        if rule['id'] in explicit:
            candidates = by_slug.get(explicit[rule['id']]['entry']['slug'], [])
        if len(candidates) == 1:
            level, record = candidates[0]
            source_map[rule['id']] = {'commit': MONO_PIN, 'path': 'src/data/grammar/' + level + '.json',
                'upstreamSlug': record['slug'], 'upstreamLevel': record['jlpt'], 'entry': record,
                'mappingStatus': 'candidate', 'mappingEvidence': 'exact title/slug; no semantic approval'}
            for index, example in enumerate(record['examples']):
                add(rule, example, {'name': 'Nihongo Mono', 'sentenceID': record['slug'] + ':example:' + str(index),
                    'author': 'Stefanus Ndaru Wedhatama', 'license': 'MIT', 'commit': MONO_PIN,
                    'url': 'https://github.com/stndaru/nihongo-mono/blob/' + MONO_PIN + '/src/data/grammar/' + level + '.json',
                    'sourceRuleID': record['slug'], 'exampleIndex': index})
        print(rule['level'], rule['id'], len(rule['examples']), len(candidates) == 1)
    output.mkdir(parents=True, exist_ok=True)
    with (output / 'source-candidates.jsonl').open('w') as stream:
        for sentence in sorted(selected.values(), key=lambda s: s['id']):
            stream.write(json.dumps(sentence, ensure_ascii=False, separators=(',', ':')) + '\n')
    write(output / 'source-usages.json', list({u['id']: u for u in usages}.values()))
    write(output / 'nihongo-mappings.json', source_map)
    write(output / 'source-summary.json', {'processedRules': len(rules), 'sourceExampleUsages': len(usages),
        'uniqueSourceSentences': len(selected), 'matchedNihongoRules': len(source_map),
        'openJLPTCommit': PIN, 'nihongoCommit': MONO_PIN, 'linguisticReviewClaimed': False})


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--nihongo-directory', required=True)
    p.add_argument('--output', default=str(Path(__file__).parent))
    args = p.parse_args()
    prepare(Path(args.nihongo_directory), Path(args.output))
