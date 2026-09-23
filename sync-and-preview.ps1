# 把 D:\蓝色大肥鱼\学习\ 的笔记同步进 quartz-site\content\,然后本地预览或构建。
# 用法(在 quartz-site 目录里打开 PowerShell):
#   .\sync-and-preview.ps1            # 同步 + 构建 + 起本地服务器 http://localhost:8081
#   .\sync-and-preview.ps1 -BuildOnly # 只同步 + 构建,产出 public\,不起服务器
#   .\sync-and-preview.ps1 -Port 9000 # 换端口(8080 常被 Steam 等程序占用)
param(
    [switch]$BuildOnly,
    [int]$Port = 8081
)

$ErrorActionPreference = 'Stop'

$siteRoot = $PSScriptRoot
$source = Join-Path (Split-Path $siteRoot -Parent) '学习'   # Obsidian 库根目录
$target = Join-Path $siteRoot 'content'

if (-not (Test-Path $source)) { throw "找不到笔记目录: $source" }

Write-Host "[1/3] 同步笔记: $source  ->  $target" -ForegroundColor Cyan
# /E  = 复制子目录(含空目录)
# /XD = 排除 Obsidian 配置目录 .obsidian
# /XF = 排除 Obsidian 自带的欢迎笔记;想公开它就删掉这一项
robocopy $source $target /E /XD .obsidian .trash .git /XF '欢迎.md' /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy 失败,exit=$LASTEXITCODE" }

# Quartz 的站点首页必须是 content\index.md。它不属于 Obsidian 库,
# 所以每次同步后从 site-index.md 复制过去,保证 homepage 不被覆盖。
Copy-Item (Join-Path $siteRoot 'site-index.md') (Join-Path $target 'index.md') -Force

Push-Location $siteRoot
$oldLogLevel = $env:npm_config_loglevel
$oldCache = $env:npm_config_cache
$env:npm_config_loglevel = 'error'                         # 别让 npm 的 verbose 日志刷屏
$env:npm_config_cache = Join-Path $siteRoot '.npm-cache'   # 缓存放站点目录内,不污染用户目录
# npx 会把日志写到 stderr,PowerShell 会把它当成异常,所以这里临时放宽
$ErrorActionPreference = 'Continue'
try {
    if ($BuildOnly) {
        Write-Host "[2/2] 构建静态站点到 public\" -ForegroundColor Cyan
        npx quartz build
    } else {
        Write-Host "[2/3] 构建并启动本地预览 http://localhost:$Port  (Ctrl+C 结束)" -ForegroundColor Cyan
        npx quartz build --serve --port $Port
    }
    $code = $LASTEXITCODE
} finally {
    $env:npm_config_loglevel = $oldLogLevel
    $env:npm_config_cache = $oldCache
    $ErrorActionPreference = 'Stop'
    Pop-Location
}
if ($code -ne 0) { throw "quartz 构建失败,exit=$code" }
Write-Host "完成。" -ForegroundColor Green
