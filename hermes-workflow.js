// ========== QUESTION BANK (Phase 1: 一次一问) ==========
const QUESTIONS = [
  { q: '这次改善的核心目标是什么?', dim: '目标',
    opts: [
      { label: '⭐A', text: '7天免登录', rec: '推荐', reason: '业界通行做法，平衡体验与安全' },
      { label: 'B', text: '永远不登录', reason: '安全隐患大，不适合外部客户' },
      { label: 'C', text: '安全超时(30分钟)', reason: '安全性高但体验差' },
    ]},
  { q: '目标用户群体是?', dim: '用户',
    opts: [
      { label: '⭐A', text: '外部付费客户', rec: '推荐', reason: '安全标准需高' },
      { label: 'B', text: '内部员工', reason: '可降低安全要求', skipTo: 3 },
    ]},
  { q: '时间压力如何?', dim: '时间',
    opts: [
      { label: 'A', text: '本周', reason: '范围需大幅缩小' },
      { label: '⭐B', text: '1-2周', rec: '推荐', reason: '合理范围' },
      { label: 'C', text: '不急', reason: '可做完整方案' },
    ]},
  { q: '登录方式偏好?', dim: '方式',
    opts: [
      { label: '⭐A', text: '邮箱+密码', rec: '推荐', reason: '最通用' },
      { label: 'B', text: '第三方登录(Google等)', reason: '需额外集成' },
      { label: 'C', text: '两者都要', reason: '增加工作量' },
    ]},
  { q: '新方案如何处理现有登录?', dim: '迁移',
    opts: [
      { label: '⭐A', text: '替换现有 session', rec: '推荐', reason: '统一方案' },
      { label: 'B', text: '叠加(兼容)', reason: '增加复杂度' },
    ]},
  { q: 'Token 过期时的交互方式?', dim: '过期',
    opts: [
      { label: '⭐A', text: '静默刷新', rec: '推荐', reason: '用户无感知' },
      { label: 'B', text: '弹窗提示', reason: '打断用户' },
      { label: 'C', text: '跳转登录页', reason: '体验最差' },
    ]},
  { q: '验收方式?', dim: '验收',
    opts: [
      { label: '⭐A', text: '自动化测试+手动', rec: '推荐', reason: '覆盖全面' },
      { label: 'B', text: '仅自动化', reason: '效率高但可能遗漏' },
    ]},
  { q: '影响范围?', dim: '范围',
    opts: [
      { label: '⭐A', text: '仅登录接口', rec: '推荐', reason: '最小范围' },
      { label: 'B', text: '登录+注册+密码重置', reason: '范围大，时间紧可能完不成' },
    ]},
  { q: '可观测性需求?', dim: '观测',
    opts: [
      { label: '⭐A', text: '基础日志', rec: '推荐', reason: '足够排查问题' },
      { label: 'B', text: '完整链路追踪', reason: '过度工程' },
    ]},
  { q: 'MVP 范围确认?', dim: 'MVP',
    opts: [
      { label: '⭐A', text: '核心认证流程(登录+刷新)', rec: '推荐', reason: '聚焦核心' },
      { label: 'B', text: '完整认证(含注册+密码重置)', reason: '时间风险' },
    ]},
  { q: '实现方式偏好?', dim: '实现',
    opts: [
      { label: '⭐A', text: '第三方库(jsonwebtoken)', rec: '推荐', reason: '成熟稳定' },
      { label: 'B', text: '自己实现', reason: '维护成本高' },
    ]},
];

// ========== APP ==========
function app() {
  return {
    // --- UI State ---
    userInput: '', rtab: 'detail', activeTaskId: null, selTask: null,
    simBusy: false, autoPlaying: false, autoTimer: null, autoSpeed: 1000,
    interactionPanel: null, // 'question' | 'decision' | 'tdd' | null
    otherInput: '',

    // --- Multi-Project Boards ---
    boards: [
      { id: 'project-alpha', name: '🏢 Project Alpha' },
    ],
    currentBoard: 'project-alpha',
    boardData: {}, // { boardId: { tasks: [], taskSeq: 0, logs: [] } }

    // --- Risk Policy Engine (YAML-like rules) ---
    riskPolicies: [
      { pattern: 'rm -rf', level: 'L3', approver: 'user', timeout: 0, desc: '删除文件系统' },
      { pattern: 'git push --force', level: 'L3', approver: 'user', timeout: 300, desc: '强制推送' },
      { pattern: 'DROP TABLE', level: 'L3', approver: 'user', timeout: 0, desc: '删除数据库表' },
      { pattern: '修改生产配置', level: 'L3', approver: 'user', timeout: 300, desc: '修改生产环境配置' },
      { pattern: '修改 CI/CD', level: 'L2', approver: 'reviewer', timeout: 600, desc: '修改 CI/CD 配置' },
      { pattern: 'git reset --hard', level: 'L3', approver: 'user', timeout: 0, desc: '强制重置' },
      { pattern: '变量重命名', level: 'L1', approver: 'self', timeout: 0, desc: '代码细节' },
      { pattern: 'kubectl delete', level: 'L3', approver: 'user', timeout: 0, desc: '删除 K8s 资源' },
    ],

    // --- Columns ---
    columns: [
      { id:'triage', label:'📥 需求池', color:'text-gray-400' },
      { id:'analyzing', label:'🔍 PM 分析', color:'text-blue-400' },
      { id:'research', label:'🔬 调研', color:'text-cyan-400' },
      { id:'todo', label:'📋 待派发', color:'text-blue-400' },
      { id:'ready', label:'⚡ 就绪', color:'text-amber-400' },
      { id:'running', label:'🔧 执行中', color:'text-emerald-400' },
      { id:'blocked', label:'🔒 阻塞', color:'text-amber-400' },
      { id:'done', label:'✅ 完成', color:'text-emerald-400' },
      { id:'deployed', label:'🚀 已部署', color:'text-purple-400' },
    ],

    // --- Data ---
    tasks: [], taskSeq: 0, logs: [],
    roles: [
      { name:'PM', color:'text-blue-400', active:false, status:'待命', task:'', layer:'可变层' },
      { name:'Orchestrator', color:'text-purple-400', active:false, status:'待命', task:'', layer:'可变层' },
      { name:'Researcher', color:'text-cyan-400', active:false, status:'待命', task:'', layer:'可变层' },
      { name:'Implementer', color:'text-emerald-400', active:false, status:'待命', task:'', layer:'可变层' },
      { name:'Reviewer', color:'text-amber-400', active:false, status:'待命', task:'', layer:'可变层' },
      { name:'QA-Tester', color:'text-pink-400', active:false, status:'待命', task:'', layer:'可变层' },
      { name:'DevOps', color:'text-orange-400', active:false, status:'待命', task:'', layer:'可变层' },
      { name:'SRE-Observer', color:'text-red-400', active:false, status:'待命', task:'', layer:'可变层' },
    ],

    // --- Phase State ---
    phase: 'idle', // idle|clarifying|researching|decomposing|executing|deploying
    qState: { idx: 0, answers: [], otherCount: 0 },
    tddState: { taskId: '', behaviors: [], behIdx: 0, phase: 'RED', status: '' },
    decisionCtx: { title: '', desc: '', options: [] },
    currentRootId: '',
    deployState: { env: 'dev', taskId: '' },
    bp: { impl: 0, rev: 0, ratio: 0, action: '正常' },
    bpHistory: [],
    reqVersion: 1,
    hasCheckpoint: false,
    traceLog: [],
    deadlockCounter: 0,
    archiveCtx: { summary: '', options: [] },
    taskGraphDesc: '',
    taskGraphOptions: [],
    pocFailOptions: [],
    curatorScores: [
      { name: 'jwt-auth-checklist', score: 85 },
      { name: 'memory:token过期配置', score: 72 },
      { name: 'memory:RS256选型', score: 60 },
    ],

    // --- Terminal Proxy (R8) ---
    termHistory: [],
    termInput: '',
    // --- Toolsets (R10) ---
    toolsetRole: 'reviewer',
    toolsetEnabled: ['file_read','kanban_read','kanban_block','kanban_complete','clarify'],
    toolsetDisabled: ['code_execution','delegation','messaging','file_write','terminal'],
    toolsetsData: {
      pm: { enabled: ['kanban','memory','clarify','file_read'], disabled: ['terminal','code_execution','web','browser','delegation'] },
      orchestrator: { enabled: ['kanban','memory','clarify'], disabled: ['terminal','file','code_execution','web','browser','delegation'] },
      researcher: { enabled: ['file_read','web','clarify','kanban','memory'], disabled: ['terminal','code_execution','delegation'] },
      implementer: { enabled: ['terminal','file','code_execution','memory','kanban'], disabled: ['delegation','messaging'] },
      reviewer: { enabled: ['file_read','kanban_read','kanban_block','kanban_complete','clarify'], disabled: ['code_execution','delegation','messaging','file_write','terminal'] },
      'qa-tester': { enabled: ['terminal','file','code_execution','browser','kanban','memory'], disabled: ['delegation','messaging'] },
      'devops-engineer': { enabled: ['terminal','file','code_execution','kanban','memory'], disabled: ['delegation','messaging','web'] },
      'sre-observer': { enabled: ['file','kanban','memory','clarify','web'], disabled: ['terminal','code_execution','delegation'] },
    },

    // --- SRE Reports History ---
    sreReports: [],
    // --- Deploy Report ---
    deployReport: null,
    // --- Audit Events ---
    auditEvents: [],

    // --- Questions ref ---
    questions: QUESTIONS,

    // --- Computed ---
    get inputPlaceholder() {
      if (this.phase === 'idle') return '输入需求，如: 登录体验太差了，每次都要重新登录';
      if (this.phase === 'clarifying') return 'PM 正在澄清需求...';
      return '模拟进行中...';
    },
    get phaseLabel() {
      const m = { idle:'等待输入', clarifying:'Phase 1: 需求澄清', researching:'Phase 1.5: 技术调研',
        decomposing:'Phase 2: 任务拆解', executing:'Phase 3-5: 执行', deploying:'Phase 5.6: 部署' };
      return m[this.phase] || this.phase;
    },
    get canAuto() { return this.tasks.length > 0 && !this.simBusy; },
    get statusText() {
      const total = this.tasks.filter(t => !t.isSubtask || t.column !== 'triage').length;
      const done = this.tasks.filter(t => ['done','deployed'].includes(t.column)).length;
      const blocked = this.tasks.filter(t => t.blocked).length;
      return `任务 ${done}/${total}` + (blocked ? ` | ${blocked} 阻塞` : '');
    },

    colTasks(cid) { return this.boardTasks().filter(t => t.column === cid); },
    boardTasks() { return this.tasks.filter(t => t.board === this.currentBoard); },

    // --- Logging ---
    log(m, c='text-gray-400') {
      const t = new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit',second:'2-digit'});
      this.logs.unshift({ t, m, c });
      if (this.logs.length > 200) this.logs.pop();
    },
    setRole(name, active, status, task='') {
      const r = this.roles.find(r => r.name === name);
      if (r) Object.assign(r, { active, status, task });
    },
    selectTask(t) { this.selTask = t; this.activeTaskId = t.id; this.rtab = 'detail'; },

    // --- Task CRUD ---
    mkTask(title, assignee, desc, parents=[], extra={}) {
      this.taskSeq++;
      const badges = { PM:'bg-blue-500/15 text-blue-400', Orchestrator:'bg-purple-500/15 text-purple-400',
        Researcher:'bg-cyan-500/15 text-cyan-400', Implementer:'bg-emerald-500/15 text-emerald-400',
        Reviewer:'bg-amber-500/15 text-amber-400', 'QA-Tester':'bg-pink-500/15 text-pink-400',
        DevOps:'bg-orange-500/15 text-orange-400', 'SRE-Observer':'bg-red-500/15 text-red-400' };
      const t = { id: `T${this.taskSeq}`, column: 'triage', assignee, assigneeBadge: badges[assignee]||'bg-gray-500/15 text-gray-400',
        title, description: desc, parents, blocked: false, blockReason: '', blockOptions: [],
        handoff: '', testResults: '', deployInfo: '', behaviors: [], isSubtask: false,
        rollbackCount: 0, board: this.currentBoard, ...extra };
      this.tasks.push(t);
      return t;
    },
    moveTask(t, col) { t.column = col; },
    promoteReady() {
      this.tasks.forEach(t => {
        if (t.column === 'todo') {
          const ok = t.parents.every(pid => { const p = this.tasks.find(x => x.id === pid); return p && ['done','deployed'].includes(p.column); });
          if (ok) { t.column = 'ready'; this.log(`${t.id} → ready (parents 满足)`); }
        }
      });
      this.calcBP();
    },
    calcBP() {
      this.bp.impl = this.tasks.filter(t => t.column === 'ready' && t.assignee === 'Implementer').length;
      this.bp.rev = this.tasks.filter(t => t.column === 'ready' && (t.assignee === 'Reviewer' || t.assignee === 'QA-Tester')).length;
      const instant = this.bp.impl / Math.max(this.bp.rev, 1);
      this.bpHistory.push(instant);
      if (this.bpHistory.length > 5) this.bpHistory.shift();
      const avg = this.bpHistory.reduce((a,b) => a+b, 0) / this.bpHistory.length;
      this.bp.ratio = avg;
      this.bp.action = this.bp.ratio <= 2 ? '正常' : this.bp.ratio <= 4 ? '降速' : '暂停';
    },

    // ==================== SUBMIT REQUIREMENT ====================
    submitRequirement() {
      const text = this.userInput.trim();
      if (!text || this.simBusy) return;
      this.simBusy = true; this.userInput = '';
      this.phase = 'clarifying';
      this.addTrace('User', 'submit_requirement', text);

      // Feature 9: Multi-requirement priority
      const existingTriage = this.boardTasks().filter(t => t.column === 'triage' && !t.isSubtask);
      if (existingTriage.length > 0) {
        const names = existingTriage.map(t => t.title).join(' → ');
        this.simBusy = false;
        this.interactionPanel = 'decision';
        this.decisionCtx = {
          title: '多需求优先级排序',
          desc: `Board 上已有需求: ${names} → ${text}`,
          options: [
            { label: '✅ 确认顺序', desc: '新需求追加到末尾', action: 'confirm_priority' },
            { label: '🔝 新需求优先', desc: '新需求排到最前', action: 'new_first' },
          ]
        };
        // Store for later
        this._pendingReq = text;
        return;
      }

      this._doSubmitRequirement(text);
    },
    _doSubmitRequirement(text) {
      const root = this.mkTask(text, 'PM', '用户提交的原始需求，等待 PM 分析...', []);
      root.column = 'analyzing';
      this.setRole('PM', true, '接收需求', root.id);
      this.log(`<b>需求提交:</b> "${text}"`, 'text-blue-400');
      this.selectTask(root);
      this.currentRootId = root.id;

      // PM: 技术发现
      setTimeout(() => {
        root.description = '<b>技术发现中...</b><br>读 CLAUDE.md → 项目入口<br>按指引: Cargo.toml → Axum 0.7, sqlx, 无 JWT 依赖<br>src/routes/users.rs → session-based 登录<br>src/middleware/ → 无 auth 中间件';
        this.log('PM 技术发现完成: Axum + session-based, 无 JWT', 'text-blue-400');
        this.addTrace('PM', 'tech_discovery', 'Axum + session-based');
        // 开始一次一问
        this.qState = { idx: 0, answers: [], otherCount: 0 };
        this.interactionPanel = 'question';
        this.simBusy = false;
      }, 1500);
    },

    // ==================== ANSWER QUESTION ====================
    answerQuestion(opt) {
      const q = QUESTIONS[this.qState.idx];
      this.qState.answers.push({ dim: q.dim, answer: opt.text, label: opt.label });
      this.qState.otherCount = 0; // reset convergence counter for this question

      // 冲突检测: 范围大+时间紧
      if (q.dim === '时间' && opt.label === 'A') {
        const scope = this.qState.answers.find(a => a.dim === '范围');
        if (scope && scope.answer.includes('登录+注册')) {
          this.log('⚠ <span class="text-red-400">冲突检测: 范围大 vs 时间紧</span>', 'text-amber-400');
          this.interactionPanel = 'decision';
          this.decisionCtx = {
            title: '⚠ 可行性冲突', desc: '范围: 完整认证 vs 时间: 本周 — 不可行',
            options: [
              { label: 'A) 缩小范围', desc: '仅做核心认证(登录+刷新)', action: 'shrink_scope' },
              { label: 'B) 延长时间', desc: '改为 1-2 周', action: 'extend_time' },
            ]
          };
          return;
        }
      }

      this.log(`Q${this.qState.idx+1} ${q.dim}: <span class="text-emerald-400">${opt.text}</span>`, 'text-gray-400');
      this.addTrace('PM', `Q${this.qState.idx+1} answered`, `${q.dim}: ${opt.text}`);

      // Dynamic ordering: skipTo support
      if (opt.skipTo !== undefined) {
        this.log(`跳转: Q${this.qState.idx+1} → Q${opt.skipTo+1} (skipTo)`, 'text-amber-400');
        this.addTrace('PM', 'skip_to', `Q${opt.skipTo+1}`);
        this.qState.idx = opt.skipTo;
      } else {
        this.qState.idx++;
      }

      // Save checkpoint every question
      this.saveCheckpoint();

      if (this.qState.idx >= QUESTIONS.length) {
        this.finishClarification();
      }
    },

    // ==================== DECISION ====================
    makeDecision(action) {
      this.interactionPanel = null;
      if (action === 'shrink_scope') {
        this.log('用户选择缩小范围: 仅核心认证', 'text-amber-400');
        this.qState.answers.push({ dim: '范围', answer: '仅登录接口', label: '⭐A' });
        this.qState.idx++;
        if (this.qState.idx >= QUESTIONS.length) { this.finishClarification(); return; }
        this.interactionPanel = 'question';
      } else if (action === 'confirm_req') {
        this.log('用户 <span class="text-emerald-400">确认需求 v1</span>', 'text-gray-400');
        this.startResearch();
      } else if (action === 'revise_req') {
        this.log('用户要求修改需求, PM 重新澄清...', 'text-amber-400');
        this.qState = { idx: 7, answers: this.qState.answers.slice(0,7) };
        this.interactionPanel = 'question';
      } else if (action === 'poc_needed') {
        this.log('PM 判断需要 POC 验证', 'text-cyan-400');
        this.startPOC();
      } else if (action === 'poc_skip') {
        this.log('PM 判断无需 POC, 直接进入拆解', 'text-blue-400');
        this.startDecomposition();
      } else if (action === 'approve_staging') {
        this.log('用户 <span class="text-emerald-400">批准 staging 部署</span>', 'text-gray-400');
        this.deployToEnv('staging');
      } else if (action === 'uat_pass') {
        this.log('用户 <span class="text-emerald-400">UAT 验收通过</span>', 'text-gray-400');
        this.deployToEnv('production');
      } else if (action === 'uat_fail') {
        this.log('用户 <span class="text-red-400">发现问题</span>', 'text-gray-400');
        this.addTrace('User', 'uat_fail');
        // Feature 4: Keep deploy task blocked
        const deployTask = this.tasks.find(t => t.id === this.deployState.taskId);
        if (deployTask) {
          deployTask.blocked = true;
          deployTask.blockReason = 'UAT 失败, 等待修复';
        }
        const fix = this.mkTask('修复 UAT 发现的问题', 'Implementer', '根据用户反馈修复, 完成后自动 unblock deploy 任务', []);
        fix.column = 'ready';
        // Store deploy task id in fix task for auto-unblock
        fix._unblockDeployId = this.deployState.taskId;
        this.promoteReady();
        setTimeout(() => this.runNext(), 500);
      } else if (action === 'approve_prod') {
        this.log('用户 <span class="text-emerald-400">批准 production 部署</span>', 'text-gray-400');
        this.deployToEnv('production');
      } else if (action === 'abort_deploy') {
        const dt = this.tasks.find(t => t.id === this.deployState.taskId);
        if (dt) { dt.column = 'done'; dt.description += '<br><span class="text-red-400">用户放弃部署</span>'; }
        this.setRole('DevOps', false, '待命');
        this.checkAllDone();
      } else if (action === 'risk_approve') {
        this.log('用户 <span class="text-emerald-400">批准 L3 风险命令</span>, Worker 继续执行', 'text-gray-400');
        const blocked = this.tasks.find(t => t.blocked && t.blockReason.includes('L3'));
        if (blocked) { blocked.blocked = false; blocked.blockReason = ''; }
        this.interactionPanel = null;
        this.simBusy = false;
      } else if (action === 'risk_reject') {
        this.log('用户 <span class="text-red-400">拒绝 L3 风险命令</span>, 任务保持 blocked', 'text-gray-400');
        this.addTrace('User', 'risk_reject');
        this.interactionPanel = null;
        this.simBusy = false;
      } else if (action === 'retry_deploy') {
        // Feature 3: Retry deploy to current env
        this.log('用户选择 <span class="text-blue-400">修复重试</span>, 重新部署到 staging', 'text-gray-400');
        this.addTrace('User', 'retry_deploy');
        this.deployToEnv('staging');
      } else if (action === 'confirm_priority') {
        // Feature 9: Confirm priority order
        this.interactionPanel = null;
        this.simBusy = true;
        this.log('用户确认需求顺序: 新需求追加到末尾', 'text-blue-400');
        this.addTrace('User', 'confirm_priority');
        this._doSubmitRequirement(this._pendingReq);
        this._pendingReq = '';
      } else if (action === 'new_first') {
        // Feature 9: New requirement first
        this.interactionPanel = null;
        this.simBusy = true;
        this.log('用户选择新需求优先', 'text-blue-400');
        this.addTrace('User', 'new_first_priority');
        this._doSubmitRequirement(this._pendingReq);
        this._pendingReq = '';
      } else if (action === 'approve_archive') {
        // Feature 17: Approve archive
        this.interactionPanel = null;
        this.log('用户 <span class="text-emerald-400">批准归档</span>, 全流程结束', 'text-gray-400');
        this.addTrace('User', 'approve_archive');
        this.curatorScores.push({ name: 'jwt-auth-module', score: 88 });
      } else if (action === 'add_requirement') {
        // Feature 17: Add more requirements
        this.interactionPanel = null;
        this.log('用户选择 <span class="text-blue-400">追加需求</span>', 'text-gray-400');
        this.addTrace('User', 'add_requirement');
        this.reqVersion++;
        this.phase = 'idle';
        this.simBusy = false;
        this.userInput = '';
      } else if (action === 'trigger_sre') {
        const faultTask = this.tasks.find(t => t.rollbackCount > 0 && t.assignee === 'DevOps');
        this.triggerSRE(faultTask ? faultTask.id : 'T-deploy');
      } else if (action === 'skip_sre') {
        this.log('跳过 SRE 分析, 重新部署...', 'text-gray-400');
        this.interactionPanel = null;
        this.simBusy = false;
        setTimeout(() => this.runNext(), 500);
      } else if (action === 'block_architecture') {
        // Implementer blocks on architecture decision → auto-create Reviewer subtask
        this.log('Implementer <span class="text-amber-400">kanban_block("reviewer-needed: RS256 vs HS256?")</span>', 'text-gray-400');
        const implTask = this.tasks.find(t => t.id === this.tddState.taskId);
        if (implTask) { implTask.blocked = true; implTask.blockReason = '等待 Reviewer 决策: RS256 vs HS256'; }
        this.setRole('Implementer', true, 'blocked', this.tddState.taskId);
        // Auto-create Reviewer task
        const revTask = this.mkTask('审查: JWT 算法选型', 'Reviewer', 'T1 需要决策: 用 RS256 还是 HS256?', [], { priority: 'high' });
        revTask.column = 'ready';
        this.promoteReady();
        this.log('Dispatcher 自动创建 Reviewer 子任务', 'text-purple-400');
        setTimeout(() => this.runNext(), 800);
      } else if (action === 'reviewer_decide_rs256') {
        // Reviewer decides
        this.log('Reviewer 决策: <span class="text-emerald-400">用 RS256 (支持 key rotation)</span>', 'text-amber-400');
        // Unblock implementer task
        const implTask = this.tasks.find(t => t.id === this.tddState.taskId);
        if (implTask) {
          implTask.blocked = false; implTask.blockReason = '';
          implTask.handoff += '\ndecision: RS256 (from Reviewer)';
        }
        this.setRole('Reviewer', false, '待命');
        this.setRole('Implementer', true, 'TDD 编码', this.tddState.taskId);
        // Continue TDD
        this.interactionPanel = 'tdd';
        this.simBusy = false;
      }
    },

    // ==================== FINISH CLARIFICATION ====================
    finishClarification() {
      this.interactionPanel = null;
      const root = this.tasks.find(t => t.id === this.currentRootId);
      if (!root) return;
      this.addTrace('PM', 'finish_clarification', `v${this.reqVersion}`);

      // DoR 验证
      this.log('<b>DoR 验证门 (7项检查)</b>', 'text-blue-400');
      const dor = ['目标明确 ✓', '用户群体确定 ✓', '时间约束明确 ✓', '技术方案可行 ✓', '范围无歧义 ✓', '验收标准清晰 ✓', '无未解决冲突 ✓'];
      dor.forEach(d => this.log(`  ${d}`, 'text-emerald-400'));
      this.log('DoR 验证 <span class="text-emerald-400">全部通过</span>', 'text-blue-400');

      // Feature 7: Version control
      root.description = `<b>需求文档 v${this.reqVersion}</b><br>` + this.qState.answers.map(a => `${a.dim}: ${a.answer}`).join('<br>') + '<br><br>DoR ✅ | 证据索引: src/routes/users.rs:45, src/middleware/mod.rs:8';
      if (this.reqVersion > 1) {
        root.description += `<br><br><span class="text-amber-400">版本历史: 从 v1 更新到 v${this.reqVersion}</span>`;
      }
      root.column = 'blocked'; root.blocked = true;
      root.blockReason = '等待确认需求';
      root.blockOptions = [
        { label: `✅ 确认需求 v${this.reqVersion}`, desc: '进入技术研判', action: 'confirm_req' },
        { label: '📝 修改需求', desc: '重新澄清', action: 'revise_req' },
      ];

      // Feature 8: Quality feedback (show before confirm decision)
      this.interactionPanel = 'feedback';
      this.setRole('PM', true, '等待反馈');
    },

    // ==================== PHASE 1.5: RESEARCH ====================
    startResearch() {
      this.phase = 'researching';
      const root = this.tasks.find(t => t.id === this.currentRootId);
      if (root) { root.blocked = false; root.column = 'analyzing'; }
      this.log('PM 判断: JWT 认证涉及未用过的技术栈 → <span class="text-cyan-400">需要 Research</span>', 'text-blue-400');
      this.addTrace('PM', 'start_research', 'JWT tech stack');

      const res = this.mkTask('JWT 技术方案调研', 'Researcher', '调研 JWT 签名方案(RS256 vs HS256)、库选型、安全性', [this.currentRootId]);
      res.column = 'research';
      this.setRole('Researcher', true, '技术调研', res.id);
      this.log(`Researcher 启动: ${res.id}`, 'text-cyan-400');

      setTimeout(() => {
        res.description = '<b>技术方案</b><br>推荐: RS256 + jsonwebtoken<br>RS256 支持密钥轮换, jsonwebtoken 是 Rust 生态最成熟 JWT 库<br><span class="text-amber-400">建议: 需要 POC 验证签名性能</span>';
        res.handoff = 'proposal: RS256 + jsonwebtoken\nneeds_poc: true\npoc_scope: 验证 RS256 签名性能和密钥轮换';
        res.column = 'done';
        this.setRole('Researcher', false, '待命');
        this.log('Researcher 完成: 推荐 RS256 + jsonwebtoken, 建议 POC', 'text-emerald-400');

        // PM 判断是否需要 POC
        this.interactionPanel = 'decision';
        this.decisionCtx = {
          title: 'Research 完成 — 是否需要 POC?',
          desc: 'Researcher 建议 POC 验证签名性能',
          options: [
            { label: '✅ 需要 POC', desc: '创建 POC 子任务', action: 'poc_needed' },
            { label: '⏭ 跳过 POC', desc: '直接进入拆解', action: 'poc_skip' },
          ]
        };
      }, 2000);
    },

    startPOC() {
      const poc = this.mkTask('JWT RS256 POC 验证', 'Implementer', '在独立 worktree 中验证 RS256 签名性能和密钥轮换', [this.currentRootId]);
      poc.column = 'ready';
      this.setRole('Implementer', true, 'POC 验证', poc.id);
      this.promoteReady();
      this.log(`Implementer 开始 POC: ${poc.id}`, 'text-emerald-400');
      this.addTrace('Implementer', 'poc_start', poc.id);

      setTimeout(() => {
        // 40% chance of POC failure
        const pocPassed = Math.random() > 0.4;
        if (pocPassed) {
          poc.handoff = 'poc_result: success\nbenchmark: 1000 ops/sec\nkey_rotation: normal';
          poc.column = 'done';
          poc.description += '<br><span class="text-emerald-400">POC 通过: 签名 1000 ops/sec, 密钥轮换正常</span>';
          this.setRole('Implementer', false, '待命');
          this.log('POC 通过 ✅', 'text-emerald-400');
          this.addTrace('Implementer', 'poc_pass', '1000 ops/sec');
          this.startDecomposition();
        } else {
          poc.handoff = 'poc_result: failed\nbenchmark: 50 ops/sec (低于阈值)\nkey_rotation: error';
          poc.column = 'done';
          poc.description += '<br><span class="text-red-400">POC 失败: 签名仅 50 ops/sec, 远低于阈值</span>';
          this.setRole('Implementer', false, '待命');
          this.log('POC <span class="text-red-400">失败</span>: 签名性能不达标 (50 ops/sec)', 'text-red-400');
          this.addTrace('Implementer', 'poc_fail', '50 ops/sec', 'error');
          // Show POC failure decision panel
          this.interactionPanel = 'poc_fail';
          this.pocFailOptions = [
            { label: '🔄 换方案重新调研', desc: '回到 Research 阶段', action: 'poc_retry_research' },
            { label: '⬆ 升级用户决策', desc: '让用户决定继续或放弃', action: 'poc_escalate_user' },
            { label: '❌ 放弃任务', desc: '标记完成并记录失败原因', action: 'poc_give_up' },
          ];
          this.simBusy = false;
        }
      }, 2500);
    },

    // ==================== PHASE 2: DECOMPOSITION ====================
    startDecomposition() {
      this.phase = 'decomposing';
      const root = this.tasks.find(t => t.id === this.currentRootId);
      if (root) root.column = 'analyzing';
      this.setRole('PM', true, '拆解任务', this.currentRootId);
      this.log('PM 开始任务拆解...', 'text-blue-400');
      this.addTrace('PM', 'start_decomposition');

      setTimeout(() => {
        const t1 = this.mkTask('实现 JWT 认证模块', 'Implementer', 'TDD: 有效登录→200+token, 无效→401, 缺字段→400', [this.currentRootId]);
        const t2 = this.mkTask('编写认证模块测试', 'Implementer', '单元测试+集成测试, 覆盖正常/异常流程', [t1.id]);
        const t3 = this.mkTask('审查认证模块代码', 'Reviewer', '安全性、代码规范、错误处理', [t1.id]);
        const t4 = this.mkTask('修复审查问题', 'Implementer', '根据 reviewer findings 修复', [t3.id]);
        const t5 = this.mkTask('部署发布', 'DevOps', '三层部署: dev/test → staging → production', [t2.id, t4.id]);
        // Feature 2: QA-Tester independent verification task
        const tqa = this.mkTask('QA 独立验收', 'QA-Tester', '独立运行测试, 验证 behaviors + regression', [t2.id, t4.id]);
        [t1,t2,t3,t4,t5,tqa].forEach(t => { t.column = 'todo'; t.isSubtask = true; });
        root.column = 'done';
        this.setRole('PM', false, '待命');
        this.setRole('Orchestrator', true, '派发任务');
        this.log(`PM 拆解为 6 个子任务: ${t1.id}→${t2.id}+${t3.id}→${t4.id}→${t5.id}+${tqa.id}`, 'text-emerald-400');
        this.addTrace('PM', 'decomposition_done', `6 tasks: ${t1.id}→${t2.id}+${t3.id}→${t4.id}→${t5.id}+${tqa.id}`);

        // Feature 10: User confirms task graph
        this.taskGraphDesc = `${t1.id}(实现) → ${t2.id}(测试) + ${t3.id}(审查) → ${t4.id}(修复) → ${t5.id}(部署) + ${tqa.id}(QA)`;
        this.taskGraphOptions = [
          { label: '✅ 确认任务图', desc: '进入执行阶段', action: 'confirm_graph' },
          { label: '📝 修改拆解', desc: 'PM 重新拆解', action: 'revise_graph' },
        ];
        this.interactionPanel = 'taskgraph';
        this.simBusy = false;
      }, 1500);
    },

    // ==================== PHASE 3-5: EXECUTION ====================
    runNext() {
      this.checkTimeouts();
      this.promoteReady();
      // Check blocked tasks that need Reviewer decision
      const reviewerDecision = this.tasks.find(t => t.blocked && t.blockReason.includes('Reviewer'));
      if (reviewerDecision && reviewerDecision.assignee === 'Implementer') {
        // Reviewer decision task
        const revDone = this.tasks.find(t => t.assignee === 'Reviewer' && t.column === 'done' && t.title.includes('算法'));
        if (!revDone) {
          const revTask = this.tasks.find(t => t.assignee === 'Reviewer' && t.column === 'ready' && t.title.includes('算法'));
          if (revTask) { this.executeTask(revTask); return; }
        }
      }

      const ready = this.tasks.filter(t => t.column === 'ready');
      if (ready.length === 0) {
        this.checkAllDone();
        return;
      }

      // Feature 14: Deadlock detection
      this.deadlockCounter++;
      if (this.deadlockCounter >= 3 && ready.length > 0) {
        const profiles = ready.map(t => t.assignee).join(', ');
        this.log(`<span class="text-red-400">⚠ 检测到潜在死锁: ${profiles} 队列积压超过阈值 (${this.deadlockCounter} 轮无执行)</span>`, 'text-red-400');
        this.addTrace('Dispatcher', 'deadlock_detected', `${profiles} x${this.deadlockCounter}`, 'error');
        this.deadlockCounter = 0; // reset
      }

      // Backpressure check
      const implReady = ready.filter(t => t.assignee === 'Implementer').length;
      const revReady = ready.filter(t => t.assignee === 'Reviewer').length;
      this.calcBP();
      if (this.bp.ratio > 4 && ready[0].assignee === 'Implementer') {
        this.log(`<span class="text-red-400">背压暂停: ratio=${this.bp.ratio.toFixed(1)}>4, 暂停 Implementer 派发</span>`, 'text-gray-400');
        this.addTrace('Dispatcher', 'backpressure_pause', `ratio=${this.bp.ratio.toFixed(1)}`, 'warn');
        // Try non-implementer tasks first
        const nonImpl = ready.find(t => t.assignee !== 'Implementer');
        if (!nonImpl) { this.checkAllDone(); return; }
        this.executeTask(nonImpl);
        return;
      }

      this.deadlockCounter = 0; // reset on successful dispatch
      this.executeTask(ready[0]);
    },

    executeTask(task) {
      task.column = 'running';
      this.setRole(task.assignee, true, '执行中', task.id);
      this.log(`${task.assignee} 开始执行 ${task.id}: ${task.title}`, 'text-emerald-400');
      this.addTrace(task.assignee, 'task_start', `${task.id}: ${task.title}`);

      // Feature 15: Environment snapshot on Worker spawn
      const snapshot = `git: clean, 3 staged\nstorage: 45G free\nhermes: running, 2 workers\nboard: ${this.currentBoard}`;
      task.envSnapshot = snapshot;
      this.addTrace(task.assignee, 'env_snapshot', snapshot);

      if (task.assignee === 'Implementer' && task.title.includes('实现')) {
        this.startTDD(task);
      } else if (task.assignee === 'Reviewer') {
        this.executeReviewer(task);
      } else if (task.assignee === 'QA-Tester') {
        this.executeQA(task);
      } else if (task.assignee === 'DevOps') {
        this.startDeploy(task);
      } else {
        // Generic execution
        setTimeout(() => {
          task.column = 'done';
          this.setRole(task.assignee, false, '待命');
          this.log(`${task.id} 完成`, 'text-emerald-400');
          this.addTrace(task.assignee, 'task_done', task.id);

          // Feature 4: Auto-unblock deploy task after fix task completes
          if (task._unblockDeployId) {
            const deployTask = this.tasks.find(t => t.id === task._unblockDeployId);
            if (deployTask) {
              deployTask.blocked = false;
              deployTask.blockReason = '';
              this.log(`修复完成, 自动 unblock deploy 任务 ${deployTask.id}, 重新部署 staging`, 'text-emerald-400');
              this.addTrace('System', 'auto_unblock_deploy', deployTask.id);
              setTimeout(() => this.deployToEnv('staging'), 800);
              return;
            }
          }

          this.promoteReady();
          setTimeout(() => this.runNext(), 500);
        }, 1500);
      }
    },

    // ==================== TDD (Phase 3) ====================
    startTDD(task) {
      // Derive behaviors from acceptance criteria
      const behaviors = [
        { name: '有效登录→200+token', test: 'test_valid_login_returns_token', status: 'pending' },
        { name: '无效登录→401', test: 'test_invalid_login_returns_401', status: 'pending' },
        { name: '缺失字段→400', test: 'test_missing_fields_returns_400', status: 'pending' },
      ];
      task.behaviors = behaviors;
      this.tddState = { taskId: task.id, behaviors, behIdx: 0, phase: 'RED', status: `行为 A: ${behaviors[0].name}` };
      this.setRole('Implementer', true, 'TDD 基线检查', task.id);

      // Baseline check
      this.log('TDD 基线检查: 跑全量测试...', 'text-emerald-400');
      this.addTrace('Implementer', 'tdd_baseline_start');
      setTimeout(() => {
        this.log('基线通过 ✅ (15/15)', 'text-emerald-400');
        this.addTrace('Implementer', 'tdd_baseline_pass', '15/15');
        // Architecture decision point (at behavior B)
        this.interactionPanel = 'tdd';
        this.simBusy = false;
      }, 1000);
    },

    tddStep() {
      const s = this.tddState;
      const beh = s.behaviors[s.behIdx];
      if (s.phase === 'RED') {
        // RED: write test, should fail
        beh.status = 'red';
        this.log(`<span class="text-red-400">RED</span>: ${beh.test} → 运行... 必须失败`, 'text-gray-400');
        this.addTrace('Implementer', 'tdd_red', beh.test);
        s.phase = 'GREEN';
        s.status = `${beh.name}: 测试已写, 等待实现`;
      } else {
        // GREEN: implement, should pass
        beh.status = 'passed';
        this.log(`<span class="text-emerald-400">GREEN</span>: ${beh.test} → 通过 ✅`, 'text-gray-400');
        this.addTrace('Implementer', 'tdd_green', beh.test);
        s.behIdx++;
        if (s.behIdx >= s.behaviors.length) {
          // All behaviors done
          this.finishTDD();
          return;
        }
        // Architecture decision at behavior B (RS256 vs HS256)
        if (s.behIdx === 1 && !this.tasks.find(t => t.id === s.taskId).handoff.includes('RS256')) {
          this.interactionPanel = 'decision';
          this.decisionCtx = {
            title: '架构决策: JWT 算法选型', desc: 'Implementer 遇到技术选型问题, 必须 block (SOUL.md 强制规则)',
            options: [
              { label: 'kanban_block', desc: '"reviewer-needed: RS256 vs HS256?" → 创建 Reviewer 子任务', action: 'block_architecture' },
            ]
          };
          return;
        }
        s.phase = 'RED';
        s.status = `行为 ${String.fromCharCode(65+s.behIdx)}: ${s.behaviors[s.behIdx].name}`;
      }
    },

    finishTDD() {
      this.interactionPanel = null;
      const task = this.tasks.find(t => t.id === this.tddState.taskId);
      if (!task) return;
      // Regression test
      this.log('全量回归测试...', 'text-emerald-400');
      setTimeout(() => {
        task.testResults = `behaviors: 3/3 passed\nregression: {run:15, passed:15, failed:0}`;
        task.handoff = `behaviors: [{name:"有效登录→200", test:"test_valid_login", status:"passed"}, {name:"无效登录→401", test:"test_invalid_login", status:"passed"}, {name:"缺失字段→400", test:"test_missing_fields", status:"passed"}]\nregression: {run:15, passed:15, failed:0}\ndecisions: ["RS256 for key rotation"]\npitfalls: ["token刷新用滑动窗口"]`;
        task.column = 'done';
        this.setRole('Implementer', false, '待命');
        this.log(`${task.id} TDD 完成: 3 行为全通过, 回归 15/15 ✅`, 'text-emerald-400');
        this.addTrace('Implementer', 'tdd_complete', `${task.id}: 3/3 passed`);
        this.promoteReady();
        setTimeout(() => this.runNext(), 500);
      }, 1500);
    },

    // ==================== REVIEWER (Phase 4) ====================
    executeReviewer(task) {
      // Read parent handoff
      const parent = this.tasks.find(t => task.parents.includes(t.id));
      if (parent) {
        this.log(`Reviewer 读取 ${parent.id} handoff: changed_files, decisions...`, 'text-amber-400');
        this.addTrace('Reviewer', 'read_handoff', parent.id);
      }
      setTimeout(() => {
        // Feature 18: Write operation intercept
        const dangerousCmds = ['rm ', 'write', 'git push', 'DROP', 'git reset --hard'];
        const intercepted = dangerousCmds.find(cmd => task.description.includes(cmd));
        if (intercepted) {
          this.log(`Reviewer 写操作被拦截: <span class="text-red-400">${intercepted}</span>`, 'text-amber-400');
          this.addTrace('Reviewer', 'write_intercepted', intercepted, 'warn');
          this.addAuditEvent('Reviewer写拦截', `Reviewer 尝试执行危险命令: ${intercepted} — 已阻止`, 'warn');
          // Record to audit log
          this.log(`[审计] Reviewer 尝试执行危险命令: ${intercepted} — 已阻止`, 'text-red-400');
        }

        // Find issue
        task.handoff = 'findings: [{severity:"high", file:"src/auth/jwt.rs", issue:"token过期时间硬编码, 应可配置"}]\napproved: false';
        task.column = 'done';
        this.setRole('Reviewer', false, '待命');
        this.log(`Reviewer 审查完成: 发现 1 个高危问题 ⚠`, 'text-amber-400');
        this.log('  <span class="text-red-400">[HIGH] src/auth/jwt.rs: token 过期时间硬编码</span>', 'text-gray-400');
        this.addTrace('Reviewer', 'review_done', '1 high issue');

        // Check if fix task becomes ready
        this.promoteReady();
        setTimeout(() => this.runNext(), 500);
      }, 2000);
    },

    // ==================== DEPLOYMENT (Phase 5.6) ====================
    startDeploy(task) {
      this.phase = 'deploying';
      this.deployState = { env: 'dev', taskId: task.id };
      this.log('DevOps 读取部署配置: 版本号, 部署脚本, 策略', 'text-orange-400');
      this.addTrace('DevOps', 'start_deploy', task.id);

      // Layer 1: dev/test
      this.log('① 部署到 <span class="text-emerald-400">dev/test</span>...', 'text-orange-400');
      setTimeout(() => {
        task.deployInfo = 'dev/test: 部署成功';
        this.log('dev/test 部署成功', 'text-emerald-400');
        // Validation gate
        this.log('验证门控: test_suite + E2E + 性能基准...', 'text-orange-400');
        setTimeout(() => {
          task.deployInfo += '\ndev/test 验证: test=15/15, e2e=5/5, perf=120ms ✅';
          this.log('dev/test 验证通过 ✅ (test=15/15, e2e=5/5, perf=120ms)', 'text-emerald-400');
          // Wait for user approval
          task.blocked = true; task.blockReason = '等待批准 staging 部署';
          this.interactionPanel = 'decision';
          this.decisionCtx = {
            title: 'dev/test 验证通过', desc: '测试 15/15 | E2E 5/5 | 性能 120ms',
            options: [
              { label: '✅ 批准 staging', desc: '部署到 staging 环境', action: 'approve_staging' },
              { label: '❌ 放弃部署', desc: '取消', action: 'abort_deploy' },
            ]
          };
        }, 1500);
      }, 2000);
    },

    deployToEnv(env) {
      const task = this.tasks.find(t => t.id === this.deployState.taskId);
      if (!task) return;
      task.blocked = false; task.blockReason = '';
      this.deployState.env = env;
      this.addTrace('DevOps', `deploy_to_${env}`, task.id);

      if (env === 'staging') {
        this.log('② 部署到 <span class="text-blue-400">staging</span>...', 'text-orange-400');
        setTimeout(() => {
          task.deployInfo += '\nstaging: 部署成功';
          this.log('staging 部署成功', 'text-emerald-400');
          this.log('验证门控: test_suite + E2E (跳过性能)...', 'text-orange-400');
          // Feature 3: 25% chance of staging verification failure
          const stagingPassed = Math.random() > 0.25;
          if (stagingPassed) {
            setTimeout(() => {
              task.deployInfo += '\nstaging 验证: test=15/15, e2e=5/5 ✅';
              this.log('staging 验证通过 ✅ (test=15/15, e2e=5/5)', 'text-emerald-400');
              this.addTrace('DevOps', 'staging_verify_pass');
              // UAT
              task.blocked = true; task.blockReason = '等待 UAT 验收';
              this.interactionPanel = 'decision';
              this.decisionCtx = {
                title: 'UAT 验收 — staging 环境', desc: '请在 staging 上验收',
                options: [
                  { label: '✅ 验收通过', desc: '部署到 production', action: 'uat_pass' },
                  { label: '🐛 发现问题', desc: '创建修复任务', action: 'uat_fail' },
                ]
              };
            }, 1500);
          } else {
            // Feature 3: Staging verification failed → auto rollback
            setTimeout(() => {
              task.deployInfo += '\n❌ staging 验证失败: test=13/15, e2e=3/5';
              task.rollbackCount++;
              this.log('staging 验证 <span class="text-red-400">失败</span>: test=13/15, e2e=3/5', 'text-red-400');
              this.addTrace('DevOps', 'staging_verify_fail', 'test=13/15, e2e=3/5', 'error');
              this.log('自动回滚 staging 环境...', 'text-amber-400');
              task.deployInfo += '\nstaging: 已回滚到上一版本';
              task.blocked = true; task.blockReason = 'staging 验证失败, 已回滚';
              this.interactionPanel = 'decision';
              this.decisionCtx = {
                title: 'staging 验证失败 — 已自动回滚',
                desc: 'test=13/15, e2e=3/5, 已回滚到上一版本',
                options: [
                  { label: '🔄 修复重试', desc: '修复后重新部署到 staging', action: 'retry_deploy' },
                  { label: '❌ 放弃部署', desc: '取消部署', action: 'abort_deploy' },
                ]
              };
            }, 1500);
          }
        }, 2000);
      } else if (env === 'production') {
        this.log('③ 部署到 <span class="text-red-400">production</span>...', 'text-orange-400');
        setTimeout(() => {
          task.deployInfo += '\nproduction: 部署成功';
          this.log('production 部署成功', 'text-emerald-400');
          this.log('冒烟测试: 服务启动 + 端点可达...', 'text-orange-400');
          setTimeout(() => {
            task.deployInfo += '\n冒烟测试: 4/4 端点可达 ✅';
            this.log('冒烟测试通过 ✅ (4/4 端点可达)', 'text-emerald-400');
            // Git tag
            task.deployInfo += '\ngit tag: v1.2.3';
            this.log('自动打 git tag: <span class="text-purple-400">v1.2.3</span>', 'text-orange-400');
            task.column = 'deployed';
            task.blocked = false;
            this.showDeployReport(task);
            this.notifyChannels('部署完成', 'v1.2.3 已上线 production');
            this.setRole('DevOps', false, '待命');
            this.log('🎉 <span class="text-emerald-400">三层部署完成! v1.2.3 已上线</span>', 'text-emerald-400');
            // Self-evolution
            this.log('自我进化: memory add "JWT token 过期时间应可配置"', 'text-purple-400');
            this.log('自我进化: skill_manage create "jwt-auth-checklist"', 'text-purple-400');
            this.checkAllDone();
          }, 1500);
        }, 2000);
      }
    },

    checkAllDone() {
      // Feature 4: If there are blocked deploy tasks with active fix tasks, keep going
      const blockedDeploy = this.tasks.find(t => t.column === 'blocked' && t.assignee === 'DevOps');
      const activeFixTask = this.tasks.find(t => t.column === 'running' && t.assignee === 'Implementer' && t.title.includes('修复'));
      const readyFixTask = this.tasks.find(t => t.column === 'ready' && t.assignee === 'Implementer' && t.title.includes('修复'));
      if (blockedDeploy && (activeFixTask || readyFixTask)) {
        this.simBusy = false;
        if (readyFixTask) setTimeout(() => this.runNext(), 500);
        return;
      }

      const allDone = this.tasks.filter(t => t.isSubtask || t.column !== 'triage').every(t => ['done','deployed'].includes(t.column));
      if (allDone) {
        this.phase = 'idle';
        this.simBusy = false;
        this.setRole('Orchestrator', false, '待命');
        this.addTrace('System', 'all_done');
        // Feature 17: Completion notification panel
        const changedFiles = 'src/auth/jwt.rs, src/auth/routes.rs, src/middleware/auth.rs';
        const testResult = '单元: 14/14, E2E: 5/5, 回归: 15/15';
        const reviewResult = '1 高危问题已修复';
        const deployVersion = 'v1.2.3 production';
        this.archiveCtx = {
          summary: `<div class="space-y-1 text-xs">
            <div>📄 变更文件: ${changedFiles}</div>
            <div>🧪 测试: ${testResult}</div>
            <div>👀 审查: ${reviewResult}</div>
            <div>🚀 部署: ${deployVersion}</div>
            <div>📚 经验: 2 memory + 1 skill</div>
          </div>`,
          options: [
            { label: '✅ 批准归档', desc: '归档并完成', action: 'approve_archive' },
            { label: '➕ 追加需求', desc: '继续迭代', action: 'add_requirement' },
          ]
        };
        this.interactionPanel = 'archive';
        this.log('━━━ <span class="text-purple-400">全流程完成</span> ━━━', 'text-emerald-400');
        this.log('代码: src/auth/jwt.rs, src/auth/routes.rs | 测试: 14/14 | 审查: 1问题已修复', 'text-gray-400');
        this.log('部署: v1.2.3 production | 经验: 2 memory + 1 skill', 'text-gray-400');
      } else {
        this.simBusy = false;
        setTimeout(() => this.runNext(), 500);
      }
    },

    // ==================== AUTO PLAY ====================
    autoAdvance() {
      if (this.autoPlaying) { this.autoPlaying = false; clearTimeout(this.autoTimer); return; }
      this.autoPlaying = true;
      const tick = () => {
        if (!this.autoPlaying) return;
        if (this.interactionPanel === 'question' && QUESTIONS[this.qState.idx]) {
          this.answerQuestion(QUESTIONS[this.qState.idx].opts.find(o => o.rec) || QUESTIONS[this.qState.idx].opts[0]);
        } else if (this.interactionPanel === 'decision' && this.decisionCtx.options.length) {
          this.makeDecision(this.decisionCtx.options[0].action);
        } else if (this.interactionPanel === 'tdd') {
          this.tddStep();
        } else if (this.interactionPanel === 'feedback') {
          this.submitFeedback(5);
        } else if (this.interactionPanel === 'archive' && this.archiveCtx.options.length) {
          this.makeDecision(this.archiveCtx.options[0].action);
        } else if (this.interactionPanel === 'taskgraph' && this.taskGraphOptions.length) {
          this.confirmTaskGraph(this.taskGraphOptions[0].action);
        } else if (this.interactionPanel === 'poc_fail' && this.pocFailOptions.length) {
          this.handlePOCDecision(this.pocFailOptions[0].action);
        }
        this.autoTimer = setTimeout(tick, parseInt(this.autoSpeed));
      };
      tick();
    },

    // ==================== MULTI-PROJECT BOARDS ====================
    switchBoard() {
      this.selTask = null; this.activeTaskId = null;
      this.interactionPanel = null;
      this.log(`切换到 Board: ${this.currentBoard}`, 'text-purple-400');
      this.calcBP();
    },
    addBoard() {
      const id = `project-${String.fromCharCode(97 + this.boards.length)}`;
      const names = ['Beta', 'Gamma', 'Delta', 'Epsilon', 'Zeta'];
      const name = `🏢 Project ${names[this.boards.length - 1] || id}`;
      this.boards.push({ id, name });
      this.currentBoard = id;
      this.log(`创建新 Board: ${name}`, 'text-purple-400');
    },

    // ==================== RISK POLICY ENGINE ====================
    checkRiskPolicy(command) {
      for (const p of this.riskPolicies) {
        if (command.includes(p.pattern)) return p;
      }
      return null;
    },
    simulateRiskPolicy(task) {
      const cmd = 'git push --force';
      const policy = this.checkRiskPolicy(cmd);
      if (!policy) return;
      this.log(`<span class="text-red-400">Risk Policy 拦截!</span> 命令: "${cmd}" → 匹配规则: ${policy.pattern}`, 'text-amber-400');
      this.log(`  级别: <span class="${policy.level==='L3'?'text-red-400':policy.level==='L2'?'text-amber-400':'text-emerald-400'}">${policy.level}</span> | 审批者: ${policy.approver} | 超时: ${policy.timeout}s`, 'text-gray-400');

      if (policy.level === 'L3') {
        task.blocked = true;
        task.blockReason = `L3 拦截: ${policy.desc} (${cmd})`;
        task.column = 'blocked';
        this.addTrace('RiskPolicy', 'L3_block', cmd, 'error');
        this.addAuditEvent('L3拦截', `命令 "${cmd}" 匹配规则 "${policy.pattern}" — ${policy.desc}`, 'error');
        this.notifyChannels('L3 风险拦截', `命令 "${cmd}" 需要人工审批`);
        this.interactionPanel = 'decision';
        this.decisionCtx = {
          title: `⚠ L3 风险拦截: ${policy.desc}`,
          desc: `命令 "${cmd}" 匹配 Risk Policy 规则 "${policy.pattern}"\n级别: L3 | 永不自动通过`,
          options: [
            { label: '✅ 批准执行', desc: '允许执行此危险命令', action: 'risk_approve' },
            { label: '❌ 拒绝', desc: '阻止执行, 任务保持 blocked', action: 'risk_reject' },
          ]
        };
      } else if (policy.level === 'L2') {
        // Feature 11: L2 routes to Reviewer — create actual Reviewer subtask
        this.log(`L2: 转 Reviewer 决策...`, 'text-amber-400');
        this.addTrace('RiskPolicy', 'L2_route_reviewer', cmd, 'warn');
        const revTask = this.mkTask(`L2 审查: ${policy.desc}`, 'Reviewer', `审查风险命令: ${cmd}`, [], { priority: 'high' });
        revTask.column = 'ready';
        task.blocked = true;
        task.blockReason = `L2 拦截: 等待 Reviewer 审查 (${cmd})`;
        this.setRole('Reviewer', true, 'L2 审查', revTask.id);
        this.promoteReady();
        setTimeout(() => {
          // Reviewer approves L2
          this.log(`Reviewer L2 审查完成: <span class="text-emerald-400">批准</span> ${cmd}`, 'text-amber-400');
          this.addTrace('Reviewer', 'L2_approve', cmd);
          revTask.handoff = `l2_review: approved\ncommand: ${cmd}`;
          revTask.column = 'done';
          task.blocked = false;
          task.blockReason = '';
          this.setRole('Reviewer', false, '待命');
          this.promoteReady();
          this.simBusy = false;
        }, 2000);
      } else {
        // Feature 12: L1 Worker self-execute — no blocking
        this.log(`L1: <span class="text-emerald-400">Worker 自行决策 → 直接执行</span>`, 'text-emerald-400');
        this.addTrace('RiskPolicy', 'L1_self_execute', cmd);
        this.simBusy = false;
      }
    },

    // ==================== WORKER CRASH ROLLBACK ====================
    simulateCrash(task) {
      this.log(`💥 <span class="text-red-400">Worker 崩溃!</span> PID 消失, 任务 ${task.id}`, 'text-red-400');
      this.log(`  ① 检测: PID 不存在`, 'text-gray-400');
      this.log(`  ② git stash pop --index → 恢复干净 workspace`, 'text-gray-400');
      task.rollbackCount++;
      task.column = 'ready';
      task.blocked = false;
      task.blockReason = '';
      task.description += `<br><span class="text-red-400">⚠ Worker 崩溃回滚 (rollback #${task.rollbackCount})</span>`;
      this.setRole(task.assignee, false, '崩溃');
      this.log(`  ③ 任务 → ready, rollback_count=${task.rollbackCount}`, 'text-amber-400');
      this.log(`  ④ 重新派发新 Worker...`, 'text-gray-400');
      this.calcBP();
      // Auto re-dispatch after a delay
      setTimeout(() => {
        this.log(`Dispatcher 重新派发 ${task.id} (新 Worker)`, 'text-purple-400');
        this.runNext();
      }, 1500);
    },

    // ==================== DEPLOYMENT CRASH + SRE-OBSERVER ====================
    simulateDeployCrash(task) {
      this.log(`💥 <span class="text-red-400">部署失败!</span> deploy.sh exited 1`, 'text-red-400');
      this.log(`  stderr: "DATABASE_URL: parameter not set"`, 'text-gray-400');
      task.column = 'done';
      task.description += `<br><span class="text-red-400">部署失败: DATABASE_URL 未设置</span>`;
      task.deployInfo += '\n❌ deploy.sh exited 1: DATABASE_URL not set';
      this.setRole('DevOps', false, '失败');

      // Hermes auto-recovery
      this.log('Hermes 官方自动回收: 任务 → ready', 'text-gray-400');
      task.column = 'ready';
      task.rollbackCount++;

      // Notify user + offer SRE
      this.notifyChannels('部署故障', 'deploy.sh exited 1 — DATABASE_URL not set');
      this.interactionPanel = 'decision';
      this.decisionCtx = {
        title: '部署故障通知',
        desc: 'T-deploy crashed, DevOps 修复失败。是否需要 SRE-Observer 深度分析?',
        options: [
          { label: '🔎 创建 SRE 分析任务', desc: 'SRE-Observer 进行 7 步根因分析', action: 'trigger_sre' },
          { label: '⏭ 暂不需要', desc: '跳过深度分析, 重新部署', action: 'skip_sre' },
        ]
      };
    },

    triggerSRE(faultTaskId) {
      this.log('人工升级触发 → 创建 <span class="text-red-400">SRE-Observer</span> 分析任务', 'text-gray-400');
      const sre = this.mkTask(`根因分析: ${faultTaskId} 部署失败`, 'SRE-Observer',
        '读取 trace.db + worker logs + task_events + env snapshot', [faultTaskId]);
      sre.column = 'ready';
      this.setRole('SRE-Observer', true, '根因分析', sre.id);
      this.promoteReady();

      // 7-step SRE analysis
      setTimeout(() => {
        this.log('SRE-Observer ① kanban_show() → 读取故障任务信息', 'text-red-400');
        setTimeout(() => {
          this.log('SRE-Observer ② 查询 trace.db → tool_call #3: deploy.sh exited 1', 'text-red-400');
          setTimeout(() => {
            this.log('SRE-Observer ③ 读取 worker logs → stderr: DATABASE_URL not set', 'text-red-400');
            setTimeout(() => {
              this.log('SRE-Observer ④ 读取 task_events → claim→crashed 时间线', 'text-red-400');
              setTimeout(() => {
                this.log('SRE-Observer ⑤ 读取 env snapshot → git status / df -h', 'text-red-400');
                setTimeout(() => {
                  this.log('SRE-Observer ⑥ 对比 parent handoff → 上游无缺陷', 'text-red-400');
                  setTimeout(() => {
                    this.log('SRE-Observer ⑦ 综合分析 → <span class="text-emerald-400">根因定位: 环境层</span>', 'text-red-400');
                    // Output structured report
                    sre.handoff = JSON.stringify({
                      fault_task_id: faultTaskId,
                      root_cause_category: 'environment',
                      confidence: 'high',
                      symptom: 'deploy.sh exited 1: DATABASE_URL not set',
                      root_cause: '生产环境缺少 DATABASE_URL 环境变量',
                      responsible_profile: 'devops-engineer',
                      upstream_fault: null,
                      recommended_action: '补全 DATABASE_URL 后重新部署',
                      trace_anchor: "tool_call_#3 terminal('deploy.sh') exited 1"
                    }, null, 2);
                    sre.column = 'done';
                    this.addSREReport({
                      faultTaskId,
                      rootCauseCategory: 'environment',
                      confidence: 'high',
                      symptom: 'deploy.sh exited 1: DATABASE_URL not set',
                      rootCause: '生产环境缺少 DATABASE_URL 环境变量',
                      recommendedAction: '补全 DATABASE_URL 后重新部署',
                    });
                    this.setRole('SRE-Observer', false, '待命');
                    this.log('根因报告已生成:', 'text-emerald-400');
                    this.log('  类别: <span class="text-amber-400">environment</span> | 置信度: <span class="text-emerald-400">high</span>', 'text-gray-400');
                    this.log('  建议: 补全 DATABASE_URL 后重新部署', 'text-gray-400');
                    this.selectTask(sre);
                    this.promoteReady();
                    this.simBusy = false;
                  }, 800);
                }, 800);
              }, 800);
            }, 800);
          }, 800);
        }, 800);
      }, 500);
    },

    // ==================== "OTHER" OPTION + CONVERGENCE ====================
    answerOther() {
      const text = this.otherInput.trim();
      if (!text) return;
      const q = QUESTIONS[this.qState.idx];
      this.qState.otherCount++;
      this.qState.answers.push({ dim: q.dim, answer: text, label: '其他' });
      this.log(`Q${this.qState.idx+1} ${q.dim}: <span class="text-amber-400">其他: ${text}</span>`, 'text-gray-400');
      this.otherInput = '';

      if (this.qState.otherCount >= 3) {
        // Force convergence: auto-select recommended
        this.log('已达收敛上限 (第3次选"其他"), <span class="text-blue-400">自动选择推荐项</span>', 'text-amber-400');
        const rec = q.opts.find(o => o.rec) || q.opts[0];
        this.qState.answers[this.qState.answers.length - 1] = { dim: q.dim, answer: rec.text, label: rec.label };
        this.qState.otherCount = 0; // reset for next question
      } else if (this.qState.otherCount === 2) {
        this.log('第2次选"其他", <span class="text-amber-400">系统合成摘要</span>: 请在下方确认或修改', 'text-gray-400');
      }

      this.qState.idx++;
      if (this.qState.idx >= QUESTIONS.length) {
        this.finishClarification();
      }
    },

    // ==================== TRACE LOGGING ====================
    addTrace(role, action, detail='', level='info') {
      const t = new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit',second:'2-digit'});
      this.traceLog.unshift({ t, role, action, detail, level });
      if (this.traceLog.length > 300) this.traceLog.pop();
    },

    // ==================== CHECKPOINT (Feature 5) ====================
    saveCheckpoint() {
      const root = this.tasks.find(t => t.id === this.currentRootId);
      if (!root) return;
      const data = JSON.stringify({ answers: this.qState.answers, idx: this.qState.idx, otherCount: this.qState.otherCount });
      root.description = root.description.replace(/\[checkpoint:.*?\]/, '') + `[checkpoint:${data}]`;
      this.hasCheckpoint = true;
      try { localStorage.setItem('hermes_checkpoint', data); } catch(e) {}
      this.addTrace('System', 'checkpoint_saved', `Q${this.qState.idx+1}`);
    },
    recoverFromCheckpoint() {
      let data = null;
      try { data = JSON.parse(localStorage.getItem('hermes_checkpoint')); } catch(e) {}
      if (!data) {
        const root = this.tasks.find(t => t.id === this.currentRootId);
        if (root) {
          const m = root.description.match(/\[checkpoint:(.*?)\]/);
          if (m) try { data = JSON.parse(m[1]); } catch(e) {}
        }
      }
      if (!data || !data.answers || !data.answers.length) { this.log('未找到可恢复的检查点', 'text-amber-400'); return; }
      this.qState = { idx: data.idx, answers: data.answers, otherCount: data.otherCount || 0 };
      this.phase = 'clarifying';
      this.simBusy = false;
      this.interactionPanel = 'question';
      this.log(`已恢复检查点: Q${this.qState.idx+1}, 已回答 ${this.qState.answers.length} 题`, 'text-emerald-400');
      this.addTrace('System', 'checkpoint_recovered', `Q${this.qState.idx+1}`);
      this.hasCheckpoint = false;
    },

    // ==================== QA-TESTER (Feature 2) ====================
    executeQA(task) {
      this.setRole('QA-Tester', true, '独立验收', task.id);
      this.log('QA-Tester 开始独立验收...', 'text-pink-400');
      this.addTrace('QA-Tester', 'qa_start', task.id);
      // Read T1 handoff
      const t1 = this.tasks.find(t => t.title.includes('实现') && t.assignee === 'Implementer');
      if (t1) {
        this.log(`QA-Tester 读取 ${t1.id} handoff: behaviors, regression`, 'text-pink-400');
        this.addTrace('QA-Tester', 'read_handoff', t1.id);
      }
      setTimeout(() => {
        // 80% pass, 20% find issues
        const passed = Math.random() > 0.2;
        if (passed) {
          task.handoff = 'qa_result: pass\nverified: true\nregression: 15/15';
          task.column = 'done';
          task.description += '<br><span class="text-emerald-400">QA 独立验收通过: verified=true</span>';
          this.setRole('QA-Tester', false, '待命');
          this.log('QA-Tester 验收通过: <span class="text-emerald-400">verified=true</span>', 'text-pink-400');
          this.addTrace('QA-Tester', 'qa_pass', 'verified=true');
        } else {
          task.blocked = true;
          task.blockReason = 'QA 发现 critical_bug';
          task.column = 'blocked';
          task.handoff = 'qa_result: blocked\nissue: critical_bug — 登录接口未处理并发请求';
          task.description += '<br><span class="text-red-400">QA 发现 critical_bug: 登录接口未处理并发请求</span>';
          this.setRole('QA-Tester', true, 'blocked', task.id);
          this.log('QA-Tester 发现 <span class="text-red-400">critical_bug</span>, kanban_block', 'text-pink-400');
          this.addTrace('QA-Tester', 'qa_block', 'critical_bug', 'error');
          this.log('推荐: 创建 SRE 分析任务排查并发问题', 'text-amber-400');
          // Create fix task
          const fix = this.mkTask('修复 QA 发现的并发问题', 'Implementer', '修复登录接口并发处理', []);
          fix.column = 'ready';
          this.promoteReady();
        }
        this.promoteReady();
        setTimeout(() => this.runNext(), 500);
      }, 2000);
    },

    // ==================== POC FAILURE (Feature 1) ====================
    handlePOCDecision(action) {
      this.interactionPanel = null;
      this.simBusy = false;
      if (action === 'poc_retry_research') {
        this.log('用户选择: <span class="text-cyan-400">换方案重新调研</span>', 'text-gray-400');
        this.addTrace('User', 'poc_fail_retry');
        this.startResearch();
      } else if (action === 'poc_escalate_user') {
        this.log('用户选择: <span class="text-amber-400">升级用户决策</span>', 'text-gray-400');
        this.addTrace('User', 'poc_fail_escalate');
        this.interactionPanel = 'decision';
        this.decisionCtx = {
          title: 'POC 失败 — 用户决策',
          desc: '请决定是否继续或放弃此需求',
          options: [
            { label: '✅ 继续 (换方案)', desc: '回到调研阶段', action: 'poc_needed' },
            { label: '❌ 放弃任务', desc: '标记为完成并记录原因', action: 'poc_give_up' },
          ]
        };
      } else if (action === 'poc_give_up') {
        const poc = this.tasks.find(t => t.title.includes('POC'));
        if (poc) { poc.column = 'done'; poc.description += '<br><span class="text-red-400">POC 失败后放弃: 用户决策终止</span>'; }
        this.log('用户放弃任务: POC 失败, 记录原因', 'text-red-400');
        this.addTrace('User', 'poc_give_up');
        this.checkAllDone();
      }
    },

    // ==================== QUALITY FEEDBACK (Feature 8) ====================
    submitFeedback(score) {
      this.log(`澄清质量反馈: <span class="text-emerald-400">${score}/5</span>`, 'text-purple-400');
      this.addTrace('User', 'quality_feedback', `score=${score}`);
      const root = this.tasks.find(t => t.id === this.currentRootId);
      if (root) root.description += `<br>澄清质量评分: ${score}/5`;
      // Show confirm decision
      this.interactionPanel = 'decision';
      this.decisionCtx = { title: `需求 v${this.reqVersion} 已生成`, desc: '请确认是否进入下一阶段', options: root ? root.blockOptions : [
        { label: '✅ 确认', desc: '进入技术研判', action: 'confirm_req' },
        { label: '📝 修改', desc: '重新澄清', action: 'revise_req' },
      ]};
    },

    // ==================== TASK GRAPH CONFIRM (Feature 10) ====================
    confirmTaskGraph(action) {
      this.interactionPanel = null;
      this.simBusy = false;
      if (action === 'confirm_graph') {
        this.log('用户 <span class="text-emerald-400">确认任务图</span>, 进入执行阶段', 'text-gray-400');
        this.addTrace('User', 'taskgraph_confirmed');
        this.phase = 'executing';
        this.promoteReady();
        setTimeout(() => this.runNext(), 800);
      } else if (action === 'revise_graph') {
        this.log('用户要求修改拆解, PM 重新分析...', 'text-amber-400');
        this.addTrace('User', 'taskgraph_revise');
        // Remove old subtasks and re-decompose
        this.tasks = this.tasks.filter(t => !t.isSubtask);
        this.startDecomposition();
      }
    },

    // ==================== CANCEL TASK ====================
    cancelTask(task) {
      if (!task || task.column !== 'running') return;
      this.log(`用户取消任务 ${task.id}: ${task.title}`, 'text-amber-400');
      this.addTrace('User', 'cancel_task', task.id);
      task.column = 'ready';
      task.blocked = false;
      task.blockReason = '';
      this.setRole(task.assignee, false, '待命');
      this.simBusy = false;
      this.promoteReady();
      setTimeout(() => this.runNext(), 500);
    },

    // ==================== TIMEOUT DETECTION ====================
    checkTimeouts() {
      const now = Date.now();
      this.boardTasks().filter(t => t.column === 'running').forEach(t => {
        if (!t.startedAt) t.startedAt = now;
        const elapsed = now - t.startedAt;
        const maxDuration = (t.assignee === 'Implementer' ? 60 : t.assignee === 'Reviewer' ? 10 : 30) * 60 * 1000;
        if (elapsed > maxDuration) {
          this.log(`⏰ 任务 ${t.id} 超时 (${Math.round(elapsed/60000)}min)，自动回退`, 'text-red-400');
          this.addTrace('Dispatcher', 'timeout', t.id, 'error');
          t.column = 'ready';
          t.blocked = false;
          t.blockReason = '';
          t.rollbackCount = (t.rollbackCount || 0) + 1;
          this.setRole(t.assignee, false, '待命');
        }
      });
    },

    // ==================== SRE REPORT HISTORY ====================
    addSREReport(report) {
      this.sreReports.push({ ...report, timestamp: Date.now() });
    },

    // ==================== DEPLOY STRUCTURED REPORT ====================
    showDeployReport(task) {
      this.deployReport = {
        version: 'v1.2.3',
        strategy: 'blue-green',
        environments: [
          { name: 'dev/test', status: 'passed', validation: 'test=15/15, e2e=5/5' },
          { name: 'staging', status: task.deployInfo.includes('staging 验证') ? 'passed' : 'failed', validation: 'test=15/15, e2e=5/5' },
          { name: 'production', status: 'passed', smoke: '4/4 endpoints' },
        ],
        gitTag: 'v1.2.3',
        duration: '4m 32s',
      };
    },

    // ==================== DEPENDENCY GRAPH ====================
    showDepGraph(task) {
      const buildChain = (t, depth = 0) => {
        const indent = '  '.repeat(depth);
        const arrow = depth > 0 ? '→ ' : '';
        let result = `${indent}${arrow}[${t.id}] ${t.title} (${t.column})\n`;
        const children = this.boardTasks().filter(c => c.parents && c.parents.includes(t.id));
        children.forEach(c => { result += buildChain(c, depth + 1); });
        return result;
      };
      return task ? buildChain(task) : '无依赖';
    },

    // ==================== AUDIT TIMELINE ====================
    addAuditEvent(type, detail, level = 'info') {
      this.auditEvents.push({ type, detail, level, timestamp: Date.now() });
    },

    // ==================== RISK POLICY EDIT ====================
    editPolicy(idx, field, value) {
      if (this.riskPolicies[idx]) {
        this.riskPolicies[idx][field] = value;
        this.log(`风险策略已更新: ${this.riskPolicies[idx].pattern} → ${field}=${value}`, 'text-amber-400');
      }
    },

    // ==================== MULTI-CHANNEL NOTIFICATION ====================
    notifyChannels(title, body) {
      const channels = ['CLI', 'Gateway(Telegram)', 'Dashboard'];
      channels.forEach(ch => {
        this.log(`📡 [${ch}] ${title}: ${body}`, 'text-cyan-400');
      });
    },

    // ==================== SESSION RESUME ====================
    resumeSession(taskId) {
      const task = this.boardTasks().find(t => t.id === taskId);
      if (task && task.column === 'blocked') {
        task.blocked = false;
        task.blockReason = '';
        task.column = 'running';
        this.log(`🔄 Session 恢复: 任务 ${taskId} 从阻塞中恢复`, 'text-emerald-400');
        this.addTrace('Dispatcher', 'session_resume', taskId);
        setTimeout(() => this.runNext(), 500);
      }
    },

    // ==================== SELF-EVOLUTION ====================
    memoryAdd(content) {
      this.log(`📝 Memory: ${content}`, 'text-purple-400');
      this.addTrace('System', 'memory_add', content);
    },
    skillCreate(name) {
      this.log(`🔧 Skill 创建: ${name}`, 'text-purple-400');
      this.addTrace('System', 'skill_create', name);
    },
    curatorReview() {
      this.log(`🔍 Curator 审查: 清理过时 skills, 合并重叠`, 'text-purple-400');
      this.addTrace('System', 'curator_review');
    },

    // ==================== TERMINAL PROXY (R8) ====================
    execTerm(cmd, role) {
      role = role || 'reviewer';
      const profile = this.toolsetsData[role];
      let result = 'ok', reason = null, output = '$ ' + cmd + '\n';
      const writeCmds = ['>', '>>', 'rm ', 'mv ', 'cp ', 'chmod ', 'chown ', 'mkdir ', 'touch ', 'DROP', 'git push', 'git reset'];
      const isWrite = writeCmds.some(w => cmd.includes(w));
      if (isWrite && role === 'reviewer') {
        result = 'blocked';
        reason = 'R8: Reviewer 只读 — 写操作被技术性拦截';
        output += 'ERROR: ' + reason;
      } else if (isWrite && profile && profile.disabled && profile.disabled.includes('file_write')) {
        result = 'blocked';
        reason = 'R8: toolset 已禁用 file_write';
        output += 'ERROR: ' + reason;
      } else {
        if (cmd.startsWith('cat ')) output += '// JWT token implementation\nuse jsonwebtoken::{encode, decode, Header, Validation};\n...';
        else if (cmd.startsWith('cargo test')) output += 'running 15 tests\ntest test_valid_login ... ok\n...\n15 passed';
        else if (cmd.startsWith('git ')) output += 'git output...';
        else output += 'command executed successfully';
      }
      this.termHistory.push({ cmd, role, result, reason, output, time: new Date().toISOString() });
      if (result === 'blocked') {
        this.log(`<span class="text-red-400">[R8]</span> 写操作拦截: ${cmd}`, 'text-amber-400');
        this.addTrace('R8', 'terminal_blocked', cmd, 'warn');
        this.addAuditEvent('TERMINAL_BLOCKED', `命令 "${cmd}" 被 R8 拦截 — ${reason}`, 'warn');
      }
      return { result, reason, output };
    },

    // ==================== TOOLSETS (R10) ====================
    updateToolset() {
      const data = this.toolsetsData[this.toolsetRole];
      if (data) {
        this.toolsetEnabled = data.enabled;
        this.toolsetDisabled = data.disabled;
      }
    },

    // ==================== RESET ====================
    resetAll() {
      this.autoPlaying = false; clearTimeout(this.autoTimer);
      Object.assign(this, {
        tasks: [], taskSeq: 0, logs: [], phase: 'idle', simBusy: false,
        interactionPanel: null, selTask: null, activeTaskId: null, currentRootId: '',
        qState: { idx: 0, answers: [], otherCount: 0 },
        tddState: { taskId: '', behaviors: [], behIdx: 0, phase: 'RED', status: '' },
        deployState: { env: 'dev', taskId: '' }, otherInput: '',
        traceLog: [], bpHistory: [], reqVersion: 1, hasCheckpoint: false,
        deadlockCounter: 0, archiveCtx: { summary: '', options: [] },
        taskGraphDesc: '', taskGraphOptions: [], pocFailOptions: [],
        sreReports: [], deployReport: null, auditEvents: [],
        termHistory: [], termInput: '', toolsetRole: 'reviewer',
        _pendingReq: '',
      });
      this.roles.forEach(r => { r.active = false; r.status = '待命'; r.task = ''; });
      this.bp = { impl: 0, rev: 0, ratio: 0, action: '正常' };
      try { localStorage.removeItem('hermes_checkpoint'); } catch(e) {}
    },

    init() { this.log('Hermes 工作流模拟器就绪。输入需求开始模拟。', 'text-blue-400'); },
  };
}
