#!/usr/bin/env python3
"""Resource preparation, not a test runner. Full dumps never enter the app or Git.

A morphological match is a candidate, never a semantic approval. No distractors
or scored exercises are invented by this program. See review.json for promotions.
"""
import argparse
import bz2
import csv
import hashlib
import io
import json
import re
import tarfile
from collections import defaultdict
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from importlib.metadata import version
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PIN = '0d1d3410bec90bd4098a7c72de820543cb4f707c'
MONO_PIN = 'ec0ba4a0ce1611c568b0e4f8a223eb8029249a25'
COUNTS = {'N5': 81, 'N4': 98, 'N3': 101, 'N2': 123, 'N1': 123}
AMBIGUOUS_READINGS = {'私', '今日', '明日', '一日', '方', '上手', '大人', '人気', '生', '何', '後'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':')) + '\n')


def rows(path):
    if path.name.endswith('.tar.bz2'):
        with tarfile.open(path, 'r|bz2') as archive:
            for member in archive:
                if member.isfile():
                    # Stream the member; never extract an untrusted archive path.
                    stream = archive.extractfile(member)
                    yield from csv.reader((line.decode('utf-8') for line in iter(stream.readline, b'')),
                        delimiter='\t', quoting=csv.QUOTE_NONE)
    else:
        with bz2.open(path, 'rt', encoding='utf-8') as stream:
            yield from csv.reader(stream, delimiter='\t', quoting=csv.QUOTE_NONE)


def detailed(path, wanted=None):
    return {int(r[0]): {'id': r[0], 'language': r[1], 'text': r[2],
            'author': None if r[3] == r'\N' else r[3], 'added': r[4], 'modified': r[5]}
        for r in rows(path) if len(r) >= 6 and (wanted is None or int(r[0]) in wanted)}


def katakana_to_hiragana(text):
    return ''.join(chr(ord(c) - 0x60) if '\u30a1' <= c <= '\u30f6' else c for c in text)


class Analyzer:
    def __init__(self):
        from sudachipy import dictionary, tokenizer
        self.tokenizer = dictionary.Dictionary(dict='core').create()
        self.mode = tokenizer.Tokenizer.SplitMode.A

    def analyze(self, text):
        tokens = []
        for m in self.tokenizer.tokenize(text, self.mode):
            start, end = m.begin(), m.end()
            if text[start:end] != m.surface():
                raise ValueError('Tokenizer offsets do not reconstruct source text')
            pos = list(m.part_of_speech())
            tokens.append({'surface': m.surface(), 'lemma': m.dictionary_form(), 'pos': pos[:4],
                'conjugationType': pos[4], 'conjugationForm': pos[5], 'reading': m.reading_form(),
                'startUTF8': len(text[:start].encode()), 'endUTF8': len(text[:end].encode()),
                'isOOV': m.is_oov(), 'readingNeedsReview': m.is_oov() or m.surface() in AMBIGUOUS_READINGS})
        return tokens

    def proposal(self, tokens):
        # Only a proposal. A reviewer must accept/override readings before publication.
        return ''.join('[' + t['surface'] + '|' + katakana_to_hiragana(t['reading']) + ']'
            if re.search(r'[一-龯]', t['surface']) and not t['readingNeedsReview']
                and re.fullmatch(r'[ァ-ヺー]+', t['reading']) else t['surface'] for t in tokens)


def profiles(rules, analyzer):
    result = []
    aliases = {'te-iru': ['ている'], 'tai': ['たい'], 'te-hoshii': ['てほしい'],
        'te-mo-ii': ['てもいい'], 'tsumori': ['つもり'], 'you-ni-suru': ['ようにする'],
        'wake-de-wa-nai': ['わけではない', 'わけじゃない']}
    for rule in rules:
        # Candidate discovery only; editor must confirm sense/register/construction boundaries.
        probes = aliases.get(rule['id']) or [p.strip('〜～~ ') for p in rule['pattern'].split(' / ')]
        sequences = []
        for surface in probes:
            if not re.fullmatch(r'[ぁ-ヿ一-龯、]+', surface):
                continue
            prefix = '食べ' if surface.startswith(('て', 'たい', 'たら', 'なければ', 'ない')) else ''
            tokens = analyzer.analyze(prefix + surface)
            tokens = [t for t in tokens if t['startUTF8'] >= len(prefix.encode())]
            if not tokens or any(t['isOOV'] for t in tokens):
                continue
            sequences.append({'surfaceProbe': surface, 'lemmas': [t['lemma'] for t in tokens],
                'partsOfSpeech': [t['pos'][0] for t in tokens]})
        result.append({'ruleID': rule['id'], 'level': rule['level'], 'pattern': rule['pattern'],
            'formation': rule['formation'], 'meaning': rule['meaning'], 'sequences': sequences,
            'status': 'candidate', 'needsSemanticReview': True,
            'limitation': 'Surface/lemma/POS constraints only; intended meaning is not inferred'})
    return result


def matches(tokens, profile):
    for sequence in profile['sequences']:
        count = len(sequence['lemmas'])
        for i in range(len(tokens) - count + 1):
            block = tokens[i:i + count]
            if [t['lemma'] for t in block] != sequence['lemmas']:
                continue
            if [t['pos'][0] for t in block] != sequence['partsOfSpeech']:
                continue
            if profile['ruleID'] == 'tai' and (i == 0 or tokens[i - 1]['pos'][0] != '動詞'):
                continue
            if profile['ruleID'] in ('te-iru', 'te-hoshii', 'te-mo-ii') and (i == 0 or tokens[i - 1]['pos'][0] not in ('動詞', '助動詞')):
                continue
            return {'startUTF8': block[0]['startUTF8'], 'endUTF8': block[-1]['endUTF8']}
    return None


def prepare(args):
    output = Path(args.output); output.mkdir(parents=True, exist_ok=True)
    dump = Path(args.snapshot_dir)
    rules = [r for level in COUNTS for r in json.loads((ROOT / 'tools/grammar/upstream' / (level.lower() + '.json')).read_text())]
    analyzer = Analyzer()
    specs = profiles(rules, analyzer)
    write(output / 'profiles.json', specs)
    snapshot = {'exportDate': args.export_date, 'retrievedAt': datetime.now(timezone.utc).isoformat(),
        'downloadsPage': 'https://tatoeba.org/en/downloads', 'files': [],
        'analyzer': {'name': 'SudachiPy', 'version': version('SudachiPy'), 'dictionary': 'core',
                     'dictionaryVersion': version('SudachiDict-core'), 'splitMode': 'A'}}
    for file in sorted(dump.glob('*.bz2')):
        headers = Path(str(file) + '.headers').read_text()
        modified = re.findall(r'(?im)^last-modified:\s*(.+?)\r?$', headers)[-1]
        if parsedate_to_datetime(modified).date().isoformat() != args.export_date:
            raise ValueError('Mixed export dates; re-pin a consistent official batch')
        # Hash bounded chunks; no multi-hundred-MB allocation on a MacBook Air.
        h = hashlib.sha256()
        with file.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''): h.update(chunk)
        language = file.name[:3]
        url = ('https://downloads.tatoeba.org/exports/per_language/' + language + '/' + file.name
            if file.name.endswith('.tsv.bz2') else 'https://downloads.tatoeba.org/exports/' + file.name)
        snapshot['files'].append({'name': file.name, 'url': url, 'sha256': h.hexdigest(),
            'bytes': file.stat().st_size, 'lastModified': modified})
    write(output / 'snapshot.json', snapshot)
    japanese = detailed(dump / 'jpn_sentences_detailed.tsv.bz2')
    indices = defaultdict(list)
    for row in rows(dump / 'jpn_indices.tar.bz2'):
        if len(row) >= 3 and int(row[0]) in japanese:
            indices[int(row[0])].append({'sentenceID': row[0], 'translationID': row[1], 'text': row[2]})
    cc0 = {int(r[0]) for r in rows(dump / 'sentences_CC0.tar.bz2') if r and r[1] in ('jpn', 'eng', 'rus')}
    # Inverted lemma/POS index avoids 526 full scans per sentence.
    by_first = defaultdict(list)
    for spec in specs:
        for sequence in spec['sequences']:
            key = (sequence['lemmas'][0], sequence['partsOfSpeech'][0])
            if spec not in by_first[key]: by_first[key].append(spec)
    selected, usages, per_rule, found_counts = {}, [], defaultdict(list), defaultdict(int)
    for sid, row in sorted(japanese.items(), key=lambda item: (item[0] not in indices, len(item[1]['text']), item[0])):
        text = row['text']
        if not 8 <= len(text) <= 100 or any(c in text for c in ('\t', '\n', '[', ']')):
            continue
        tokens = analyzer.analyze(text)
        potential = {p['ruleID']: p for t in tokens for p in by_first[(t['lemma'], t['pos'][0])]}
        hits = [(p, matches(tokens, p)) for p in potential.values()]
        hits = [(p, span) for p, span in hits if span is not None]
        for p, span in hits:
            rid = p['ruleID']; found_counts[rid] += 1
            gid = 'gs:' + sha(text.encode())[:24]
            if gid in per_rule[rid] or len(per_rule[rid]) >= args.limit: continue
            per_rule[rid].append(gid)
            usages.append({'id': rid + ':' + gid, 'ruleID': rid, 'sentenceID': gid,
                'targetSpan': span, 'grammaticalMeaning': p['meaning'], 'difficulty': None,
                'segments': [], 'status': 'candidate', 'semanticReview': None,
                'evidence': 'Sudachi lemma/POS sequence; no semantic approval', 'eligibleForScoring': False})
            if sid not in selected:
                selected[sid] = {'id': gid, 'japanese': text, 'sourceRow': row,
                    'morphology': tokens, 'readingProposal': analyzer.proposal(tokens),
                    'indices': indices[sid], 'license': 'CC0-1.0' if sid in cc0 else 'CC-BY-2.0-FR'}
    links = defaultdict(set)
    for row in rows(dump / 'links.tar.bz2'):
        if len(row) >= 2 and int(row[0]) in selected:
            links[int(row[0])].add(int(row[1]))
    wanted = {tid for values in links.values() for tid in values}
    translations = {}
    for lang in ('rus', 'eng'):
        translations.update(detailed(dump / (lang + '_sentences_detailed.tsv.bz2'), wanted))
    sentences = {}
    for sid, record in selected.items():
        source = record.pop('sourceRow')
        record['sources'] = [{'name': 'Tatoeba', 'sentenceID': str(sid), 'author': source['author'],
            'url': 'https://tatoeba.org/en/sentences/show/' + str(sid), 'license': record.pop('license'),
            'exportDate': args.export_date, 'lastModified': source['modified']}]
        record['translations'] = [dict(translations[tid], license='CC0-1.0' if tid in cc0 else 'CC-BY-2.0-FR',
            url='https://tatoeba.org/en/sentences/show/' + str(tid), status='candidate', sourceSentenceID=str(sid))
            for tid in sorted(links[sid]) if tid in translations]
        record['status'] = 'algorithmicallyChecked'
        if record['id'] in sentences:
            existing = sentences[record['id']]
            existing['sources'] += record['sources']; existing['translations'] += record['translations']
        else: sentences[record['id']] = record
    # Batch all five levels, checkpointing coverage after each level, including deficits.
    for level in COUNTS:
        batch = [r['id'] for r in rules if r['level'] == level]
        write(output / (level.lower() + '-coverage.json'), {'level': level, 'rules': [{
            'ruleID': rid, 'foundMorphologicalMatches': found_counts[rid],
            'selectedCandidates': len(set(per_rule[rid])), 'linguisticallyReviewed': 0,
            'missingReviewedContexts': 5, 'candidateSentenceIDs': list(dict.fromkeys(per_rule[rid]))} for rid in batch]})
    with (output / 'tatoeba-candidates.jsonl').open('w') as stream:
        for record in sorted(sentences.values(), key=lambda r: r['id']): stream.write(json.dumps(record, ensure_ascii=False, separators=(',', ':')) + '\n')
    write(output / 'tatoeba-usages.json', list({u['id']: u for u in usages}.values()))
    write(output / 'summary.json', {'processedRules': len(rules), 'japaneseRows': len(japanese),
        'uniqueSelectedSentences': len(sentences), 'selectedUsages': len({u['id'] for u in usages}),
        'morphologicalMatches': sum(found_counts.values()), 'scoredTatoebaExercises': 0,
        'linguisticallyReviewedContexts': 0, 'insufficientRules': [r['id'] for r in rules],
        'audioImported': False, 'releaseReady': False})
    print(json.dumps({'processedRules': len(rules), 'uniqueCandidates': len(sentences), 'reviewed': 0}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--snapshot-dir', required=True)
    parser.add_argument('--export-date', required=True)
    parser.add_argument('--output', default=str(Path(__file__).parent))
    parser.add_argument('--limit', type=int, default=10)
    prepare(parser.parse_args())
