"""Normalize immutable examples and existing editorial exercises without inventing tasks."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def identity(text, prefix):
    return prefix + hashlib.sha256(text.encode()).hexdigest()[:24]


def build(rules):
    from corpus.publish import approved_material
    from author_exercises import materials
    approved_sentences, approved_usages, approved_exercises = approved_material()
    texts, sentences, templates, usages = {}, {}, {}, []
    candidates = {}
    for line in (Path(__file__).parent / 'source-candidates.jsonl').read_text().splitlines():
        s = json.loads(line)
        candidates[s['id']] = s
        # Publish existing OpenJLPT examples only; harvesting/review corpus stays outside Bundle.
        sources = [x for x in s['sources'] if x['name'] == 'OpenJLPT']
        if not sources: continue
        sentences[s['id']] = {k: s[k] for k in ('id', 'japanese')}
        sentences[s['id']].update(sources=sources, translations=[t for t in s['translations']
            if any(t['id'] == source['sentenceID'] + ':en' for source in sources)], status='structurallyChecked')
    sentences.update(approved_sentences)

    def text_ref(text):
        if text is None: return None
        sentence_id = identity(text, 'gs:')
        if sentence_id in sentences: return '@' + sentence_id
        key = identity(text, '@gtext:')
        if key in texts and texts[key] != text: raise ValueError('Text identity collision')
        texts[key] = text
        return key

    def add_sentence(text, rule, translation_ru=None):
        key = identity(text, 'gs:')
        if key not in sentences:
            sentences[key] = {'id': key, 'japanese': text, 'sources': [{'name': 'test_anki authored adaptation',
                'sentenceID': key, 'author': 'test_anki contributors', 'license': 'CC-BY-SA-4.0',
                'url': 'https://github.com/Virus3908/test_anki/blob/feature/grammar-learning/tools/grammar/lessons.json'}],
                'translations': [], 'status': 'structurallyChecked'}
        if translation_ru:
            tid = identity(translation_ru, 'ru:')
            if not any(t['id'] == tid for t in sentences[key]['translations']):
                sentences[key]['translations'].append({'id': tid, 'language': 'rus', 'text': translation_ru,
                    'author': 'test_anki contributors', 'license': 'CC-BY-SA-4.0',
                    'url': 'https://github.com/Virus3908/test_anki', 'status': 'structurallyChecked'})
        return key

    for rule in rules:
        rule['exampleReferences'] = [{'sentenceID': identity(e['ja'], 'gs:'),
            'translationID': rule['id'] + ':example:' + str(i) + ':en', 'furigana': e.get('furigana'),
            'translationRU': e.get('ru')} for i, e in enumerate(rule['examples'])]
        lesson = materials().get(rule['id'], {})
        references = []
        preparation = lesson.get('referencePreparation', {})
        for index, (original, russian, reading, target) in enumerate(lesson.get('referenceExamples', [])):
            if preparation.get('status') != 'assistantPrepared' or not russian or not reading or not target:
                raise ValueError('Reference preparation must be explicit; it is not independent review')
            if original.startswith('gs:'):
                candidate = candidates[original]
                # This path admits explicit source examples only, never morphology-only/Tatoeba matches.
                sources = [s for s in candidate['sources'] if s['name'] in ('OpenJLPT', 'Nihongo Mono')]
                if not sources: raise ValueError('Reference needs an original teaching source')
                if original not in sentences:
                    sentences[original] = {k: candidate[k] for k in ('id', 'japanese')}
                    sentences[original].update(sources=sources, translations=candidate['translations'], status='sourceExample')
                sid = original
            else:
                sid = add_sentence(original, rule)
            sentence = sentences[sid]
            ja = sentence['japanese']
            import re
            if re.sub(r'\[([^\[\]|]+)\|[^\[\]]+\]', lambda m: m[1], reading).encode() != ja.encode():
                raise ValueError('Reference ruby must reconstruct exact original bytes')
            if target not in ja or ja.count(target) != 1:
                raise ValueError('Reference target must be an explicit unambiguous span: ' + rule['id'])
            tid = identity(russian, 'ru:')
            if not any(t['id'] == tid for t in sentence['translations']):
                sentence['translations'].append({'id': tid, 'language': 'rus', 'text': russian,
                    'license': 'CC-BY-SA-4.0', 'author': 'test_anki assistant preparation',
                    'url': 'https://github.com/Virus3908/test_anki/blob/feature/grammar-learning/tools/grammar/lessons.json',
                    'status': 'assistantPrepared'})
            uid = rule['id'] + ':reference:' + str(index)
            start = len(ja[:ja.index(target)].encode())
            usages.append({'id': uid, 'ruleID': rule['id'], 'sentenceID': sid, 'segments': [],
                'targetSpan': {'startUTF8': start, 'endUTF8': start + len(target.encode())},
                'skillRU': preparation['skillRU'], 'status': 'assistantPrepared', 'eligibleForScoring': False,
                'evidence': preparation['method']})
            references.append({'sentenceID': sid, 'translationID': tid, 'furigana': reading,
                'usageID': uid, 'status': 'assistantPrepared', 'targetConstruction': target,
                'skillRU': preparation['skillRU']})
        if references: rule['studyExampleReferences'] = references
        ids = []
        for e in rule.get('exercises', []):
            value = json.loads(json.dumps(e))
            sentence = e.get('japanese')
            accepted = [o['text'] for o in e['options'] if o['id'] in e['acceptedOptionIDs']]
            segments = []
            if e['kind'] == 'fillBlank' and len(accepted) == 1:
                sentence = sentence.replace('（　）', accepted[0])
            elif e['kind'] == 'assembleSentence':
                parts = [next(o['text'] for o in e['options'] if o['id'] == oid) for oid in e['acceptedOrders'][0]]
                sentence = ''.join(parts)
                offset = 0
                for i, part in enumerate(parts):
                    end = offset + len(part.encode())
                    segments.append({'id': str(i), 'startUTF8': offset, 'endUTF8': end})
                    offset = end
            elif e['kind'] in ('chooseContext', 'correctError'):
                sentence = accepted[0] if accepted else None
            elif e['kind'] == 'formProduction': sentence = None
            if sentence:
                ru = accepted[0] if e['kind'] == 'understandSentence' and accepted else None
                sid = add_sentence(sentence, rule, ru)
                value['sentenceID'] = sid
                # No guessed target boundaries or semantic chunking. Explicit assembly only.
                usages.append({'id': e['id'], 'ruleID': rule['id'], 'sentenceID': sid,
                    'segments': segments, 'status': 'structurallyChecked', 'eligibleForScoring': bool(e['isScored']),
                    'evidence': 'Existing explicit authored exercise key; independent review pending'})
            if e.get('sentenceID') in approved_sentences:
                value['sentenceID'] = e['sentenceID']
                reviewed_usage = next(u for u in approved_usages.values()
                    if u['ruleID'] == e['ruleID'] and u['sentenceID'] == e['sentenceID'])
                usages = [u for u in usages if u['id'] != e['id']]
                usages.append({'id': e['id'], 'ruleID': e['ruleID'], 'sentenceID': e['sentenceID'],
                    'segments': reviewed_usage['segments'], 'status': 'linguisticallyReviewed',
                    'eligibleForScoring': True, 'evidence': reviewed_usage['semanticEvidence']})
            for field in ('promptRU', 'japanese', 'explanationRU', 'cueEN', 'explanationEN', 'aspect', 'hintRU'):
                if field in value: value[field] = text_ref(value[field])
            for option in value['options']:
                option['text'] = text_ref(option['text']); option['feedbackRU'] = text_ref(option.get('feedbackRU'))
            value['furigana'] = {text_ref(text): text_ref(markup) for text, markup in value.get('furigana', {}).items()}
            templates[e['id']] = value; ids.append(e['id'])
        rule['exerciseTemplateIDs'] = ids
        # Source definitions retain IDs; bodies are materialized by the existing loader.
        rule.pop('examples'); rule.pop('exercises')
    return {'schemaVersion': 1, 'texts': texts, 'sentences': sorted(sentences.values(), key=lambda s: s['id']),
            'usages': usages, 'templates': templates, 'candidatePublicationPolicy': 'No harvested candidates in scored templates'}


def expand(value, texts, sentences):
    if isinstance(value, str) and value.startswith('@gtext:'):
        if value not in texts: raise ValueError('Missing text reference: ' + value)
        return texts[value]
    if isinstance(value, str) and value.startswith('@gs:'): return sentences[value[1:]]['japanese']
    if isinstance(value, list): return [expand(x, texts, sentences) for x in value]
    if isinstance(value, dict): return {expand(k, texts, sentences): expand(v, texts, sentences) for k, v in value.items()}
    return value


def hydrate_resource(resource, bank):
    sentences = {s['id']: s for s in bank['sentences']}
    for rule in resource['rules']:
        if 'exampleReferences' in rule:
            rule['examples'] = []
            for ref in rule['exampleReferences']:
                sentence = sentences[ref['sentenceID']]
                translation = next(t for t in sentence['translations'] if t['id'] == ref['translationID'])
                rule['examples'].append({'ja': sentence['japanese'], 'en': translation['text'],
                    'furigana': ref.get('furigana'), 'ru': ref.get('translationRU')})
        if 'exerciseTemplateIDs' in rule:
            rule['exercises'] = [expand(bank['templates'][eid], bank['texts'], sentences) for eid in rule['exerciseTemplateIDs']]
        if 'studyExampleReferences' in rule:
            rule['studyExamples'] = []
            for ref in rule['studyExampleReferences']:
                sentence = sentences[ref['sentenceID']]
                translation = next(t for t in sentence['translations'] if t['id'] == ref['translationID'])
                if translation['language'] != 'rus': raise ValueError('Prepared reference needs Russian translation')
                rule['studyExamples'].append({'ja': sentence['japanese'], 'ru': translation['text'],
                    'furigana': ref['furigana'], 'status': ref['status'], 'targetConstruction': ref['targetConstruction']})
    return resource
