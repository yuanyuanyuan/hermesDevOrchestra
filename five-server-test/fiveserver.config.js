// Five Server 配置文件
// 解决频繁自动刷新的问题

module.exports = {
  // === 基础服务配置 ===
  host: '0.0.0.0',
  port: 5500,
  open: true,

  // === 关键：防抖与忽略（解决频繁刷新）===
  // 文件变化后等待 1000ms 再刷新，期间有新变化会重新计时
  wait: 1000,

  // 忽略这些文件/目录的变化，防止后台文件触发的误刷新
  ignore: [
    '**/*.log',
    '**/node_modules/**',
    '**/.git/**',
    '**/dist/**',
    '**/build/**',
    '**/.vscode/**',
    '**/.tmp*/**',
    '**/*.tmp',
    '**/*.map',
    "**/tests/**",
  ],

  // 只监控特定目录（可选，比 ignore 更严格）
  // watch: ['src', 'public', '*.html'],

  // === 实时更新控制 ===
  // injectBody: true 会在你打字时实时更新页面（很灵敏，但容易频繁刷新）
  // 设为 false 则只在保存文件后刷新，更稳定
  injectBody: false,

  // CSS 变化时是否直接注入（不整页刷新）
  injectCss: true,

  // === 扩展功能 ===
  // 高亮当前编辑的标签（按需开启）
  highlight: false,

  // 自动导航到当前编辑的文件（按需开启）
  navigate: false,

  // 在终端显示浏览器 console.log
  remoteLogs: true,

  // === 调试（有问题时可打开看日志）===
  // logLevel: 2,  // 0=仅错误, 1=部分, 2=详细, 3=全部
}
