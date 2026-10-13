"""Compile explicitly authored contexts. Never synthesize wrong Japanese by substitution.

AutomaticallyChecked means structural validation only. No linguistic review is claimed.
Rules without authored material stay readable; release CI reports their missing lessons.
"""
from pathlib import Path
import json
from functools import lru_cache

COMMIT = '0d1d3410bec90bd4098a7c72de820543cb4f707c'
KIND_NAMES = ('formProduction', 'fillBlank', 'transformSentence', 'assembleSentence', 'chooseContext',
              'correctError', 'distinguishMeaning', 'understandSentence')


@lru_cache(maxsize=1)
def materials():
    return json.loads(Path(__file__).with_name('lessons.json').read_text())

@lru_cache(maxsize=1)
def reviewed_exercises():
    from corpus.publish import approved_material
    return approved_material()[2]


def authored(rule, all_rules):
    lesson = materials().get(rule['id'])
    approved = [e for e in reviewed_exercises() if e['ruleID'] == rule['id']]
    if not lesson:
        return approved
    result = []
    ruby = json.loads(Path(__file__).with_name('furigana.json').read_text())['texts']
    for index, exercise in enumerate(lesson['exercises']):
        value = dict(exercise)
        value.update(id=f'{rule["id"]}:{exercise["slug"]}', ruleID=rule['id'], isScored=True,
                     provenance={'commit': COMMIT, 'sourceRuleID': rule['id'],
                                 'exampleIndex': None, 'method': 'explicit-context-authoring-v2',
                                 'status': 'automaticallyChecked'})
        value.pop('slug')
        texts = [value.get('japanese'), value['promptRU'], value['explanationRU'], value.get('hintRU')]
        texts += [o['text'] for o in value['options']] + [o.get('feedbackRU') for o in value['options']]
        for order in value.get('acceptedOrders', []):
            texts.append(''.join(next(o['text'] for o in value['options'] if o['id'] == oid) for oid in order))
        value['furigana'] = {text: ruby[text] for text in texts if text in ruby}
        value['competency'] = {'formProduction': 'formation', 'fillBlank': 'formation',
            'transformSentence': 'application', 'assembleSentence': 'application',
            'chooseContext': 'context', 'correctError': 'correction',
            'distinguishMeaning': 'contrast', 'understandSentence': 'meaning'}[value['kind']]
        # Algorithm checking verifies the keyed surface only, not the context or distractors.
        if value.get('conjugation'):
            value['provenance']['status'] = 'algorithmicallyChecked'
            value['provenance']['method'] = 'explicit-verb-class-conjugation-v1; context-needs-linguistic-review'
        result.append(value)
    return result + approved
