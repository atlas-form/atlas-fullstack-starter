param(
    [Parameter(Position = 0)]
    [string]$Area,

    [Parameter(Position = 1)]
    [string]$Target,

    [Parameter(Position = 2)]
    [string]$Action
)

$ErrorActionPreference = 'Stop'

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RunDir = Join-Path $RootDir 'temp/run'
$LogDir = Join-Path $RootDir 'temp/logs'

New-Item -ItemType Directory -Force -Path $RunDir, $LogDir | Out-Null

function Show-Usage {
@"
Usage:
  .\manage.ps1 init_env [frontend|backend]
  .\manage.ps1 backend start|stop|restart|status
  .\manage.ps1 frontend install
  .\manage.ps1 frontend <app> start|stop|restart|status

Examples:
  .\manage.ps1 init_env
  .\manage.ps1 init_env frontend
  .\manage.ps1 init_env backend
  .\manage.ps1 backend start
  .\manage.ps1 backend stop
  .\manage.ps1 frontend install
  .\manage.ps1 frontend admin start
  .\manage.ps1 frontend admin stop

Logs:
  temp/logs/backend.log
  temp/logs/backend.err.log
  temp/logs/frontend-<app>.log
  temp/logs/frontend-<app>.err.log
"@
}

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
}

function Resolve-CommandPath {
    param([string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Missing required command: $Name"
    }

    return $command.Source
}

function Invoke-NativeCommand {
    param(
        [scriptblock]$Command,
        [string]$ErrorMessage
    )

    $global:LASTEXITCODE = 0
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$ErrorMessage Exit code: $LASTEXITCODE"
    }
}

function Get-ErrLogPath {
    param([string]$LogFile)

    $directory = Split-Path -Parent $LogFile
    $leaf = Split-Path -Leaf $LogFile
    return (Join-Path $directory ($leaf -replace '\.log$', '.err.log'))
}

function Get-PidValue {
    param([string]$PidFile)

    if (-not (Test-Path -LiteralPath $PidFile -PathType Leaf)) {
        return $null
    }

    $value = (Get-Content -LiteralPath $PidFile -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return [int]$value
}

function Test-Running {
    param([string]$PidFile)

    $pidValue = Get-PidValue -PidFile $PidFile
    if ($null -eq $pidValue) {
        return $false
    }

    return $null -ne (Get-Process -Id $pidValue -ErrorAction SilentlyContinue)
}

function Clear-LogFile {
    param([string]$Path)

    New-Item -ItemType File -Force -Path $Path | Out-Null
    Clear-Content -LiteralPath $Path
}

function Start-ManagedProcess {
    param(
        [string]$Name,
        [string]$PidFile,
        [string]$LogFile,
        [string]$WorkingDirectory,
        [string]$FilePath,
        [string[]]$ArgumentList = @()
    )

    if (Test-Running -PidFile $PidFile) {
        Write-Host "$Name is already running, PID: $(Get-PidValue -PidFile $PidFile)"
        return
    }

    $errLogFile = Get-ErrLogPath -LogFile $LogFile

    Write-Host "==> Start $Name"
    Write-Host "    Log: $LogFile"
    Write-Host "    Error log: $errLogFile"

    Clear-LogFile -Path $LogFile
    Clear-LogFile -Path $errLogFile

    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -WorkingDirectory $WorkingDirectory `
        -RedirectStandardOutput $LogFile `
        -RedirectStandardError $errLogFile `
        -PassThru `
        -WindowStyle Hidden

    Set-Content -LiteralPath $PidFile -Value $process.Id -Encoding UTF8
}

function Get-LogTail {
    param(
        [string]$Path,
        [int]$Lines = 80
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Write-Host ''
        Write-Host "Recent log: $Path"
        Get-Content -LiteralPath $Path -Tail $Lines
    }
}

function Show-Logs {
    param([string]$LogFile)

    Get-LogTail -Path $LogFile
    Get-LogTail -Path (Get-ErrLogPath -LogFile $LogFile)
}

function Fail-Start {
    param(
        [string]$Name,
        [string]$PidFile,
        [string]$LogFile
    )

    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    Write-Host "Error: $Name failed to start."
    Write-Host "Log: $LogFile"
    Write-Host "Error log: $(Get-ErrLogPath -LogFile $LogFile)"
    Show-Logs -LogFile $LogFile
    exit 1
}

function Wait-HttpUrl {
    param(
        [string]$Name,
        [string]$PidFile,
        [string]$LogFile,
        [string]$Url,
        [int]$Seconds = 120
    )

    Write-Host "    Waiting for URL: $Url"

    for ($i = 1; $i -le $Seconds; $i++) {
        if (-not (Test-Running -PidFile $PidFile)) {
            Fail-Start -Name $Name -PidFile $PidFile -LogFile $LogFile
        }

        try {
            Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2 | Out-Null
            Write-Host "$Name started, PID: $(Get-PidValue -PidFile $PidFile)"
            Write-Host "URL: $Url"
            return
        } catch {
        }

        Start-Sleep -Seconds 1
    }

    Write-Host "Error: $Name is running, but URL was not reachable within $Seconds seconds."
    Write-Host "Log: $LogFile"
    Write-Host "Error log: $(Get-ErrLogPath -LogFile $LogFile)"
    Show-Logs -LogFile $LogFile
    exit 1
}

function Stop-ManagedProcess {
    param(
        [string]$Name,
        [string]$PidFile
    )

    if (-not (Test-Running -PidFile $PidFile)) {
        Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
        Write-Host "$Name is not running."
        return
    }

    $pidValue = Get-PidValue -PidFile $PidFile
    Write-Host "==> Stop $Name, PID: $pidValue"

    if (Get-Command taskkill -ErrorAction SilentlyContinue) {
        taskkill /PID $pidValue /T /F | Out-Null
    } else {
        Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue
    }

    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    Write-Host "$Name stopped."
}

function Show-ProcessStatus {
    param(
        [string]$Name,
        [string]$PidFile
    )

    if (Test-Running -PidFile $PidFile) {
        Write-Host "$Name is running, PID: $(Get-PidValue -PidFile $PidFile)"
    } else {
        Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
        Write-Host "$Name is not running."
    }
}

function Run-FrontendInitEnv {
    Require-Command 'pnpm'
    Write-Host '==> Install frontend dependencies'
    Invoke-NativeCommand -ErrorMessage 'Failed to install frontend dependencies.' -Command {
        pnpm -C (Join-Path $RootDir 'frontend') install
    }

    Write-Host '==> Initialize frontend env'
    Invoke-NativeCommand -ErrorMessage 'Failed to initialize frontend env.' -Command {
        pnpm -C (Join-Path $RootDir 'frontend') env:init
    }
}

function Run-BackendInitEnv {
    $script = Join-Path $RootDir 'backend/scripts/init.sh'
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
        throw 'Backend init script not found: backend/scripts/init.sh'
    }

    Require-Command 'bash'
    Write-Host '==> Initialize backend env'
    Invoke-NativeCommand -ErrorMessage 'Failed to initialize backend env.' -Command {
        Push-Location (Join-Path $RootDir 'backend')
        try {
            bash scripts/init.sh
        } finally {
            Pop-Location
        }
    }
    Write-Host 'Backend env initialized.'
}

function Invoke-InitEnv {
    param([string]$TargetName)

    if ([string]::IsNullOrWhiteSpace($TargetName)) {
        $TargetName = 'all'
    }

    switch ($TargetName) {
        'all' {
            Run-BackendInitEnv
            Run-FrontendInitEnv
        }
        'backend' {
            Run-BackendInitEnv
        }
        'frontend' {
            Run-FrontendInitEnv
        }
        default {
            Write-Host "Error: unknown init_env target: $TargetName"
            Show-Usage
            exit 1
        }
    }
}

function Get-BackendUrl {
    $configFile = Join-Path $RootDir 'backend/config/services.toml'
    $port = $null

    if (Test-Path -LiteralPath $configFile -PathType Leaf) {
        $inHttp = $false
        foreach ($line in Get-Content -LiteralPath $configFile) {
            if ($line -match '^\s*\[http\]\s*$') {
                $inHttp = $true
                continue
            }
            if ($line -match '^\s*\[') {
                $inHttp = $false
            }
            if ($inHttp -and $line -match '^\s*port\s*=\s*([0-9]+)') {
                $port = $Matches[1]
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($port)) {
        $port = '19878'
    }

    return "http://127.0.0.1:$port/"
}

function Install-FrontendDeps {
    Require-Command 'pnpm'
    Write-Host '==> Install frontend dependencies'
    Invoke-NativeCommand -ErrorMessage 'Failed to install frontend dependencies.' -Command {
        pnpm -C (Join-Path $RootDir 'frontend') install
    }
}

function Ensure-FrontendDeps {
    if (Test-Path -LiteralPath (Join-Path $RootDir 'frontend/node_modules') -PathType Container) {
        return
    }

    Write-Host 'Error: frontend dependencies are not installed.'
    Write-Host 'Please run: .\manage.ps1 frontend install'
    exit 1
}

function Get-FrontendUrlFromLogs {
    param([string]$LogFile)

    $files = @($LogFile, (Get-ErrLogPath -LogFile $LogFile))
    foreach ($file in $files) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            continue
        }

        $content = Get-Content -LiteralPath $file -Raw
        $matches = [regex]::Matches($content, 'https?://(?:localhost|127\.0\.0\.1|\[::1\])(?::[0-9]+)?/?')
        if ($matches.Count -gt 0) {
            return $matches[0].Value
        }
    }

    return $null
}

function Show-FrontendUrl {
    param(
        [string]$App,
        [string]$PidFile,
        [string]$LogFile
    )

    for ($i = 1; $i -le 10; $i++) {
        if (-not (Test-Running -PidFile $PidFile)) {
            Fail-Start -Name "frontend:$App" -PidFile $PidFile -LogFile $LogFile
        }

        $url = Get-FrontendUrlFromLogs -LogFile $LogFile
        if (-not [string]::IsNullOrWhiteSpace($url)) {
            Write-Host "frontend:$App started, PID: $(Get-PidValue -PidFile $PidFile)"
            Write-Host "URL: $url"
            return
        }

        Start-Sleep -Seconds 1
    }

    Write-Host "Error: frontend:$App did not print a URL in time."
    Write-Host "Log: $LogFile"
    Write-Host "Error log: $(Get-ErrLogPath -LogFile $LogFile)"
    Show-Logs -LogFile $LogFile
    exit 1
}

function Invoke-Backend {
    param([string]$BackendAction)

    $pidFile = Join-Path $RunDir 'backend.pid'
    $logFile = Join-Path $LogDir 'backend.log'

    switch ($BackendAction) {
        'start' {
            Require-Command 'cargo'
            Start-ManagedProcess `
                -Name 'backend' `
                -PidFile $pidFile `
                -LogFile $logFile `
                -WorkingDirectory (Join-Path $RootDir 'backend') `
                -FilePath (Resolve-CommandPath 'cargo') `
                -ArgumentList @('run', '-p', 'web-server')
            Wait-HttpUrl -Name 'backend' -PidFile $pidFile -LogFile $logFile -Url (Get-BackendUrl) -Seconds 120
        }
        'stop' {
            Stop-ManagedProcess -Name 'backend' -PidFile $pidFile
        }
        'restart' {
            Stop-ManagedProcess -Name 'backend' -PidFile $pidFile
            Invoke-Backend -BackendAction 'start'
        }
        'status' {
            Show-ProcessStatus -Name 'backend' -PidFile $pidFile
        }
        default {
            Show-Usage
            exit 1
        }
    }
}

function Invoke-Frontend {
    param(
        [string]$App,
        [string]$FrontendAction
    )

    if ($App -eq 'install') {
        Install-FrontendDeps
        return
    }

    if ([string]::IsNullOrWhiteSpace($App) -or [string]::IsNullOrWhiteSpace($FrontendAction)) {
        Show-Usage
        exit 1
    }

    $appDir = Join-Path $RootDir "frontend/apps/$App"
    if (-not (Test-Path -LiteralPath $appDir -PathType Container)) {
        throw "Frontend app not found: frontend/apps/$App"
    }

    $pidFile = Join-Path $RunDir "frontend-$App.pid"
    $logFile = Join-Path $LogDir "frontend-$App.log"

    switch ($FrontendAction) {
        'start' {
            Require-Command 'pnpm'
            Ensure-FrontendDeps
            Start-ManagedProcess `
                -Name "frontend:$App" `
                -PidFile $pidFile `
                -LogFile $logFile `
                -WorkingDirectory $appDir `
                -FilePath (Resolve-CommandPath 'pnpm') `
                -ArgumentList @('dev')
            Show-FrontendUrl -App $App -PidFile $pidFile -LogFile $logFile
        }
        'stop' {
            Stop-ManagedProcess -Name "frontend:$App" -PidFile $pidFile
        }
        'restart' {
            Stop-ManagedProcess -Name "frontend:$App" -PidFile $pidFile
            Invoke-Frontend -App $App -FrontendAction 'start'
        }
        'status' {
            Show-ProcessStatus -Name "frontend:$App" -PidFile $pidFile
        }
        default {
            Show-Usage
            exit 1
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Area)) {
    Show-Usage
    exit 0
}

switch ($Area) {
    'init_env' {
        Invoke-InitEnv -TargetName $Target
    }
    'backend' {
        Invoke-Backend -BackendAction $Target
    }
    'frontend' {
        Invoke-Frontend -App $Target -FrontendAction $Action
    }
    { $_ -in @('help', '--help', '-h') } {
        Show-Usage
    }
    default {
        Show-Usage
        exit 1
    }
}
