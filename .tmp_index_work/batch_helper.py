import json

with open('/data/hermes/.tmp_index_work/batch_C_ug_nonskills.jsonl', 'r') as f:
    pages = [json.loads(line) for line in f if line.strip()]

pages.sort(key=lambda p: p['url'])

# Compute sizes and find optimal batches
target_min = 60000
target_max = 100000

batches = []
current = []
current_size = 0

for p in pages:
    size = len(p.get('text', '')) + sum(len(c) for c in p.get('code_blocks', []))
    if current_size > 0 and current_size + size > target_max and len(current) >= 3:
        batches.append(current)
        current = [p]
        current_size = size
    else:
        current.append(p)
        current_size += size

if current:
    batches.append(current)

print(f"Total batches: {len(batches)}")
for i, b in enumerate(batches):
    total = sum(len(p.get('text','')) + sum(len(c) for c in p.get('code_blocks',[])) for p in b)
    print(f"Batch {i+1}: {len(b)} pages, {total} chars")
    for p in b:
        s = len(p.get('text','')) + sum(len(c) for c in p.get('code_blocks',[]))
        print(f"  - {p['url']} ({s})")

# Save batch metadata
with open('/data/hermes/.tmp_index_work/batch_plan.json', 'w') as f:
    json.dump([{"count": len(b), "urls": [p['url'] for p in b]} for b in batches], f, indent=2)

