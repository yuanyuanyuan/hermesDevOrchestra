import json
import re

with open('/data/hermes/.tmp_index_work/extracted_C_ug_nonskills.json') as f:
    data = json.load(f)

weak_concepts = {
    '/store', '/hermes', '/docker', '/entrypoint', '/me', '/projects', '/jobs', '/scripts',
    '/long-task-alert', '/pico', '/usage', '/agents', '/pause', '/reload', '/mouse', '/off',
    '/antenna-matches', '/test', '/plugins', '/register', '/login', '/session', '/token',
    '/boards', '/host', '/local', '/loopback', '/jo-inc', '/camofox-browser', '/camofox',
    '/experiments', '/rl-runner', '/documents', '/tmp', '/compress', '/zero-priced',
    '/claude-sonnet-4', '/log', '/cheap', '/claude', '/gemini', '/home', '/you', '/code',
    '/reports', '/github', '/root', '/null', '/boot-md', '/var', '/worktree',
    '/hermes-checkpoints-do', '/hermes-checkpoints-docs', '/native', '/redo', '/model',
    '/sessions', '/terminal-setup', '/ui-tui'
}

weak_prefixes = ('see also:', 'hermes will:', 'in separate terminals:', 'each hermes process:',
                 'can use ', 'now you can ', 'quick start:', 'running multiple', 'cleaning up',
                 'ares agent', 'poseidon agent', 'sisyphus agent', 'charizard agent',
                 'hermes agent\n', 'example', 'examples:', 'built-in personalities',
                 'security scanning', 'those belong in', 'if you use a custom home:',
                 'grant the', 'callback signature:', 'return value:', 'fires:\n',
                 'personality', 'change skins', 'or set the default skin in')

def clean_concept(c):
    c = c.strip()
    c = re.sub(r'\s+', ' ', c)
    return c

def is_weak_concept(c):
    c_lower = c.lower()
    if c_lower in {w.lower() for w in weak_concepts}:
        return True
    for prefix in weak_prefixes:
        if c_lower.startswith(prefix):
            return True
    return False

for p in data:
    # Clean key_concepts
    cleaned = []
    seen = set()
    for c in p['key_concepts']:
        c = clean_concept(c)
        if not c or len(c) < 3:
            continue
        if is_weak_concept(c):
            continue
        if c.lower() in seen:
            continue
        seen.add(c.lower())
        cleaned.append(c)
    p['key_concepts'] = cleaned[:10]
    
    # Clean code snippets
    cleaned_snippets = []
    seen_snippets = set()
    for s in p['code_snippets']:
        s = s.strip()
        # Remove status bar artifacts
        if '│' in s and ('K/' in s or '$' in s or '%' in s):
            continue
        # Clean garbled concatenation
        s = re.sub(r'([a-zA-Z0-9])#', r'\1 #', s)
        s = re.sub(r'([a-zA-Z0-9])hermes', r'\1 hermes', s)
        s = re.sub(r'([a-zA-Z0-9])docker', r'\1 docker', s)
        s = re.sub(r'([a-zA-Z0-9])mkdir', r'\1 mkdir', s)
        s = re.sub(r'([a-zA-Z0-9])cd ', r'\1 cd ', s)
        s = re.sub(r'([a-zA-Z0-9])git ', r'\1 git ', s)
        s = re.sub(r'([a-zA-Z0-9])pip ', r'\1 pip ', s)
        s = re.sub(r'([a-zA-Z0-9])export ', r'\1 export ', s)
        s = re.sub(r'([a-zA-Z0-9])curl ', r'\1 curl ', s)
        s = re.sub(r'([a-zA-Z0-9])python', r'\1 python', s)
        s = re.sub(r'([a-zA-Z0-9])nousresearch', r'\1 nousresearch', s)
        s = re.sub(r'([a-zA-Z0-9])mkdir', r'\1 mkdir', s)
        s = re.sub(r'([a-zA-Z0-9])node', r'\1 node', s)
        s = re.sub(r'([a-zA-Z0-9])npm', r'\1 npm', s)
        s = re.sub(r'([a-zA-Z0-9])code ', r'\1 code ', s)
        s = re.sub(r'([a-zA-Z0-9])go ', r'\1 go ', s)
        s = re.sub(r'([a-zA-Z0-9])cargo', r'\1 cargo', s)
        s = re.sub(r'([a-zA-Z0-9])cargo', r'\1 cargo', s)
        # Limit length
        if len(s) > 120:
            s = s[:117] + '...'
        key = re.sub(r'\s+', ' ', s.lower())
        if key not in seen_snippets and len(key) > 5:
            seen_snippets.add(key)
            cleaned_snippets.append(s)
    p['code_snippets'] = cleaned_snippets[:5]
    
    # Clean summary - remove artifact words
    summary = p['summary']
    summary = re.sub(r'\s+', ' ', summary)
    p['summary'] = summary.strip()
    
    # Clean embedding_keywords
    kw = p['embedding_keywords']
    # Remove artifacts
    kw = re.sub(r'\b(you|your|this|that|with|from|have|been|being|were|they|them|their|there|then|than|when|where|what|how|who|which|why|would|could|should|may|might|must|shall|will|shall|can|need|does|did|done|has|had|having|get|gets|got|getting|make|makes|made|making|take|takes|took|taking|come|comes|came|coming|see|sees|saw|seeing|know|knows|knew|knowing|think|thinks|thought|thinking|look|looks|looked|looking|use|uses|used|using|find|finds|found|finding|give|gives|gave|giving|tell|tells|told|telling|work|works|worked|working|call|calls|called|calling|try|tries|tried|trying|ask|asks|asked|asking|need|needs|needed|needing|feel|feels|felt|feeling|seem|seems|seemed|seeming|leave|leaves|left|leaving|put|puts|putting|mean|means|meant|meaning|keep|keeps|kept|keeping|let|lets|letting|begin|begins|began|beginning|help|helps|helped|helping|show|shows|showed|showing|hear|hears|heard|hearing|play|plays|played|playing|run|runs|ran|running|move|moves|moved|moving|live|lives|lived|living|believe|believes|believed|believing|bring|brings|brought|bringing|happen|happens|happened|happening|stand|stands|stood|standing|lose|loses|lost|losing|pay|pays|paid|paying|meet|meets|met|meeting|include|includes|included|including|continue|continues|continued|continuing|set|sets|setting|learn|learns|learned|learning|change|changes|changed|changing|lead|leads|led|leading|understand|understands|understood|understanding|watch|watches|watched|watching|follow|follows|followed|following|stop|stops|stopped|stopping|create|creates|created|creating|speak|speaks|spoke|speaking|read|reads|reading|allow|allows|allowed|allowing|add|adds|added|adding|spend|spends|spent|spending|grow|grows|grew|growing|open|opens|opened|opening|walk|walks|walked|walking|win|wins|won|winning|offer|offers|offered|offering|remember|remembers|remembered|remembering|love|loves|loved|loving|consider|considers|considered|considering|appear|appears|appeared|appearing|buy|buys|bought|buying|wait|waits|waited|waiting|serve|serves|served|serving|die|dies|died|dying|send|sends|sent|sending|expect|expects|expected|expecting|build|builds|built|building|stay|stays|stayed|staying|fall|falls|fell|falling|cut|cuts|cutting|reach|reaches|reached|reaching|kill|kills|killed|killing|remain|remains|remained|remaining|suggest|suggests|suggested|suggesting|raise|raises|raised|raising|pass|passes|passed|passing|sell|sells|sold|selling|require|requires|required|requiring|report|reports|reported|reporting|decide|decides|decided|deciding|pull|pulls|pulled|pulling)\b', '', kw)
    kw = re.sub(r'\s+', ' ', kw).strip()
    p['embedding_keywords'] = kw[:500]

with open('/data/hermes/.tmp_index_work/extracted_C_ug_nonskills.json', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"Cleaned {len(data)} pages")
