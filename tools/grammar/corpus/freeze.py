#!/usr/bin/env python3
"""Pin a preparation batch and generate honest coverage/review packets for all 526 rules."""
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path
from prepare import ROOT, COUNTS, write


def freeze():
    folder = Path(__file__).parent
    sentences = {}
    for name in ('source-candidates.jsonl', 'tatoeba-candidates.jsonl'):
        for line in (folder / name).read_text().splitlines():
            item = json.loads(line)
            if item['id'] in sentences:
                sentences[item['id']]['sources'] += item['sources']
                sentences[item['id']]['translations'] += item['translations']
            else: sentences[item['id']] = item
    usages = {}
    for name in ('source-usages.json', 'tatoeba-usages.json'):
        for usage in json.loads((folder / name).read_text()):
            # Merge independent discovery evidence, never promote semantic status.
            key = usage['ruleID'] + ':' + usage['sentenceID']
            if key in usages:
                usages[key]['evidence'] += '; ' + usage['evidence']
                if usages[key]['targetSpan'] is None: usages[key]['targetSpan'] = usage['targetSpan']
            else: usages[key] = usage
    by_rule = defaultdict(list)
    for usage in usages.values(): by_rule[usage['ruleID']].append(usage)
    lessons = json.loads((ROOT / 'tools/grammar/lessons.json').read_text())
    from publish import approved_material
    approved_sentences, approved_usages, approved_exercises = approved_material()
    totals, by_level, deficits = [], {}, []
    for level, expected in COUNTS.items():
        source = json.loads((ROOT / 'tools/grammar/upstream' / (level.lower() + '.json')).read_text())
        packets = []
        for rule in source:
            contexts = by_rule[rule['id']]
            count = len(contexts); totals.append(count)
            reviewed_count = len({u['sentenceID'] for u in approved_usages.values() if u['ruleID'] == rule['id']})
            packet = {'ruleID': rule['id'], 'level': level, 'pattern': rule['pattern'],
                'meaningEN': rule['meaning'], 'formation': rule['formation'],
                'candidateContextCount': count, 'targetAnnotatedCandidates': sum(u['targetSpan'] is not None for u in contexts),
                'existingAuthoredExercises': len(lessons.get(rule['id'], {}).get('exercises', [])),
                **({'preparedReferenceExamples': len(lessons[rule['id']]['referenceExamples'])}
                   if lessons.get(rule['id'], {}).get('referenceExamples') else {}),
                'linguisticallyReviewedContexts': reviewed_count,
                'readyForScoring': reviewed_count >= 5 and bool(lessons.get(rule['id'], {}).get('teaching'))
                    and len(lessons.get(rule['id'], {}).get('exercises', [])) >= 4,
                'needed': ['semantic sense/register review', 'verified target span and meaningful segments',
                    'offline Russian explanation/translations', 'diagnostic alternatives and accepted variants'],
                'candidateUsages': contexts}
            packets.append(packet)
            if reviewed_count < 5:
                deficits.append({'ruleID': rule['id'], 'candidateContexts': count, 'missingReviewedContexts': max(0, 5 - reviewed_count)})
        write(folder / (level.lower() + '-review-packet.json'), {'level': level, 'rules': packets})
        by_level[level] = {'rules': len(source), 'candidateUsages': sum(p['candidateContextCount'] for p in packets),
            'rulesWithFiveCandidates': sum(p['candidateContextCount'] >= 5 for p in packets),
            'reviewedRules': sum(p['readyForScoring'] for p in packets), 'existingAuthoredExercises': sum(p['existingAuthoredExercises'] for p in packets)}
        print(level, len(source), by_level[level]['candidateUsages'], 'reviewed=' + str(by_level[level]['reviewedRules']))
    known_translations = [t for s in sentences.values() for t in s['translations']]
    rus = sum(any(t['language'] == 'rus' for t in s['translations']) for s in sentences.values())
    report = {'processedRules': len(totals), 'uniqueCandidateSentences': len(sentences),
        'tatoebaUniqueCandidates': json.loads((folder / 'summary.json').read_text())['uniqueSelectedSentences'],
        'candidateUsages': len(usages), 'meanCandidateContextsPerRule': sum(totals) / len(totals),
        'minimumCandidateContextsPerRule': min(totals), 'byLevel': by_level,
        'sentencesWithLinkedRussian': rus, 'linkedRussianSentenceFraction': rus / len(sentences),
        'translatedSentences': len({s['id'] for s in sentences.values() if s['translations']}),
        'linguisticallyReviewedContexts': len(approved_usages), 'eligibleHarvestedExercises': len(approved_exercises),
        'insufficientRules': deficits, 'candidateCountsAreNotTeachingReadiness': True,
        'releaseReady': not deficits and all(v['reviewedRules'] == v['rules'] for v in by_level.values())}
    manifest = json.loads((ROOT / 'kanji_test/Data/Grammar/grammar-manifest.json').read_text())
    bank = json.loads((ROOT / 'kanji_test/Data/Grammar/grammar-sentence-bank.json').read_text())
    report['publishedExercisesByKind'] = manifest['exercisesByKind']
    report['publishedExercisesByLevel'] = manifest['exercisesByLevel']
    report['publishedTemplateCount'] = len(bank['templates'])
    report['publishedUniqueSentences'] = len(bank['sentences'])
    report['preparedReferenceExamples'] = sum(len(l.get('referenceExamples', [])) for l in lessons.values())
    report['preparedReferencesAreNotLinguisticReview'] = True
    report['publishedTeachingCoverage'] = {}
    for level in COUNTS:
        resource = json.loads((ROOT / 'kanji_test/Data/Grammar' / ('grammar-' + level.lower() + '.json')).read_text())
        rules = resource['rules']
        def contexts(rule):
            return {ref['sentenceID'] for ref in rule.get('exampleReferences', []) + rule.get('studyExampleReferences', [])}
        report['publishedTeachingCoverage'][level] = {
            'rules': len(rules),
            'exampleReferences': sum(len(r.get('exampleReferences', [])) + len(r.get('studyExampleReferences', [])) for r in rules),
            'rulesWithAtLeastFiveExamples': sum(len(contexts(r)) >= 5 for r in rules),
            'rulesWithExtendedPractice': sum(bool(r.get('exerciseTemplateIDs')) for r in rules),
            'scoredExerciseCount': sum(len(r.get('exerciseTemplateIDs', [])) for r in rules),
            'sourceRestorationCount': sum(len(r.get('exampleReferences', [])) for r in rules if not r.get('exerciseTemplateIDs')),
            'completeRules': by_level[level]['reviewedRules']}
    report['exerciseFuriganaFraction'] = sum(bool(e.get('furigana')) for e in bank['templates'].values()) / len(bank['templates'])
    report['furiganaFractionDefinition'] = 'At least one explicitly annotated text in an existing authored exercise; not full glyph coverage'
    write(folder / 'excluded-from-scoring.json', {'reason': 'Semantic mapping/translation/segments not reviewed; morphology is not sufficient',
        'usageIDs': sorted(usages)})
    write(folder / 'coverage-report.json', report)
    names = ['source-candidates.jsonl', 'source-usages.json', 'nihongo-mappings.json', 'source-summary.json',
        'tatoeba-candidates.jsonl', 'tatoeba-usages.json', 'summary.json', 'profiles.json', 'snapshot.json']
    write(folder / 'batch-lock.json', {'schemaVersion': 1,
        'files': {name: hashlib.sha256((folder / name).read_bytes()).hexdigest() for name in names},
        'analyzer': json.loads((folder / 'snapshot.json').read_text())['analyzer']})
    print(json.dumps({k: report[k] for k in ('processedRules', 'uniqueCandidateSentences', 'candidateUsages', 'meanCandidateContextsPerRule', 'minimumCandidateContextsPerRule', 'sentencesWithLinkedRussian')}))


if __name__ == '__main__': freeze()
