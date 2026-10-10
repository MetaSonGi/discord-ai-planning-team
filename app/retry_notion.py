"""Run only after checking the page for uncertain writes. Does not call the LLM."""
import asyncio
import json
import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from app.core import save
from app.notion import Notion

async def main():
    load_dotenv()
    ident = sys.argv[1]
    if len(ident) != 32 or any(c not in '0123456789abcdef' for c in ident):
        raise ValueError('Expected 32-character meeting ID')
    root = Path(os.getenv('DATA_DIR', './data'))
    job = json.loads((root / (ident + '.json')).read_text(encoding='utf-8'))
    if not job.get('final'):
        raise ValueError('No final PRD available')
    if job['status'] == 'completed':
        print(job['notion_url'])
        return
    client = Notion(os.environ['NOTION_TOKEN'], os.environ['NOTION_PARENT_PAGE_ID'],
                    os.getenv('NOTION_VERSION', '2022-06-28'))
    try:
        print(await client.publish(job, lambda: save(root, job)))
        job['status'] = 'completed'
        save(root, job)
    finally:
        await client.client.aclose()

if __name__ == '__main__':
    asyncio.run(main())
