import json

with open('/data/hermes/.tmp_index_work/extracted_C_ug_nonskills.json') as f:
    data = json.load(f)

url_idx = {p['url']: i for i, p in enumerate(data)}

def patch_page(url, extra_concepts=None, remove_concepts=None, extra_prereqs=None, fix_audience=None):
    if url not in url_idx:
        return
    p = data[url_idx[url]]
    
    if extra_concepts:
        existing = {c.lower() for c in p['key_concepts']}
        for c in extra_concepts:
            if c.lower() not in existing:
                p['key_concepts'].append(c)
                existing.add(c.lower())
    
    if remove_concepts:
        p['key_concepts'] = [c for c in p['key_concepts'] if c.lower() not in {r.lower() for r in remove_concepts}]
    
    if extra_prereqs:
        current = p['prerequisites']
        if current:
            p['prerequisites'] = current + ', ' + extra_prereqs
        else:
            p['prerequisites'] = extra_prereqs
    
    if fix_audience:
        p['audience'] = fix_audience

patch_page(
    'https://hermes-agent.nousresearch.com/docs/user-guide/features/browser',
    extra_concepts=['Browserbase', 'Browser Use', 'Firecrawl', 'CDP', 'agent-browser', 'browser automation'],
    remove_concepts=['javascript', 'loopback', 'jo-inc', 'camofox-browser', 'camofox', 'host', 'local']
)
patch_page(
    'https://hermes-agent.nousresearch.com/docs/user-guide/features/personality',
    extra_concepts=['personality', '/personality', 'system prompt', 'custom persona', 'built-in personalities']
)
patch_page(
    'https://hermes-agent.nousresearch.com/docs/user-guide/git-worktrees',
    extra_concepts=['git worktree', 'hermes -w', 'worktree mode', 'multiple agents', 'parallel agents', 'isolated branch']
)
patch_page(
    'https://hermes-agent.nousresearch.com/docs/user-guide/tui',
    extra_concepts=['hermes --tui', 'TUI', 'Classic CLI', 'terminal UI', 'modal overlays'],
    remove_concepts=['/usage', '/agents', '/pause', '/reload', '/mouse', '/off', '/projects']
)
patch_page(
    'https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/features/browser',
    extra_concepts=['Browserbase', 'Browser Use', 'Firecrawl', 'CDP', 'agent-browser', 'browser automation'],
    remove_concepts=['javascript', 'loopback', 'jo-inc', 'camofox-browser', 'camofox', 'host', 'local']
)
patch_page(
    'https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/features/personality',
    extra_concepts=['personality', '/personality', 'system prompt', 'custom persona', 'built-in personalities']
)
patch_page(
    'https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/git-worktrees',
    extra_concepts=['git worktree', 'hermes -w', 'worktree mode', 'multiple agents', 'parallel agents', 'isolated branch']
)
patch_page(
    'https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/tui',
    extra_concepts=['hermes --tui', 'TUI', 'Classic CLI', 'terminal UI', 'modal overlays'],
    remove_concepts=['/usage', '/agents', '/pause', '/reload', '/mouse', '/off', '/projects']
)
patch_page(
    'https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks',
    remove_concepts=['fires: in']
)
patch_page(
    'https://hermes-agent.nousresearch.com/docs/user-guide/windows-native',
    remove_concepts=['/raw', '/hermes-agent', '/install', '/pico'],
    extra_concepts=['Windows Terminal', 'PowerShell install', 'native Windows']
)
patch_page(
    'https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/windows-native',
    remove_concepts=['/raw', '/hermes-agent', '/install', '/pico'],
    extra_concepts=['Windows Terminal', 'PowerShell install', 'native Windows']
)

patch_page('https://hermes-agent.nousresearch.com/docs/user-guide/checkpoints-and-rollback', fix_audience='intermediate')
patch_page('https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/checkpoints-and-rollback', fix_audience='intermediate')
patch_page('https://hermes-agent.nousresearch.com/docs/user-guide/features/personality', fix_audience='intermediate')
patch_page('https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/features/personality', fix_audience='intermediate')
patch_page('https://hermes-agent.nousresearch.com/docs/user-guide/features/skins', fix_audience='intermediate')
patch_page('https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/features/skins', fix_audience='intermediate')
patch_page('https://hermes-agent.nousresearch.com/docs/user-guide/git-worktrees', fix_audience='intermediate')
patch_page('https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/git-worktrees', fix_audience='intermediate')

for p in data:
    p['key_concepts'] = p['key_concepts'][:10]

with open('/data/hermes/.tmp_index_work/extracted_C_ug_nonskills.json', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

short_concepts = sum(1 for p in data if len(p['key_concepts']) < 5)
print('Pages with <5 concepts after patch: ' + str(short_concepts))
for p in data:
    if len(p['key_concepts']) < 5:
        print('  ' + p['url'] + ': ' + str(p['key_concepts']))
