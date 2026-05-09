import json

with open('/data/hermes/.tmp_index_work/batch_A_core_unique.jsonl', 'r') as f:
    pages = [json.loads(line) for line in f]

pages.sort(key=lambda p: p['url'])

for i, p in enumerate(pages):
    url = p['url']
    text_len = len(p.get('text', ''))
    title = p.get('title', '')
    print(f"{i+1:2d}. {url} | text_len={text_len}")
