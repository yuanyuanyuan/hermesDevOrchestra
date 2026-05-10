// Hermes Workflow Lab — Alpine.js Engine (existing features)
function masterEngine(config, phases) {
  return {
    // === Tab 0-3: Narrative Slide Deck ===
    activeTab: 0,
    title: config.title,
    subtitle: config.subtitle || '',
    tabs: config.tabs || ['演示'],
    panelLabels: config.panelLabels || ['上下文'],
    current: 0,
    isPlaying: false,
    speed: 800,
    timer: null,
    allSteps: config.steps || [],

    get tabSteps() { return this.allSteps.filter(s => s.tab === this.activeTab); },
    get maxStep() { return this.tabSteps.length - 1; },
    get step() { const s = this.tabSteps[Math.min(this.current, this.maxStep)]; return s || {}; },
    get progress() { const name = this.tabStepName; return name ? name + ' \u00b7 Step ' + this.current + ' / ' + this.maxStep : 'Step ' + this.current + ' / ' + this.maxStep; },
    get tabStepName() {
      const names = ['需求提交', '技术发现', '一次一问澄清', '可行性检查', 'Research 触发', 'POC 验证', '任务拆解', 'TDD 执行', '并行审查', '修复进化', '三层部署', '完成通知', 'L1 自行决定', 'L2 Reviewer', 'L3 硬拦截', 'Reviewer 纵深防御', '审计日志', '8 角色', 'Kanban 状态机', '背压机制', '自我进化', '可观测性', 'Profile Override', 'Memory 命名空间', 'Handoff Schema', 'Untrusted-Handoff', 'Block 触发条件', 'Worker 生命周期', 'SRE 报告 Schema', '路径 A/B 决策路由'];
      const globalIndex = this.allSteps.indexOf(this.step);
      return names[globalIndex] || '';
    },
    next() { if (this.current < this.maxStep) this.current++; },
    prev() { if (this.current > 0) this.current--; },
    reset() { this.current = 0; this.stop(); },
    play() {
      if (this.current >= this.maxStep) this.current = 0;
      this.isPlaying = true;
      const tick = () => {
        if (this.current < this.maxStep && this.isPlaying) { this.current++; this.timer = setTimeout(tick, 2200 - this.speed); }
        else { this.isPlaying = false; }
      };
      tick();
    },
    stop() { this.isPlaying = false; clearTimeout(this.timer); },
    togglePlay() { this.isPlaying ? this.stop() : this.play(); },
    state(name) {
      const keyMap = { '\u6d41\u7a0b\u89c6\u56fe': 'flow', '\u4e0a\u4e0b\u6587\u9762\u677f': 'context' };
      const key = keyMap[name] || name;
      return this.step?.[key] ?? '<span class="text-gray-600">\u2014</span>';
    },
    switchTab(i) { this.activeTab = i; this.current = 0; this.stop(); },

    // === Tab 4: Workflow Simulator ===
    columns: ['triage','todo','ready','running','blocked','done','archived'],
    tasks: [],
    logs: [],
    simPhase: 0,
    phases: phases,
    selectedTask: null,
    activeProject: 'project-alpha',
    projects: PROJECTS,
    riskPolicies: JSON.parse(JSON.stringify(RISK_POLICY_DEFAULT)),
    riskTestInput: '',
    riskTestResult: null,
    pendingDeploy: null,
    obsTraces: [],
    sreReports: [],
    memories: JSON.parse(JSON.stringify(MEMORY_DATA)),
    activeSimPanel: 'phase',
    selectedProfileForToolset: 'reviewer',
    currentToolset: TOOLSETS['reviewer'],
    newRiskPattern: '',
    newRiskLevel: 'L3',
    newRiskApprover: 'user',
    hasConflictWarning: true,

    // === NEW: Missing Core Features (placeholders for subagent expansion) ===
    // Notifications
    notifications: [],
    unreadNotifications: 0,
    showNotificationPanel: false,
    // Audit Log
    auditLogs: [],
    showAuditPanel: false,
    // Terminal Proxy
    terminalProxyHistory: [],
    terminalProxyInput: '',
    // Unblock
    unblockDecision: '',
    // Curator
    showCuratorPanel: false,
    curatorAction: 'review',
    // Clarification
    clarificationStep: 0,
    clarificationAnswers: {},
    showClarificationPanel: false,
    // Defer
    deferTasks: [],
    showDeferPanel: false,
    // Deploy Report
    showDeployReport: false,
    selectedDeployReport: null,
    // Dashboard
    showDashboard: false,
    dashboardView: 'trace',

    get maxPhase() { return this.phases.length - 1; },
    get currentPhase() { return this.phases[this.simPhase] || null; },
    get selectedTaskObj() { return this.tasks.find(t => t.id === this.selectedTask) || null; },

    tasksByStatus(status) { return this.tasks.filter(t => t.status === status); },
    selectTask(id) { this.selectedTask = this.selectedTask === id ? null : id; },

    roleColor(role) {
      const map = { pm: 'role-pm', orchestrator: 'role-orch', implementer: 'role-impl',
        reviewer: 'role-rev', 'qa-tester': 'role-qa', 'devops-engineer': 'role-devops',
        'sre-observer': 'role-sre', researcher: 'role-research' };
      return map[role] || 'text-gray-400';
    },
    colColor(col) {
      const map = { triage: 'text-gray-400', todo: 'text-gray-400', ready: 'text-emerald-400',
        running: 'text-blue-400', blocked: 'text-amber-400', done: 'text-emerald-400', archived: 'text-gray-500' };
      return map[col] || 'text-gray-400';
    },

    bpRatio() {
      const readyImpl = this.tasks.filter(t => t.status === 'ready' && t.assignee === 'implementer').length;
      const readyRev = this.tasks.filter(t => t.status === 'ready' && t.assignee === 'reviewer').length;
      return readyImpl / Math.max(readyRev, 1);
    },
    bpClass() {
      const r = this.bpRatio();
      if (r <= 2.0) return 'text-emerald-400';
      if (r <= 4.0) return 'text-amber-400';
      return 'text-red-400';
    },
    bpLabel() {
      const r = this.bpRatio();
      if (r <= 2.0) return '(正常)';
      if (r <= 4.0) return '(降速)';
      return '(暂停)';
    },
    readyCount() { return this.tasks.filter(t => t.status === 'ready').length; },
    runningCount() { return this.tasks.filter(t => t.status === 'running').length; },
    blockedCount() { return this.tasks.filter(t => t.status === 'blocked').length; },

    parentsDone(task) {
      if (!task.parents || task.parents.length === 0) return true;
      return task.parents.every(pid => {
        const p = this.tasks.find(x => x.id === pid);
        return p && (p.status === 'done' || p.status === 'archived' || p.status === 'blocked');
      });
    },
    autoPromote() {
      let promoted = [];
      this.tasks.forEach(t => {
        if (t.status === 'todo' && this.parentsDone(t)) {
          t.status = 'ready';
          promoted.push(t.id);
        }
      });
      return promoted;
    },

    log(msg) { this.logs.unshift(msg); if (this.logs.length > 30) this.logs.pop(); },

    simReset() {
      this.tasks = [];
      this.logs = [];
      this.simPhase = 0;
      this.selectedTask = null;
      this.pendingDeploy = null;
      this.obsTraces = [];
      this.sreReports = [];
      this.riskPolicies = JSON.parse(JSON.stringify(RISK_POLICY_DEFAULT));
      this.activeSimPanel = 'phase';
      this.notifications = [];
      this.unreadNotifications = 0;
      this.auditLogs = [];
      this.terminalProxyHistory = [];
      this.deferTasks = [];
      this.clarificationStep = 0;
      this.clarificationAnswers = {};
    },

    simPrev() {
      if (this.simPhase <= 0) return;
      this.simPhase--;
      this.simReset();
      for (let i = 0; i < this.simPhase; i++) { this._applyPhase(i); }
    },

    simNext() {
      if (this.simPhase >= this.maxPhase || this.pendingDeploy) return;
      this._applyPhase(this.simPhase);
      this.simPhase++;
    },

    switchProject(pid) {
      this.activeProject = pid;
      this.simReset();
      this.log('<span class="text-purple-400">[orchestrator]</span> \u5207\u6362\u5230 ' + pid);
    },

    updateToolsetView() {
      const profile = this.selectedProfileForToolset;
      this.currentToolset = TOOLSETS[profile] || { enabled: [], disabled: [] };
    },

    _actorColor(actor) {
      const map = { pm: 'role-pm', orchestrator: 'role-orch', implementer: 'role-impl',
        reviewer: 'role-rev', researcher: 'role-research', 'devops-engineer': 'role-devops',
        'qa-tester': 'role-qa', user: 'text-gray-300', system: 'text-gray-400' };
      return map[actor] || 'text-gray-400';
    },

    _recordTrace(taskId, tool, command, status, duration) {
      this.obsTraces.unshift({ id: 'trace-' + Date.now() + '-' + Math.random().toString(36).substr(2,5), taskId, tool, command, status, duration });
      const t = this.tasks.find(x => x.id === taskId);
      if (t) {
        if (!t.trace) t.trace = [];
        t.trace.push({ id: 't-' + t.trace.length, tool, command, status, duration });
      }
      if (this.obsTraces.length > 50) this.obsTraces.pop();
    },

    _genEnvSnapshot() {
      return {
        gitStatus: 'M src/auth/jwt.rs\nA tests/auth/test_jwt.py',
        diskFree: '/dev/sda1 45G 32G 13G 72%',
        hermesStatus: 'Hermes v0.13.0 \u2713 Kanban \u2713 Profile \u2713 Dispatcher'
      };
    },

    _pushNotification(type, title, message, actions) {
      const n = { id: 'n-' + Date.now(), type, title, message, actions: actions || [], time: new Date().toISOString(), read: false };
      this.notifications.unshift(n);
      if (!n.read) this.unreadNotifications++;
      if (this.notifications.length > 20) this.notifications.pop();
    },

    _recordAudit(event, details) {
      this.auditLogs.unshift({ id: 'a-' + Date.now(), event, details, time: new Date().toISOString() });
      if (this.auditLogs.length > 50) this.auditLogs.pop();
    },

    _applyPhase(idx) {
      const phase = this.phases[idx];
      if (!phase) return;
      const actor = phase.actor || 'system';
      const color = this._actorColor(actor);

      switch (phase.action) {
        case 'none':
          this.log('<span class="' + color + '">[' + actor + ']</span> ' + phase.desc);
          break;

        case 'create':
          if (phase.task) {
            const t = JSON.parse(JSON.stringify(phase.task));
            t.envSnapshot = this._genEnvSnapshot();
            this.tasks.push(t);
            this.log('<span class="' + color + '">[' + actor + ']</span> \u521b\u5efa <span class="text-blue-400">' + t.id + '</span> \u2192 ' + t.status);
          }
          break;

        case 'create_multi':
          if (phase.tasks) {
            phase.tasks.forEach(t => {
              const task = JSON.parse(JSON.stringify(t));
              task.envSnapshot = this._genEnvSnapshot();
              this.tasks.push(task);
              this.log('<span class="' + color + '">[' + actor + ']</span> \u521b\u5efa <span class="text-blue-400">' + task.id + '</span> \u2192 ' + task.status);
            });
          }
          break;

        case 'spawn': {
          const t = this.tasks.find(x => x.id === phase.taskId);
          if (t) {
            const old = t.status;
            t.status = 'running';
            t.startTime = Date.now();
            this.log('<span class="' + color + '">[' + actor + ']</span> <span class="text-blue-400">' + t.id + '</span> ' + old + ' \u2192 running');
          }
          break;
        }

        case 'complete': {
          const t = this.tasks.find(x => x.id === phase.taskId);
          if (t) {
            const old = t.status;
            t.status = 'done';
            if (phase.handoff) t.handoff = JSON.parse(JSON.stringify(phase.handoff));
            this._recordTrace(t.id, 'kanban_complete', 'kanban_complete(' + t.id + ')', 'ok', 120);
            this.log('<span class="' + color + '">[' + actor + ']</span> <span class="text-blue-400">' + t.id + '</span> ' + old + ' \u2192 done');
            const promoted = this.autoPromote();
            if (promoted.length) {
              this.log('<span class="text-purple-400">[orchestrator]</span> promote: ' + promoted.join(', ') + ' \u2192 ready');
            }
          }
          break;
        }

        case 'promote': {
          const t = this.tasks.find(x => x.id === phase.taskId);
          if (t && t.status === 'todo' && this.parentsDone(t)) {
            t.status = 'ready';
            this.log('<span class="' + color + '">[' + actor + ']</span> <span class="text-blue-400">' + t.id + '</span> todo \u2192 ready');
          }
          break;
        }

        case 'promote_multi': {
          const promoted = [];
          phase.taskIds.forEach(tid => {
            const t = this.tasks.find(x => x.id === tid);
            if (t && t.status === 'todo' && this.parentsDone(t)) {
              t.status = 'ready';
              promoted.push(t.id);
            }
          });
          if (promoted.length) {
            this.log('<span class="' + color + '">[' + actor + ']</span> promote: ' + promoted.join(', ') + ' \u2192 ready');
          }
          break;
        }

        case 'spawn_then_complete': {
          const t = this.tasks.find(x => x.id === phase.taskId);
          if (t) {
            t.status = 'running';
            t.startTime = Date.now();
            this.log('<span class="' + color + '">[' + actor + ']</span> <span class="text-blue-400">' + t.id + '</span> \u2192 running');
            this._recordTrace(t.id, 'terminal', 'cargo test --lib', 'ok', 3200);
            this._recordTrace(t.id, 'file_write', 'src/auth/jwt.rs', 'ok', 800);
            t.status = 'done';
            if (phase.handoff) t.handoff = JSON.parse(JSON.stringify(phase.handoff));
            this._recordTrace(t.id, 'kanban_complete', 'kanban_complete(' + t.id + ')', 'ok', 120);
            this.log('<span class="' + color + '">[' + actor + ']</span> <span class="text-blue-400">' + t.id + '</span> \u2192 done');
            const promoted = this.autoPromote();
            if (promoted.length) {
              this.log('<span class="text-purple-400">[orchestrator]</span> promote: ' + promoted.join(', ') + ' \u2192 ready');
            }
          }
          break;
        }

        case 'spawn_then_block': {
          const t = this.tasks.find(x => x.id === phase.taskId);
          if (t) {
            t.status = 'running';
            t.startTime = Date.now();
            this.log('<span class="' + color + '">[' + actor + ']</span> <span class="text-blue-400">' + t.id + '</span> \u2192 running');
            this._recordTrace(t.id, 'file_read', 'src/auth/jwt.rs', 'ok', 200);
            this._recordTrace(t.id, 'terminal', 'claude -p \u5ba1\u67e5 src/auth/', 'ok', 5000);
            t.status = 'blocked';
            if (phase.finding) {
              t.handoff = { findings: [JSON.parse(JSON.stringify(phase.finding))], behaviors: [], regression: { run: 0, passed: 0, failed: 0 }, changed_files: [], decisions: [], pitfalls: [] };
              t.blockReason = 'reviewer-rejected: ' + phase.finding.issue;
            }
            this.log('<span class="' + color + '">[' + actor + ']</span> <span class="text-blue-400">' + t.id + '</span> \u2192 blocked (' + (phase.finding?.issue || '') + ')');
            // Push QA critical bug notification
            this._pushNotification('qa-block', 'QA-Tester 发现 High 严重级问题', t.id + ': ' + (phase.finding?.issue || ''), [{ label: '创建 SRE 分析', action: 'sre' }]);
            this._recordAudit('QA_BLOCK', { taskId: t.id, severity: phase.finding?.severity, issue: phase.finding?.issue });
          }
          break;
        }

        case 'parallel': {
          phase.operations.forEach(op => {
            const t = this.tasks.find(x => x.id === op.taskId);
            if (!t) return;
            if (op.type === 'complete') {
              t.status = 'done';
              if (op.handoff) t.handoff = JSON.parse(JSON.stringify(op.handoff));
              this.log('<span class="' + color + '">[' + actor + ']</span> <span class="text-blue-400">' + t.id + '</span> \u2192 done');
            } else if (op.type === 'block') {
              t.status = 'blocked';
              if (op.finding) { t.blockReason = op.finding; }
              this.log('<span class="' + color + '">[' + actor + ']</span> <span class="text-blue-400">' + t.id + '</span> \u2192 blocked (' + (op.finding || '') + ')');
            }
          });
          const promoted = this.autoPromote();
          if (promoted.length) {
            this.log('<span class="text-purple-400">[orchestrator]</span> promote: ' + promoted.join(', ') + ' \u2192 ready');
          }
          break;
        }

        case 'deploy_start': {
          const t = this.tasks.find(x => x.id === phase.taskId);
          if (t) {
            t.status = 'running';
            t.startTime = Date.now();
            this.log('<span class="' + color + '">[' + actor + ']</span> <span class="text-blue-400">' + t.id + '</span> \u2192 running (deploy)');
            this.pendingDeploy = {
              taskId: t.id,
              config: JSON.parse(JSON.stringify(phase.deployConfig)),
              currentIdx: 0,
              currentStage: null,
              status: 'deploying',
              uatPassed: false
            };
            this._advanceDeployStage();
          }
          break;
        }

        case 'finish':
          this.log('<span class="text-emerald-400 font-bold">[' + actor + ']</span> ' + phase.desc);
          this._pushNotification('complete', 'Project Alpha 全部任务完成', '所有子任务已完成，代码可合并到 main', [{ label: '查看部署报告', action: 'deploy-report' }]);
          break;
      }
    },

    _advanceDeployStage() {
      if (!this.pendingDeploy) return;
      const pd = this.pendingDeploy;
      const stages = pd.config.stages;
      if (pd.currentIdx >= stages.length) {
        const t = this.tasks.find(x => x.id === pd.taskId);
        if (t) {
          t.status = 'done';
          t.handoff = {
            behaviors: [],
            regression: { run: 0, passed: 0, failed: 0 },
            changed_files: [],
            decisions: ['Deployed to all 3 environments'],
            pitfalls: [],
            deployReport: {
              version: 'v1.2.0',
              strategy: 'blue-green',
              environments: stages.map(s => ({ name: s.name, status: 'deployed', validation: s.validations.map(v => v.type + ':' + v.status).join(', '), smoke_test: s.name === 'production' ? 'passed' : 'N/A' })),
              git_tag: 'v1.2.0',
              rollback_available: true,
              duration: '12min'
            }
          };
          this.log('<span class="text-emerald-400">[devops-engineer]</span> <span class="text-blue-400">' + t.id + '</span> \u2192 done \u00b7 \u81ea\u52a8 git tag v1.2.0');
        }
        this.pendingDeploy = null;
        const promoted = this.autoPromote();
        if (promoted.length) {
          this.log('<span class="text-purple-400">[orchestrator]</span> promote: ' + promoted.join(', ') + ' \u2192 ready');
        }
        return;
      }
      pd.currentStage = stages[pd.currentIdx];
      const stage = pd.currentStage;
      this.log('<span class="text-orange-400">[devops-engineer]</span> \u90e8\u7f72\u5230 <span class="text-emerald-400">' + stage.name + '</span>');
      if (stage.auto) {
        this.log('<span class="text-emerald-400">[devops-engineer]</span> ' + stage.name + ' \u81ea\u52a8\u90e8\u7f72\u5b8c\u6210');
        stage.validations.forEach(v => {
          this.log('<span class="text-gray-400">[devops-engineer]</span>   \u9a8c\u8bc1 ' + v.type + ': <span class="text-emerald-400">' + v.status + '</span>');
        });
        pd.currentIdx++;
        this._advanceDeployStage();
      } else {
        this.log('<span class="text-amber-400">[devops-engineer]</span> ' + stage.name + ' \u7b49\u5f85\u7528\u6237\u6279\u51c6...');
        this._pushNotification('deploy-approval', '部署需要批准', '请将 ' + stage.name + ' 部署到生产环境', [{ label: '批准', action: 'approve' }, { label: '拒绝', action: 'reject' }]);
        this.activeSimPanel = 'deploy';
      }
    },

    approveDeployStage() {
      if (!this.pendingDeploy) return;
      const pd = this.pendingDeploy;
      const stage = pd.currentStage;
      this.log('<span class="text-emerald-400">[user]</span> \u6279\u51c6\u90e8\u7f72\u5230 ' + stage.name);
      stage.validations.forEach(v => {
        this.log('<span class="text-gray-400">[devops-engineer]</span>   \u9a8c\u8bc1 ' + v.type + ': <span class="text-emerald-400">' + v.status + '</span>');
      });
      if (stage.needsUAT && !pd.uatPassed) {
        this.log('<span class="text-purple-400">[devops-engineer]</span> ' + stage.name + ' UAT \u9a8c\u6536\u4e2d...');
        return;
      }
      pd.currentIdx++;
      this._advanceDeployStage();
    },

    rejectDeployStage() {
      if (!this.pendingDeploy) return;
      const pd = this.pendingDeploy;
      const t = this.tasks.find(x => x.id === pd.taskId);
      if (t) {
        t.status = 'blocked';
        t.blockReason = 'deploy-rejected: ' + pd.currentStage.name;
        this.log('<span class="text-red-400">[user]</span> \u62d2\u7edd\u90e8\u7f72\u5230 ' + pd.currentStage.name + ' \u2192 \u56de\u6eda');
        this.log('<span class="text-red-400">[devops-engineer]</span> \u81ea\u52a8\u56de\u6eda ' + pd.currentStage.name + ' \u73af\u5883');
        this._pushNotification('deploy-failure', '部署被拒绝', t.id + ' 在 ' + pd.currentStage.name + ' 被拒绝，已回滚', [{ label: '创建 SRE', action: 'sre' }]);
        this._recordAudit('DEPLOY_REJECT', { taskId: t.id, stage: pd.currentStage.name });
      }
      this.pendingDeploy = null;
    },

    passUAT() {
      if (!this.pendingDeploy) return;
      this.pendingDeploy.uatPassed = true;
      this.log('<span class="text-purple-400">[user]</span> UAT \u9a8c\u6536\u901a\u8fc7');
      this.approveDeployStage();
    },

    failUAT() {
      if (!this.pendingDeploy) return;
      const pd = this.pendingDeploy;
      const t = this.tasks.find(x => x.id === pd.taskId);
      if (t) {
        t.status = 'blocked';
        t.blockReason = 'uat-failed: ' + pd.currentStage.name;
        this.log('<span class="text-red-400">[user]</span> UAT \u9a8c\u6536\u5931\u8d25 \u2192 \u521b\u5efa\u4fee\u590d\u4efb\u52a1');
        this.tasks.push({
          id: 'T5-fix', title: 'UAT \u95ee\u9898\u4fee\u590d', assignee: 'implementer', status: 'todo',
          parents: [t.id], body: '\u6839\u636e UAT \u53cd\u9988\u4fee\u590d\u95ee\u9898', rollbackCount: 0, expectedDurationMax: 30
        });
        this._pushNotification('uat-failure', 'UAT 验收失败', t.id + ' UAT 未通过，已创建修复任务 T5-fix', [{ label: '查看任务', action: 'task' }]);
        this._recordAudit('UAT_FAIL', { taskId: t.id, stage: pd.currentStage.name });
      }
      this.pendingDeploy = null;
    },

    simulateCrash(taskId) {
      const t = this.tasks.find(x => x.id === taskId);
      if (!t || t.status !== 'running') return;
      t.status = 'ready';
      t.rollbackCount = (t.rollbackCount || 0) + 1;
      t.startTime = null;
      this.log('<span class="text-red-400">[system]</span> <span class="text-blue-400">' + t.id + '</span> PID \u4e0d\u5b58\u5728 \u2192 crashed');
      this.log('<span class="text-red-400">[system]</span> git stash pop --index \u6062\u590d worktree');
      this.log('<span class="text-red-400">[system]</span> <span class="text-blue-400">' + t.id + '</span> \u56de\u9000\u5230 ready (rollback_count=' + t.rollbackCount + ')');
      if (t.rollbackCount >= 2) {
        this.log('<span class="text-amber-400">[orchestrator]</span> \u8b66\u544a: ' + t.id + ' rollback_count \u2265 2 \uff0c\u5efa\u8bae\u521b\u5efa SRE \u5206\u6790\u4efb\u52a1');
        this._pushNotification('crash-alert', '任务多次崩溃', t.id + ' 已回滚 ' + t.rollbackCount + ' 次，建议创建 SRE 分析', [{ label: '创建 SRE', action: 'sre' }]);
        this._recordAudit('CRASH_ROLLBACK', { taskId: t.id, rollbackCount: t.rollbackCount });
      }
    },

    createSRE(taskId) {
      const t = this.tasks.find(x => x.id === taskId);
      if (!t) return;
      const sreId = 'SRE-' + Date.now().toString(36).substr(-4);
      this.tasks.push({
        id: sreId, title: '\u6839\u56e0\u5206\u6790: ' + t.id, assignee: 'sre-observer', status: 'running',
        parents: [t.id], body: '\u5bf9 ' + t.id + ' \u7684\u6545\u969c\u8fdb\u884c\u6839\u56e0\u5206\u6790', rollbackCount: 0, expectedDurationMax: 60
      });
      const report = {
        id: sreId + '-report',
        faultTaskId: t.id,
        root_cause_category: t.status === 'blocked' && t.blockReason?.includes('reviewer') ? 'review' : (t.assignee === 'devops-engineer' ? 'deployment' : 'code'),
        confidence: 'high',
        symptom: t.blockReason || 'task crashed after ' + (t.rollbackCount || 0) + ' rollbacks',
        root_cause: t.blockReason || 'unknown failure in worker process',
        responsible_profile: t.assignee,
        upstream_fault: t.parents.length > 0 ? t.parents[0] : null,
        recommended_action: 'Review ' + t.id + ' handoff metadata and re-run with extended timeout',
        trace_anchor: 'task_run_' + t.id + '_rollback_' + (t.rollbackCount || 0)
      };
      this.sreReports.unshift(report);
      const sreTask = this.tasks.find(x => x.id === sreId);
      if (sreTask) {
        sreTask.status = 'done';
        sreTask.handoff = { behaviors: [], regression: { run: 0, passed: 0, failed: 0 }, changed_files: [], decisions: [], pitfalls: [], sreReport: report };
      }
      this.log('<span class="text-red-400">[sre-observer]</span> \u521b\u5efa ' + sreId + ' \u2192 running');
      this.log('<span class="text-red-400">[sre-observer]</span> \u8bfb\u53d6 trace.db + worker logs + task_events + audit logs');
      this.log('<span class="text-red-400">[sre-observer]</span> ' + sreId + ' \u2192 done \u00b7 category=' + report.root_cause_category + ' confidence=' + report.confidence);
      this.activeSimPanel = 'sre';
    },

    testRiskPolicy() {
      const cmd = this.riskTestInput.trim();
      if (!cmd) { this.riskTestResult = null; return; }
      for (const rp of this.riskPolicies) {
        if (cmd.includes(rp.pattern) || (rp.pattern.endsWith(' ') && cmd.startsWith(rp.pattern))) {
          this.riskTestResult = { level: rp.level, approver: rp.approver, matchedPattern: rp.pattern, timeout: rp.timeout };
          this._recordAudit('RISK_TEST', { command: cmd, level: rp.level, pattern: rp.pattern });
          return;
        }
      }
      this.riskTestResult = { level: 'L1', approver: 'self', matchedPattern: '\u65e0\u5339\u914d\uff08\u9ed8\u8ba4 L1\uff09', timeout: 0 };
    },

    addRiskPolicy() {
      if (!this.newRiskPattern.trim()) return;
      this.riskPolicies.push({
        id: 'rp-' + Date.now(),
        pattern: this.newRiskPattern.trim(),
        level: this.newRiskLevel,
        approver: this.newRiskApprover,
        timeout: this.newRiskLevel === 'L3' ? 0 : 300,
        category: 'custom'
      });
      this.newRiskPattern = '';
      this.log('<span class="text-amber-400">[system]</span> \u6dfb\u52a0 Risk Policy: ' + this.riskPolicies[this.riskPolicies.length-1].pattern + ' \u2192 ' + this.newRiskLevel);
      this._recordAudit('RISK_POLICY_ADD', { pattern: this.riskPolicies[this.riskPolicies.length-1].pattern, level: this.newRiskLevel });
    },

    removeRiskPolicy(id) {
      const idx = this.riskPolicies.findIndex(rp => rp.id === id);
      if (idx >= 0) {
        this.log('<span class="text-amber-400">[system]</span> \u5220\u9664 Risk Policy: ' + this.riskPolicies[idx].pattern);
        this._recordAudit('RISK_POLICY_REMOVE', { pattern: this.riskPolicies[idx].pattern });
        this.riskPolicies.splice(idx, 1);
      }
    },

    // === NEW FEATURE METHODS (expanded by subagents or inline below) ===
    // These will be populated in hermes-workflow-features.js

    // Unblock a blocked task
    unblockTask(taskId, decision) {
      const t = this.tasks.find(x => x.id === taskId);
      if (!t || t.status !== 'blocked') return;
      t.status = 'ready';
      t.unblockDecision = decision || 'user-approved';
      t.unblockTime = new Date().toISOString();
      this.log('<span class="text-emerald-400">[user]</span> \u89e3\u9664\u963b\u585e <span class="text-blue-400">' + t.id + '</span> \u2192 ready');
      this.log('<span class="text-gray-400">[orchestrator]</span> \u51b3\u7b56: ' + (decision || 'user-approved'));
      this._recordAudit('TASK_UNBLOCK', { taskId: t.id, decision: decision || 'user-approved' });
      this._pushNotification('unblock', '任务已解除阻塞', t.id + ' 已被解除阻塞，决策: ' + (decision || 'user-approved'), []);
      const promoted = this.autoPromote();
      if (promoted.length) {
        this.log('<span class="text-purple-400">[orchestrator]</span> promote: ' + promoted.join(', ') + ' \u2192 ready');
      }
    },

    // Archive a done task
    archiveTask(taskId) {
      const t = this.tasks.find(x => x.id === taskId);
      if (!t || t.status !== 'done') return;
      t.status = 'archived';
      this.log('<span class="text-gray-400">[system]</span> <span class="text-blue-400">' + t.id + '</span> done \u2192 archived');
      this._recordAudit('TASK_ARCHIVE', { taskId: t.id });
    },

    // Mark notification as read
    readNotification(id) {
      const n = this.notifications.find(x => x.id === id);
      if (n && !n.read) { n.read = true; this.unreadNotifications = Math.max(0, this.unreadNotifications - 1); }
    },

    dismissNotification(id) {
      this.notifications = this.notifications.filter(x => x.id !== id);
    },

    // Execute terminal proxy command
    execTerminalProxy(cmd, role) {
      role = role || 'reviewer';
      const profile = TOOLSETS[role];
      let result = 'ok';
      let reason = null;
      let output = '$ ' + cmd + '\n';

      // Check if write operation
      const writeCmds = ['>', '>>', 'rm ', 'mv ', 'cp ', 'chmod ', 'chown ', 'mkdir ', 'touch '];
      const isWrite = writeCmds.some(w => cmd.includes(w));
      if (isWrite && profile && profile.disabled.includes('file_write')) {
        result = 'blocked';
        reason = 'R8: Reviewer toolset 已禁用 file_write';
        output += 'ERROR: ' + reason;
      } else if (isWrite && role === 'reviewer') {
        result = 'blocked';
        reason = 'R8: Read-Only Terminal Proxy 技术性拦截';
        output += 'ERROR: ' + reason;
      } else {
        // Simulate output
        if (cmd.startsWith('cat ')) output += '// file content...\n...';
        else if (cmd.startsWith('cargo test')) output += 'running 15 tests\nall passed';
        else if (cmd.startsWith('git ')) output += 'git output...';
        else output += 'command executed successfully';
      }

      this.terminalProxyHistory.push({ cmd, role, result, reason, output, time: new Date().toISOString() });
      if (result === 'blocked') {
        this._recordAudit('TERMINAL_BLOCKED', { command: cmd, role, reason });
      }
      return { result, reason, output };
    },

    // Curator operations
    pinMemory(ns, id) {
      const m = this.memories[ns]?.find(x => x.id === id);
      if (m) { m.pinned = true; this.log('<span class="text-purple-400">[curator]</span> pin ' + id); this._recordAudit('CURATOR_PIN', { ns, id }); }
    },
    unpinMemory(ns, id) {
      const m = this.memories[ns]?.find(x => x.id === id);
      if (m) { m.pinned = false; this.log('<span class="text-purple-400">[curator]</span> unpin ' + id); this._recordAudit('CURATOR_UNPIN', { ns, id }); }
    },
    deleteMemory(ns, id, scope) {
      const arr = this.memories[ns];
      if (!arr) return;
      const idx = arr.findIndex(x => x.id === id);
      if (idx >= 0) {
        const m = arr[idx];
        this.log('<span class="text-purple-400">[curator]</span> delete ' + id + ' (scope: ' + (scope || 'project') + ')');
        this._recordAudit('CURATOR_DELETE', { ns, id, scope: scope || 'project' });
        if (scope === 'global' && ns !== '_global') {
          // Also remove from global if exists
          const gIdx = this.memories['_global']?.findIndex(x => x.content === m.content);
          if (gIdx >= 0) this.memories['_global'].splice(gIdx, 1);
        }
        arr.splice(idx, 1);
      }
    },
    promoteToGlobal(id) {
      const pending = this.memories['_pending']?.find(x => x.id === id);
      if (pending) {
        pending.quality = Math.min(100, pending.quality + 10);
        this.memories['_global'].push({ ...pending, source: 'curator-approved' });
        this.memories['_pending'] = this.memories['_pending'].filter(x => x.id !== id);
        this.log('<span class="text-purple-400">[curator]</span> promote ' + id + ' \u2192 _global');
        this._recordAudit('CURATOR_PROMOTE', { id });
      }
    },
    runCuratorReview() {
      this.log('<span class="text-purple-400">[curator]</span> \u5f00\u59cb\u5b9a\u671f\u5ba1\u67e5...');
      let archived = 0, merged = 0;
      ['project-alpha', '_global'].forEach(ns => {
        const arr = this.memories[ns];
        if (!arr) return;
        for (let i = arr.length - 1; i >= 0; i--) {
          const m = arr[i];
          if (!m.pinned && m.quality < 40) {
            m.archived = true;
            archived++;
          }
        }
      });
      this.log('<span class="text-purple-400">[curator]</span> \u5ba1\u67e5\u5b8c\u6210: archive=' + archived + ', merge=' + merged);
      this._pushNotification('curator', 'Curator 审查完成', '归档 ' + archived + ' 条，合并 ' + merged + ' 条', []);
      this._recordAudit('CURATOR_REVIEW', { archived, merged });
    },

    // Clarification workflow
    startClarification() {
      this.clarificationStep = 0;
      this.clarificationAnswers = {};
      this.showClarificationPanel = true;
    },
    answerClarification(questionId, answer) {
      this.clarificationAnswers[questionId] = answer;
      if (this.clarificationStep < CLARIFICATION_QUESTIONS.length - 1) {
        this.clarificationStep++;
      } else {
        this.showClarificationPanel = false;
        this.log('<span class="text-emerald-400">[pm]</span> \u6f84\u6e05\u5b8c\u6210, \u5171 ' + Object.keys(this.clarificationAnswers).length + ' \u4e2a\u95ee\u9898\u5df2\u56de\u7b54');
        this._recordAudit('CLARIFICATION_COMPLETE', { answers: this.clarificationAnswers });
      }
    },

    // Defer simulation
    deferTask(taskId, question) {
      const t = this.tasks.find(x => x.id === taskId);
      if (!t) return;
      t.status = 'blocked';
      t.deferred = true;
      t.deferQuestion = question || '需要用户确认...';
      this.deferTasks.push({ taskId, question: t.deferQuestion, time: new Date().toISOString() });
      this.log('<span class="text-purple-400">[system]</span> ' + t.id + ' \u5df2 defer: ' + t.deferQuestion);
      this._pushNotification('defer', '任务需要用户确认', t.id + ': ' + t.deferQuestion, [{ label: '回答', action: 'defer' }]);
      this._recordAudit('TASK_DEFER', { taskId, question: t.deferQuestion });
    },
    resumeDeferred(taskId, answer) {
      const t = this.tasks.find(x => x.id === taskId);
      if (!t || !t.deferred) return;
      t.status = 'ready';
      t.deferred = false;
      t.deferAnswer = answer;
      this.deferTasks = this.deferTasks.filter(x => x.taskId !== taskId);
      this.log('<span class="text-emerald-400">[system]</span> ' + t.id + ' resume: ' + answer);
      this._recordAudit('TASK_RESUME', { taskId, answer });
      const promoted = this.autoPromote();
      if (promoted.length) {
        this.log('<span class="text-purple-400">[orchestrator]</span> promote: ' + promoted.join(', ') + ' \u2192 ready');
      }
    },

    // View deploy report
    viewDeployReport(taskId) {
      const t = this.tasks.find(x => x.id === taskId);
      if (!t || !t.handoff?.deployReport) return;
      this.selectedDeployReport = t.handoff.deployReport;
      this.showDeployReport = true;
    }
  };
}
