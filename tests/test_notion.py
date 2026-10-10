import unittest
import httpx
from app.notion import Notion

class NotionTests(unittest.IsolatedAsyncioTestCase):
    async def test_split_and_completed_retry(self):
        requests, saved = [], []
        def handler(request):
            requests.append(request)
            if request.method == 'POST':
                return httpx.Response(200, json={'id': 'page', 'url': 'https://notion.so/page'})
            return httpx.Response(200, json={'results': []})
        client = Notion('test', 'parent', '2022-06-28')
        await client.client.aclose()
        client.client = httpx.AsyncClient(base_url='https://api.notion.com/v1/', transport=httpx.MockTransport(handler))
        job = {'topic': '시험', 'final': '가'*4000, 'transcript': []}
        try:
            url = await client.publish(job, lambda: saved.append(dict(job)))
            self.assertEqual(url, 'https://notion.so/page')
            self.assertEqual(job['notion_offset'], 3)
            self.assertEqual(len(requests), 2)
            await client.publish(job, lambda: None)
            self.assertEqual(len(requests), 2)
            self.assertEqual(saved[0]['notion_id'], 'page')
        finally:
            await client.client.aclose()

    async def test_uncertain_post_not_retried(self):
        calls = []
        def handler(request):
            calls.append(request)
            raise httpx.ReadTimeout('uncertain')
        client = Notion('test', 'parent', '2022-06-28')
        await client.client.aclose()
        client.client = httpx.AsyncClient(base_url='https://api.notion.com/v1/', transport=httpx.MockTransport(handler))
        try:
            with self.assertRaises(httpx.ReadTimeout):
                await client.publish({'topic':'x'}, lambda: None)
            self.assertEqual(len(calls), 1)
        finally:
            await client.client.aclose()
