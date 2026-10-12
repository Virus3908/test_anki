"""Deterministic source-aligned exercises. No invented Japanese distractors.

Automatic checks establish provenance/identity and literal reconstruction, not
linguistic equivalence or professional review. Source originals are immutable.
"""
import re
from difflib import SequenceMatcher

COMMIT = '0d1d3410bec90bd4098a7c72de820543cb4f707c'
SUPPLEMENTAL_NOTES = {
 'zutsu': 'Attach ずつ to a quantity to indicate an equal amount for each person or item, or an amount repeated at each step. In 二つずつ, each recipient receives two, rather than two being the total for everyone. In 少しずつ, the action proceeds a little at a time. The quantity belongs immediately before ずつ.',
 'me': 'Add 目 after a number and its counter to indicate an ordinal position: 三つ目 means the third item, not a total of three items. Keep the counter appropriate to the counted object; 目 follows the entire number-counter expression. In 右から三つ目, count from the right. This ordinal suffix is distinct from 目 as the noun meaning eye.'
}

def fragments(rule):
    return sorted(set(re.findall(r'[ぁ-ヿ一-龯々]+', rule['pattern'])), key=lambda x: (-len(x), x))

def candidates(rule, all_rules):
    words = set(re.findall(r'[a-z]{3,}', rule['meaning'].lower()))
    def rank(other):
        overlap = len(words & set(re.findall(r'[a-z]{3,}', other['meaning'].lower())))
        return (other['level'] != rule['level'], overlap,
                SequenceMatcher(None, rule['meaning'].lower(), other['meaning'].lower()).ratio(), other['id'])
    return sorted((r for r in all_rules if r['id'] != rule['id']
                   and r['pattern'] != rule['pattern'] and r['meaning'].lower() != rule['meaning'].lower()), key=rank)

def make(rule, suffix, kind, prompt, options, correct, cue, explanation, index=None, method='source-definition-association'):
    return {'id': rule['id'] + ':' + suffix, 'ruleID': rule['id'], 'kind': kind,
            'promptRU': prompt, 'options': options, 'acceptedOptionIDs': [correct],
            'cueEN': cue, 'explanationRU': explanation,
            'explanationEN': rule.get('notes') or SUPPLEMENTAL_NOTES.get(rule['id'], rule['meaning']),
            'difficulty': int(rule['level'][1:]),
            'provenance': {'commit': COMMIT, 'sourceRuleID': rule['id'], 'exampleIndex': index,
                           'method': method, 'status': 'automaticallyChecked'}}

def authored(rule, all_rules):
    others = candidates(rule, all_rules)
    # Reject candidates literally occurring in the target example. Their source
    # meanings must differ as well. No false claim that these real constructs
    # or sentences are ungrammatical in their own contexts.
    example = rule['examples'][0]
    pool = [r for r in others if not any(part in example['ja'] for part in fragments(r))]
    if len(pool) < 3:
        pool = [r for r in others if r['pattern'].lstrip('〜') not in example['ja']]
    alternatives = pool[:3]
    choices = [{'id': rule['id'], 'text': rule['pattern'], 'feedbackRU': None}] + [
        {'id': r['id'], 'text': r['pattern'],
         'feedbackRU': f'Это другая конструкция: {r["pattern"]}. Сравни её с формулой и примером текущего правила.'}
        for r in alternatives]
    exercises = [
        make(rule, 'meaning', 'chooseConstruction',
             'Какая конструкция соответствует этому значению?', choices, rule['id'], rule['meaning'],
             f'Правильный выбор — {rule["pattern"]}. Смысл и ограничения употребления приведены ниже.'),
        make(rule, 'identify-0', 'identifyConstruction',
             'Какая из перечисленных конструкций иллюстрируется в этом предложении?\n' + example['ja'],
             choices, rule['id'], example['en'],
             f'Это исходный пример правила {rule["pattern"]}. Сопоставь японское предложение с переводом и формулой.',
             0, 'source-example-association'),
        make(rule, 'formation', 'chooseConstruction',
             'Выбери конструкцию, которая образуется по этой формуле.', choices, rule['id'], rule['formation'],
             f'Эта формула относится к {rule["pattern"]}. Обрати внимание на форму слова перед конструкцией.')]
    # Sentence selection only when a literal piece of the studied pattern is
    # present. Reject every foreign example containing it, conservatively.
    token = next((part for part in fragments(rule) if part in example['ja']), None)
    if token:
        sentence_choices = []
        for other in others:
            for idx, e in enumerate(other['examples']):
                if not any(part in e['ja'] for part in fragments(rule)) and e['ja'] != example['ja']:
                    sentence_choices.append({'id': other['id'] + ':example:' + str(idx), 'text': e['ja'],
                        'feedbackRU': f'Это грамматически корректный исходный пример другого правила ({other["pattern"]}), но в нём нет проверяемой конструкции {rule["pattern"]}.'})
                    break
            if len(sentence_choices) == 3: break
        if len(sentence_choices) == 3:
            correct = rule['id'] + ':example:0'
            exercises.append(make(rule, 'usage-0', 'chooseCorrectSentence',
                f'Выбери предложение, в котором используется {rule["pattern"]} в изученном значении. Остальные предложения тоже грамматически корректны, но используют другие конструкции.',
                [{'id': correct, 'text': example['ja'], 'feedbackRU': None}] + sentence_choices,
                correct, rule['meaning'], 'Правильный вариант — настоящий пример текущего правила. Другие предложения относятся к другим конструкциям.',
                0, 'literal-pattern-present-foreign-pattern-absent'))
        if len(token) >= 2:
            gap = example['ja'].replace(token, '（　）', 1)
            options = [{'id': rule['id'], 'text': token, 'feedbackRU': None}] + [
                {'id': r['id'], 'text': r['pattern'].lstrip('〜'),
                 'feedbackRU': 'Этот вариант не восстанавливает изученную конструкцию в исходном примере. Сравни восстановленное предложение с формулой урока.'}
                for r in alternatives if r['pattern'].lstrip('〜') != token]
            if len(options) == 4 and len({o['text'] for o in options}) == 4:
                exercises.append(make(rule, 'gap-0', 'fillBlank',
                    'Восстанови пропуск, используя конструкцию из этого урока и сохранив исходный перевод.\n' + gap,
                    options, rule['id'], example['en'],
                    f'Пропущено «{token}». Полное предложение: {example["ja"]}',
                    0, 'literal-source-gap-reconstruction'))
    if rule['id'] == 'tai':
        # Explicitly authored, grammatically controlled transformation. The
        # correct option is byte-identical to OpenJLPT tai example 0.
        options = [
            {'id':'desire','text':example['ja'],'feedbackRU':None},
            {'id':'past','text':'夏休みに沖縄へ行きました。','feedbackRU':'Этот вариант сообщает о совершённой поездке, а не о желании.'},
            {'id':'negative','text':'夏休みに沖縄へ行きません。','feedbackRU':'Этот вариант отрицает поездку; он не выражает желания.'},
            {'id':'negative-past','text':'夏休みに沖縄へ行きませんでした。','feedbackRU':'Этот вариант отрицает поездку в прошлом; он не выражает желания.'}]
        exercises.append(make(rule,'transform-okinawa','transformSentence',
            '夏休みに沖縄へ行きます。\nИзмени сообщение о поездке на желание поехать на Окинаву во время летних каникул.',
            options,'desire',example['en'],
            '行きます → 行きたいです: たい присоединяется к основе ます и выражает желание действующего лица. Прошедшее время и отрицание не передают заданный смысл.',
            0,'authored-masu-stem-desire-transformation'))
    return exercises
