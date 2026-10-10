# 봇 실행: 설치가 안 되어 있으면 setup을 먼저 실행한다
# 설정 누락·Ollama 미실행 등은 봇이 시작 전에 검사하고 원인을 출력한다
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path '.\.venv\Scripts\python.exe') -or -not (Test-Path '.env')) {
    & "$PSScriptRoot\setup.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host '봇 시작 (종료: Ctrl+C)' -ForegroundColor Cyan
& '.\.venv\Scripts\python.exe' -m app.bot
exit $LASTEXITCODE
