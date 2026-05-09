import json, sys

batch_idx = int(sys.argv[1])
with open('/data/hermes/.tmp_index_work/batch_plan.json') as f:
    plan = json.load(f)

with open('/data/hermes/.tmp_index_work/batch_C_ug_nonskills.jsonl') as f:
    pages = {json.loads(line)['url']: json.loads(line) for line in f if line.strip()}

urls = plan[batch_idx]['urls']
batch_pages = [pages[url] for url in urls]

for p in batch_pages:
    url = p['url']
    title = p['title']
    h1 = p.get('h1', '')
    text = p.get('text', '')
    code = '\n\n'.join(p.get('code_blocks', []))
    print(f"""
{'='*80}
URL: {url}
TITLE: {title}
H1: {h1}
TEXT:
{text}
{'='*40}
CODE_BLOCKS:
{code}
{'='*80}
""")

