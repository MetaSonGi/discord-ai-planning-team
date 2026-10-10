import asyncio
import httpx
from app.core import chunks


class Notion:
    def __init__(self, token, parent, version):
        self.parent = parent
        self.client = httpx.AsyncClient(base_url='https://api.notion.com/v1/', timeout=40,
            headers={'Authorization': f'Bearer {token}', 'Notion-Version': version})

    async def request(self, method, path, payload):
        # Only explicit 429 responses are retried: uncertain POST success must not create duplicates.
        for attempt in range(4):
            r = await self.client.request(method, path, json=payload)
            if r.status_code != 429:
                r.raise_for_status()
                return r.json()
            if attempt == 3:
                r.raise_for_status()
            await asyncio.sleep(min(float(r.headers.get('Retry-After', '2')), 60))

    async def publish(self, job, persist):
        if not job.get('notion_id'):
            result = await self.request('POST', 'pages', {
                'parent': {'page_id': self.parent},
                'properties': {'title': {'title': [{'text': {'content': job['topic'][:100]}}]}}
            })
            job.update(notion_id=result['id'], notion_url=result['url'], notion_offset=0)
            persist()
        # Paragraph blocks preserve Markdown as text; rich Markdown conversion is an extension.
        text = job['final'] + '\n\n회의 기록\n' + '\n\n'.join(
            f"{x['stage']} / {x['role']}\n{x['text']}" for x in job['transcript'])
        blocks = [{'object': 'block', 'type': 'paragraph', 'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': part}}]}}
            for part in chunks(text, 1800)]
        offset = job.get('notion_offset', 0)
        for start in range(offset, len(blocks), 50):
            await self.request('PATCH', f"blocks/{job['notion_id']}/children", {'children': blocks[start:start+50]})
            job['notion_offset'] = start + len(blocks[start:start+50])
            persist()
            await asyncio.sleep(0.4)
        return job['notion_url']
