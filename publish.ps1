# 一键发布:D:\蓝色大肥鱼\学习\ 的 Obsidian 笔记 -> https://3085487039.github.io/-
#
# 用法(在 quartz-site 目录打开 PowerShell):
#   .\publish.ps1                 # 同步 + 提交 + 推送,线上约 1-2 分钟后更新
#   .\publish.ps1 -Message "补充第7周笔记"
#   .\publish.ps1 -Preview        # 同步 + 起本地预览 http://localhost:8081,不推送
#   .\publish.ps1 -DryRun         # 只同步并显示将要提交的内容,什么都不提交
#
# 前提:GitHub 凭据已由 Git Credential Manager 保存过一次(推过一次就会记住)。

[CmdletBinding()]
param(
    [string]$Message,
    [switch]$Preview,
    [switch]$DryRun,
    [int]$Port = 8081
)

$ErrorActionPreference = 'Stop'

$siteRoot = $PSScriptRoot
$vault    = Join-Path (Split-Path $siteRoot -Parent) '学习'
$content  = Join-Path $siteRoot 'content'

if (-not (Test-Path $vault)) { throw "找不到 Obsidian 库: $vault" }
if (-not (Test-Path (Join-Path $siteRoot '.git'))) { throw "这不是 git 仓库: $siteRoot" }

# ---------- 0. 检查工作区是否干净,避免把无关改动一起提交 ----------
$dirty = git -C $siteRoot status --porcelain
if ($dirty) {
    Write-Host "注意:推送前仓库里已有未提交的改动,它们会一起被提交:" -ForegroundColor Yellow
    $dirty | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
}

# ---------- 1. 同步笔记 ----------
Write-Host "[1/4] 同步笔记 $vault -> $content" -ForegroundColor Cyan
# /E  复制子目录   /XD 排除 Obsidian 配置与回收站   /XF 排除 Obsidian 自带欢迎笔记
robocopy $vault $content /E /XD .obsidian .trash .git /XF '欢迎.md' /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy 失败,exit=$LASTEXITCODE" }

# 站点首页必须叫 index.md,它不属于 Obsidian 库,每次同步后从 site-index.md 还原
Copy-Item (Join-Path $siteRoot 'site-index.md') (Join-Path $content 'index.md') -Force

# ---------- 2. 清理会被发布成空白页的零字节笔记 ----------
$empties = Get-ChildItem $content -Recurse -File -Filter *.md |
           Where-Object { $_.Length -eq 0 -and $_.Name -ne 'index.md' }
foreach ($e in $empties) {
    Write-Host "  删除空笔记: $($e.FullName.Substring($content.Length + 1))" -ForegroundColor Yellow
    Remove-Item $e.FullName -Force
}

# ---------- 3. 本地构建校验 ----------
Write-Host "[2/4] 本地构建校验" -ForegroundColor Cyan
Push-Location $siteRoot
$oldLevel = $env:npm_config_loglevel
$oldCache = $env:npm_config_cache
$env:npm_config_loglevel = 'error'
$env:npm_config_cache = Join-Path $siteRoot '.npm-cache'
$ErrorActionPreference = 'Continue'   # npx 把日志写 stderr,别让 PowerShell 当异常
try {
    if ($Preview) {
        Write-Host "  起本地预览 http://localhost:$Port (Ctrl+C 结束)" -ForegroundColor Cyan
        npx quartz build --serve --port $Port
        exit $LASTEXITCODE
    }
    npx quartz build
    $code = $LASTEXITCODE
} finally {
    $env:npm_config_loglevel = $oldLevel
    $env:npm_config_cache = $oldCache
    $ErrorActionPreference = 'Stop'
    Pop-Location
}
if ($code -ne 0) { throw "Quartz 构建失败,exit=$code —— 已中止,没有推送" }

# ---------- 4. 提交并推送 ----------
if (-not $Message) { $Message = "notes: 更新于 $(Get-Date -Format 'yyyy-MM-dd HH:mm')" }

Write-Host "[3/4] 暂存改动" -ForegroundColor Cyan
git -C $siteRoot add -A
$staged = git -C $siteRoot diff --cached --name-only
if (-not $staged) {
    Write-Host "没有需要提交的改动,线上已是最新。" -ForegroundColor Green
    exit 0
}
$staged | ForEach-Object { Write-Host "  + $_" -ForegroundColor DarkGray }

if ($DryRun) {
    Write-Host "-DryRun:已同步并暂存,未提交也未推送。" -ForegroundColor Yellow
    exit 0
}

Write-Host "[4/4] 提交并推送 (分支 v5)" -ForegroundColor Cyan
git -C $siteRoot commit -m $Message --quiet
git -C $siteRoot push origin v5
if ($LASTEXITCODE -ne 0) { throw "推送失败,exit=$LASTEXITCODE" }

Write-Host ""
Write-Host "已推送。GitHub Actions 会自动构建部署,约 1-2 分钟后线上更新:" -ForegroundColor Green
Write-Host "  https://3085487039.github.io/-/" -ForegroundColor Green
Write-Host "查看构建进度: https://github.com/3085487039/-/actions" -ForegroundColor DarkGray
