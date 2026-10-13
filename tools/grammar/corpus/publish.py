"""Explicit review-to-publication boundary. Never assigns a reviewer or fabricates keys."""
import json
import re
from pathlib import Path

FOLDER = Path(__file__).parent
ERROR_KINDS = {'verbForm', 'particle', 'tense', 'negation', 'subject', 'context', 'usageRestriction'}


def approved_material():
    review = json.loads((FOLDER / 'review.json').read_text())
    known_rules = {r['id'] for p in (FOLDER.parent / 'upstream').glob('n*.json') for r in json.loads(p.read_text())}
    candidates = {}
    for name in ('source-candidates.jsonl', 'tatoeba-candidates.jsonl'):
        for line in (FOLDER / name).read_text().splitlines():
            s = json.loads(line)
            if s['id'] in candidates:
                candidates[s['id']]['sources'] += s['sources']; candidates[s['id']]['translations'] += s['translations']
            else: candidates[s['id']] = s
    approved, usages = {}, {}
    for sid, decision in review['sentenceReviews'].items():
        original = candidates[sid]
        if decision.get('status') != 'linguisticallyReviewed' or not decision.get('reviewer') or not decision.get('rationale'):
            raise ValueError('Publication requires an explicit review, not a structural pass')
        if decision.get('japanese') != original['japanese']:
            raise ValueError('Review cannot replace a source sentence')
        if not decision.get('translationRU') or not decision.get('translationReview'):
            raise ValueError('Offline Russian translation needs an explicit correspondence review')
        reading = decision.get('reading')
        if reading:
            restored = re.sub(r'\[([^\[\]|]+)\|[^\[\]]+\]', lambda m: m[1], reading)
            if restored.encode() != original['japanese'].encode() or not decision.get('readingReview'):
                raise ValueError('Reading markup needs exact reconstruction and contextual approval')
        approved[sid] = {k: original[k] for k in ('id', 'japanese', 'sources', 'translations')}
        approved[sid].update(status='linguisticallyReviewed', reviewer=decision['reviewer'],
            reviewedTranslationRU=decision['translationRU'], reading=decision.get('reading'))
    for decision in review['usageReviews']:
        sid = decision['sentenceID']; sentence = approved[sid]
        if decision.get('status') != 'linguisticallyReviewed' or not decision.get('reviewer') or not decision.get('semanticEvidence'):
            raise ValueError('Usage requires semantic review for this exact rule, separately from morphology')
        if decision['ruleID'] not in known_rules or not decision.get('grammaticalMeaningRU') or not decision.get('usageRestrictions'):
            raise ValueError('Review must state the exact rule sense and restrictions (or why none apply)')
        if not (1 <= decision.get('difficulty', 0) <= 3): raise ValueError('Missing reviewed difficulty')
        raw = sentence['japanese'].encode(); span = decision['targetSpan']
        if not 0 <= span['startUTF8'] < span['endUTF8'] <= len(raw): raise ValueError('Invalid target span')
        raw[span['startUTF8']:span['endUTF8']].decode('utf-8')
        offset = 0
        for segment in decision['segments']:
            if segment['startUTF8'] != offset or segment['endUTF8'] <= offset: raise ValueError('Unusable semantic blocks')
            raw[offset:segment['endUTF8']].decode('utf-8'); offset = segment['endUTF8']
        if offset != len(raw): raise ValueError('Semantic blocks must reconstruct the unchanged original')
        usages[decision['id']] = decision
    exercises = []
    for record in review['exercises']:
        usage = usages[record['usageID']]
        exercise = record['exercise']
        if exercise['ruleID'] != usage['ruleID']: raise ValueError('Wrong exercise/rule association')
        if exercise['kind'] in ('chooseConstruction', 'identifyConstruction'): raise ValueError('Recognition-only exercise')
        if exercise['kind'] == 'distinguishMeaning' and not exercise.get('requiredRuleIDs'):
            raise ValueError('Cross-construction comparison must declare taught prerequisites')
        keys = set(exercise['acceptedOptionIDs'])
        proofs = record.get('errorCriteria', {})
        if exercise['kind'] == 'assembleSentence':
            keys = {key for order in exercise['acceptedOrders'] for key in order}
        for option in exercise['options']:
            if option['id'] not in keys:
                proof = proofs.get(option['id'], {})
                if proof.get('kind') not in ERROR_KINDS or not proof.get('explanationRU'):
                    raise ValueError('Every rejected option needs a reviewed diagnostic criterion')
                if not option.get('feedbackRU'): option['feedbackRU'] = proof['explanationRU']
        exercise['sentenceID'] = usage['sentenceID']
        exercise['isScored'] = True
        exercise['reviewer'] = usage['reviewer']
        exercise['provenance'] = {'commit': '0d1d3410bec90bd4098a7c72de820543cb4f707c', 'sourceRuleID': usage['ruleID'],
            'exampleIndex': None, 'method': 'explicit-sentence-and-semantic-usage-review', 'status': 'linguisticallyReviewed'}
        exercises.append(exercise)
    return approved, usages, exercises
