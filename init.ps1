param(
    [Parameter(Position = 0)]
    [string]$ProjectName,

    [Parameter(Position = 1)]
    [string]$OutputDir = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StarterRepoDefault = "https://github.com/atlas-form/atlas-fullstack-starter.git"
$StarterRefDefault = "main"
$BackendSourceDefault = "https://github.com/atlas-form/db-center-template.git"
$BackendRefDefault = "main"
$FrontendSourceDefault = "https://github.com/atlas-form/react-mono-template.git"
$FrontendRefDefault = "main"

function Show-Usage {
    @"
用法：
  .\init.ps1 <project-name> [output-dir]

示例：
  .\init.ps1 my-app
  .\init.ps1 my-app D:\workspace

可选环境变量：
  STARTER_REPO     脚手架仓库地址，用于拉取文档模板
  STARTER_REF      脚手架仓库分支
  BACKEND_SOURCE   后端模板来源，可以是 git 地址或本地目录
  BACKEND_REF      后端分支、标签或提交，仅对 git 地址有效
  FRONTEND_SOURCE  前端模板来源，可以是 git 地址或本地目录
  FRONTEND_REF     前端分支、标签或提交，仅对 git 地址有效
"@
}

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "错误：缺少命令 '$Name'"
    }
}

function Test-GitUrl {
    param([string]$Value)

    return $Value -match '^(http://|https://|git@|ssh://)'
}

function New-TempDirectory {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("atlas-fullstack-starter." + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $dir | Out-Null
    return $dir
}

function Copy-DirectoryContents {
    param(
        [string]$SourceDir,
        [string]$TargetDir,
        [string[]]$ExcludeNames = @()
    )

    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
        throw "错误：目录不存在：$SourceDir"
    }

    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

    Get-ChildItem -LiteralPath $SourceDir -Force | ForEach-Object {
        if ($ExcludeNames -contains $_.Name) {
            return
        }

        $destination = Join-Path $TargetDir $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
    }
}

function Copy-GitRepo {
    param(
        [string]$RepoUrl,
        [string]$RepoRef,
        [string]$TmpDir,
        [string]$TargetDir
    )

    git clone --depth 1 --branch $RepoRef $RepoUrl $TmpDir | Out-Null
    Copy-DirectoryContents -SourceDir $TmpDir -TargetDir $TargetDir -ExcludeNames @(".git")
}

function Generate-BackendWithCargoGenerate {
    param(
        [string]$Source,
        [string]$Ref,
        [string]$DestinationDir
    )

    Require-Command "cargo-generate"
    $parentDir = Split-Path -Parent $DestinationDir
    $backendName = Split-Path -Leaf $DestinationDir
    New-Item -ItemType Directory -Force -Path $parentDir | Out-Null

    if (Test-GitUrl $Source) {
        cargo generate --git $Source --branch $Ref --destination $parentDir --name $backendName --silent --vcs none
    } else {
        cargo generate --path $Source --destination $parentDir --name $backendName --silent --vcs none
    }
}

function Copy-FrontendTemplate {
    param(
        [string]$Source,
        [string]$Ref,
        [string]$TmpDir,
        [string]$TargetDir
    )

    Write-Host "==> 准备前端模板"
    Write-Host "    来源：$Source"

    if (Test-GitUrl $Source) {
        Write-Host "    版本：$Ref"
        Copy-GitRepo -RepoUrl $Source -RepoRef $Ref -TmpDir $TmpDir -TargetDir $TargetDir
    } else {
        Copy-DirectoryContents -SourceDir $Source -TargetDir $TargetDir -ExcludeNames @(".git", "node_modules", "target", "dist", ".turbo", "logs", "tmp", ".DS_Store")
    }
}

function Resolve-TemplateSource {
    param(
        [string]$StarterRepo,
        [string]$StarterRef,
        [string]$StarterTmpDir
    )

    $localTemplateDir = Join-Path $ScriptDir "project_template"
    $localReadmeTpl = Join-Path $localTemplateDir "ROOT_README.md.tpl"

    if ((Test-Path -LiteralPath $localTemplateDir -PathType Container) -and (Test-Path -LiteralPath $localReadmeTpl -PathType Leaf)) {
        return $localTemplateDir
    }

    git clone --depth 1 --branch $StarterRef $StarterRepo $StarterTmpDir | Out-Null
    return (Join-Path $StarterTmpDir "project_template")
}

function Copy-ProjectTemplate {
    param(
        [string]$TemplateSourceDir,
        [string]$ProjectDir
    )

    if (-not (Test-Path -LiteralPath $TemplateSourceDir -PathType Container)) {
        throw "错误：文档模板目录不存在：$TemplateSourceDir"
    }

    Copy-DirectoryContents -SourceDir $TemplateSourceDir -TargetDir $ProjectDir
}

function Merge-ApiDocs {
    param(
        [string]$ProjectDir,
        [string]$BackendDir
    )

    $backendApiDir = Join-Path $BackendDir "API_CONTRACTS"
    $rootApiDir = Join-Path $ProjectDir "API_DOCS"

    if (-not (Test-Path -LiteralPath $backendApiDir -PathType Container)) {
        return
    }

    New-Item -ItemType Directory -Force -Path $rootApiDir | Out-Null
    Copy-DirectoryContents -SourceDir $backendApiDir -TargetDir $rootApiDir
    Remove-Item -LiteralPath $backendApiDir -Recurse -Force

    Get-ChildItem -LiteralPath $BackendDir -Recurse -File -Filter "*.md" | ForEach-Object {
        $content = Get-Content -LiteralPath $_.FullName -Raw
        $content = $content.Replace("`API_CONTRACTS/", "`../API_DOCS/")
        $content = $content.Replace("API_CONTRACTS/", "../API_DOCS/")
        $content = $content.Replace("`API_CONTRACTS`", "`../API_DOCS`")
        $content = $content.Replace("API_CONTRACTS", "../API_DOCS")
        Set-Content -LiteralPath $_.FullName -Value $content -Encoding UTF8
    }

    Get-ChildItem -LiteralPath $rootApiDir -Recurse -File -Filter "*.md" | ForEach-Object {
        $content = Get-Content -LiteralPath $_.FullName -Raw
        $content = $content.Replace("`API_CONTRACTS/", "`API_DOCS/")
        $content = $content.Replace("API_CONTRACTS/", "API_DOCS/")
        $content = $content.Replace("`API_CONTRACTS`", "`API_DOCS`")
        $content = $content.Replace("API_CONTRACTS", "API_DOCS")
        Set-Content -LiteralPath $_.FullName -Value $content -Encoding UTF8
    }
}

function Render-RootReadme {
    param(
        [string]$ProjectDir,
        [string]$ProjectNameValue
    )

    $templatePath = Join-Path $ProjectDir "ROOT_README.md.tpl"
    $readmePath = Join-Path $ProjectDir "README.md"

    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        throw "错误：缺少 ROOT_README.md.tpl 模板"
    }

    (Get-Content -LiteralPath $templatePath -Raw).Replace("__PROJECT_NAME__", $ProjectNameValue) | Set-Content -LiteralPath $readmePath -Encoding UTF8
    Remove-Item -LiteralPath $templatePath -Force
}

function Write-RootGitignore {
    param([string]$ProjectDir)

    $content = @'
.DS_Store
.idea/
.vscode/
.claude/
.serena/

output/
temp/
'@

    Set-Content -LiteralPath (Join-Path $ProjectDir ".gitignore") -Value $content -Encoding UTF8
}

function Remove-GeneratedArtifacts {
    param([string]$ProjectDir)

    $targets = @(".git", "node_modules", "target", "logs", "dist", ".turbo", "tmp")
    foreach ($name in $targets) {
        Get-ChildItem -LiteralPath $ProjectDir -Force -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $name } |
            Sort-Object FullName -Descending |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    Get-ChildItem -LiteralPath $ProjectDir -Force -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq ".DS_Store" } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    Show-Usage
    exit 1
}

if ($ProjectName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    throw "错误：项目名 '$ProjectName' 非法。只允许字母、数字、点、下划线和中划线。"
}

Require-Command "git"

$StarterRepo = if ($env:STARTER_REPO) { $env:STARTER_REPO } else { $StarterRepoDefault }
$StarterRef = if ($env:STARTER_REF) { $env:STARTER_REF } else { $StarterRefDefault }
$BackendSource = if ($env:BACKEND_SOURCE) { $env:BACKEND_SOURCE } else { $BackendSourceDefault }
$BackendRef = if ($env:BACKEND_REF) { $env:BACKEND_REF } else { $BackendRefDefault }
$FrontendSource = if ($env:FRONTEND_SOURCE) { $env:FRONTEND_SOURCE } else { $FrontendSourceDefault }
$FrontendRef = if ($env:FRONTEND_REF) { $env:FRONTEND_REF } else { $FrontendRefDefault }

$TargetDir = Join-Path $OutputDir $ProjectName
$BackendDir = Join-Path $TargetDir "backend"
$FrontendDir = Join-Path $TargetDir "frontend"
$TmpDir = New-TempDirectory
$TmpFrontendDir = Join-Path $TmpDir "frontend"
$TmpStarterDir = Join-Path $TmpDir "starter"

try {
    if (Test-Path -LiteralPath $TargetDir) {
        throw "错误：目标目录已存在：$TargetDir"
    }

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

    Write-Host "==> 生成后端模板"
    Write-Host "    来源：$BackendSource"
    if (Test-GitUrl $BackendSource) {
        Write-Host "    版本：$BackendRef"
    }
    Generate-BackendWithCargoGenerate -Source $BackendSource -Ref $BackendRef -DestinationDir $BackendDir

    Copy-FrontendTemplate -Source $FrontendSource -Ref $FrontendRef -TmpDir $TmpFrontendDir -TargetDir $FrontendDir

    Write-Host "==> 拉取脚手架文档模板"
    $templateSourceDir = Resolve-TemplateSource -StarterRepo $StarterRepo -StarterRef $StarterRef -StarterTmpDir $TmpStarterDir
    Copy-ProjectTemplate -TemplateSourceDir $templateSourceDir -ProjectDir $TargetDir

    Write-Host "==> 统一 API 文档到根目录"
    Merge-ApiDocs -ProjectDir $TargetDir -BackendDir $BackendDir

    Write-Host "==> 渲染根目录 README 和 .gitignore"
    Render-RootReadme -ProjectDir $TargetDir -ProjectNameValue $ProjectName
    Write-RootGitignore -ProjectDir $TargetDir

    Write-Host "==> 清理模板残留文件"
    Remove-GeneratedArtifacts -ProjectDir $TargetDir

    Write-Host "==> 初始化新的 git 仓库"
    try {
        git -C $TargetDir init -b main | Out-Null
    } catch {
        git -C $TargetDir init | Out-Null
        try {
            git -C $TargetDir branch -M main | Out-Null
        } catch {
        }
    }

    Write-Host ""
    Write-Host "初始化完成：$TargetDir"
    Write-Host "当前项目已经是一个全新的 git 仓库"
    Write-Host "模板仓库原本的 .git 目录不会保留到用户项目中"
    Write-Host ""
    Write-Host "目录结构："
    Write-Host "  $TargetDir/"
    Write-Host "  ├── temp/"
    Write-Host "  ├── API_DOCS/"
    Write-Host "  ├── frontend/"
    Write-Host "  ├── backend/"
    Write-Host "  ├── AGENTS.md"
    Write-Host "  ├── README.md"
    Write-Host "  ├── manage.sh"
    Write-Host "  ├── AI_PROTOCOLS/"
    Write-Host "  └── .gitignore"
}
finally {
    if (Test-Path -LiteralPath $TmpDir) {
        Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
