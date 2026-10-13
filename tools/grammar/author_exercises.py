"""Compile explicitly authored contexts. Never synthesize wrong Japanese by substitution.

AutomaticallyChecked means structural validation only. No linguistic review is claimed.
Rules without authored material stay readable; release CI reports their missing lessons.
"""
from pathlib import Path
import json
from functools import lru_cache

COMMIT = '0d1d3410bec90bd4098a7c72de820543cb4f707c'
KIND_NAMES = ('fillBlank', 'transformSentence', 'assembleSentence', 'chooseContext',
              'correctError', 'distinguishMeaning', 'understandSentence')


@lru_cache(maxsize=1)
def materials():
    return json.loads(Path(__file__).with_name('lessons.json').read_text())


def authored(rule, all_rules):
    lesson = materials().get(rule['id'])
    if not lesson:
        return []
    result = []
    for index, exercise in enumerate(lesson['exercises']):
        value = dict(exercise)
        value.update(id=f'{rule["id"]}:{exercise["slug"]}', ruleID=rule['id'], isScored=True,
                     provenance={'commit': COMMIT, 'sourceRuleID': rule['id'],
                                 'exampleIndex': None, 'method': 'explicit-context-authoring-v2',
                                 'status': 'automaticallyChecked'})
        value.pop('slug')
        result.append(value)
    return result
