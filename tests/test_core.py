import unittest
import tempfile
import json
from pathlib import Path
from app.core import meeting, save, chunks


class Tests(unittest.IsolatedAsyncioTestCase):
    async def test_peer_context_and_synthesis(self):
        calls, messages, checkpoints, notices = [], [], [], []
        async def ask(role, task, prompt):
            calls.append((role, json.loads(prompt)))
            return f'{role} 의견'
        async def emit(text):
            messages.append(text)
        async def announce(text):
            notices.append(text)
        transcript, final = await meeting('테스트', ask, emit, lambda t: checkpoints.append(list(t)), announce)
        self.assertEqual(len(notices), 3)
        self.assertEqual(len(calls), 9)
        self.assertTrue(all(x[1]['previous'] == '[]' for x in calls[:4]))
        self.assertTrue(all(len(json.loads(x[1]['previous'])) == 4 for x in calls[4:8]))
        self.assertEqual(len(calls[8][1]['transcript']), 8)
        self.assertEqual(len(messages), 8)
        self.assertEqual(len(checkpoints[-1]), 8)
        self.assertEqual(final, '총괄 PM 의견')

    async def test_failure_propagates(self):
        async def ask(*args):
            raise RuntimeError('provider unavailable')
        async def emit(*args):
            pass
        with self.assertRaises(RuntimeError):
            await meeting('x', ask, emit, lambda t: None)

    def test_atomic_storage_and_chunks(self):
        with tempfile.TemporaryDirectory() as root:
            save(root, {'id': 'abc', 'topic': '한글'})
            self.assertEqual(json.loads((Path(root)/'abc.json').read_text(encoding='utf-8'))['topic'], '한글')
            self.assertFalse(list(Path(root).glob('*.tmp')))
        self.assertEqual(''.join(chunks('한'*4001)), '한'*4001)
