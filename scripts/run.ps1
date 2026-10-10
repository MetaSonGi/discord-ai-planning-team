# 봇 실행: 설치가 안 되어 있으면 setup을 먼저 실행한다
# 설정 누락·Ollama 미실행 등은 봇이 시작 전에 검사하고 원인을 출력한다
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path '.\.venv\Scripts\python.exe') -or -not (Test-Path '.env')) {
    & "$PSScriptRoot\setup.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# 자동 실행(autostart.ps1)과 같은 이름의 Mutex로 봇 중복 실행을 막는다
$botMutex = [System.Threading.Mutex]::new($false, 'Local\DiscordPlanningBot')
$hasMutex = $false
$botExitCode = 0
try {
    try {
        $hasMutex = $botMutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        $hasMutex = $true
    }
    if (-not $hasMutex) {
        Write-Host '봇이 이미 실행 중입니다 (자동 실행 창 확인). 중복 실행하지 않습니다.' -ForegroundColor Yellow
        exit 1
    }
    Write-Host '봇 시작 (종료: Ctrl+C)' -ForegroundColor Cyan
    & '.\.venv\Scripts\python.exe' -m app.bot
    $botExitCode = $LASTEXITCODE
} finally {
    if ($hasMutex) { $botMutex.ReleaseMutex() }
    $botMutex.Dispose()
}
exit $botExitCode
