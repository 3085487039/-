// GitHub 全链路可达性检测
// 用法(在 quartz-site 目录里):  node check-network.js
// 作用:分别检测「网页/注册」「API」「git 推代码」「Pages 访问」四类域名,
//       把注册后可能再卡住的环节提前暴露出来。

const targets = [
  ['网页 + 注册', 'https://github.com/signup'],
  ['网页 + 注册', 'https://github.com'],
  ['API / 认证', 'https://api.github.com/zen'],
  ['git 推代码', 'https://github.com/jackyzha0/quartz.git/info/refs?service=git-upload-pack'],
  ['git 推代码(镜像源)', 'https://codeload.github.com/jackyzha0/quartz/zip/refs/heads/v5'],
  ['静态资源(头像等)', 'https://avatars.githubusercontent.com'],
  ['Pages 站点访问', 'https://pages.github.com'],
];

const verdict = (status) => {
  if (status === 'OK') return '✓ 通';
  if (status === 'BLOCKED') return '✗ 被拦(403,风控/区域)';
  if (status === 'DNS') return '✗ 域名解析失败(被污染)';
  if (status === 'TIMEOUT') return '✗ 超时(连不上)';
  if (status === 'TLS') return '✗ TLS 被重置';
  return '✗ 失败';
};

(async () => {
  let lastGroup = '';
  for (const [group, url] of targets) {
    if (group !== lastGroup) {
      console.log('\n【' + group + '】');
      lastGroup = group;
    }
    const t0 = Date.now();
    let mark = 'FAIL';
    let detail = '';
    try {
      const c = new AbortController();
      const id = setTimeout(() => c.abort(), 10000);
      const r = await fetch(url, { method: 'GET', redirect: 'manual', signal: c.signal });
      clearTimeout(id);
      if (r.status === 403 || r.status === 451) mark = 'BLOCKED';
      else mark = 'OK';
      detail = 'HTTP ' + r.status;
    } catch (e) {
      const code = e.cause ? e.cause.code || e.cause.message : e.message;
      if (e.name === 'AbortError') mark = 'TIMEOUT';
      else if (/ENOTFOUND|EAI_AGAIN/.test(code)) mark = 'DNS';
      else if (/ECONNRESET|EPROTO|CERT|SSL/.test(code)) mark = 'TLS';
      detail = code;
    }
    console.log(`  ${verdict(mark).padEnd(26)} ${String(Date.now() - t0).padStart(6)}ms  ${url}`);
    if (detail) console.log(`  ${''.padEnd(26)} ${detail}`);
  }

  console.log(`
怎么读这份结果:
  · 「网页 + 注册」403  -> 只是注册页的机器人风控,换手机热点 / VPN / 无痕窗口再试
  · 「git 推代码」超时或 TLS 被重置  -> 网页能开但推不了代码,需要给 git 配代理(见下)
  · 「Pages 站点访问」不通  -> 发出去的链接你自己可能打不开,但不影响别人访问

git 需要代理时(把端口换成你自己的代理端口,常见 7890 / 10809 / 1080):
  git config --global http.proxy  http://127.0.0.1:7890
  git config --global https.proxy http://127.0.0.1:7890
  取消:
  git config --global --unset http.proxy
  git config --global --unset https.proxy
`);
})();
