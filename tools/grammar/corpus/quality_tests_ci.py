#!/usr/bin/env python3
"""Synthetic publication regressions, GitHub Actions only; never publish these fixtures."""
import os
if os.environ.get('GITHUB_ACTIONS') != 'true': raise SystemExit('CI only; local tests are forbidden.')
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import publish
from compile_bank import expand

class PublicationTests(unittest.TestCase):
    def testUnknownTextAndSentenceReferencesFail(self):
        with self.assertRaises(ValueError): expand('@gtext:missing', {}, {})
        with self.assertRaises(KeyError): expand('@gs:missing', {}, {})
    def testTextReferencesAreNotRecursivelyExpanded(self):
        self.assertEqual(expand('@gtext:x', {'@gtext:x': '@gtext:literal'}, {}), '@gtext:literal')
    def testNormalizationResolvesDictionaryKeysForRuby(self):
        result = expand({'@gs:x': '@gtext:reading'}, {'@gtext:reading': '[本|ほん]'}, {'gs:x': {'japanese': '本'}})
        self.assertEqual(result, {'本': '[本|ほん]'})
    def testMorphologyCannotPromoteCandidatesToPublication(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name)
            # A fake fixture is isolated from production records, not a claimed reviewer.
            (folder / 'review.json').write_text(json.dumps({'sentenceReviews': {'fixture': {
                'status': 'algorithmicallyChecked', 'japanese': '本です。'}}, 'usageReviews': [], 'exercises': []}))
            (folder / 'source-candidates.jsonl').write_text(json.dumps({'id': 'fixture', 'japanese': '本です。',
                'sources': [], 'translations': []}) + '\n')
            (folder / 'tatoeba-candidates.jsonl').write_text('')
            with patch.object(publish, 'FOLDER', folder):
                with self.assertRaises(ValueError): publish.approved_material()

if __name__ == '__main__': unittest.main()
