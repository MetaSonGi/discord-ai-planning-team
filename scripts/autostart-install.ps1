# 로그인 시 자동 실행 등록: 시작프로그램 폴더에 최소화 창으로 뜨는 바로가기를 만든다
# 관리자 권한이 필요 없다. 이미 있으면 현재 폴더 경로로 덮어쓴다.
$projectRoot = Split-Path $PSScriptRoot -Parent
$autostartScript = Join-Path $PSScriptRoot 'autostart.ps1'
$startupFolder = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupFolder 'DiscordPlanningBot.lnk'
$powershellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$minimizedWindowStyle = 7

if (-not (Test-Path $autostartScript)) {
    Write-Host "[중단] 실행 스크립트가 없습니다: $autostartScript" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path (Join-Path $projectRoot '.venv\Scripts\python.exe')) -or -not (Test-Path (Join-Path $projectRoot '.env'))) {
    Write-Host '경고: 아직 설치가 안 되어 있습니다. 등록은 하지만 다음 로그인 전에 setup.cmd를 실행하세요.' -ForegroundColor Yellow
}

try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $powershellExe
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$autostartScript`""
    $shortcut.WorkingDirectory = $projectRoot
    $shortcut.WindowStyle = $minimizedWindowStyle
    $shortcut.Description = 'Discord AI 기획팀 봇 자동 실행'
    $shortcut.Save()
} catch {
    Write-Host "[중단] 바로가기 생성 실패: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "자동 실행 등록 완료: $shortcutPath" -ForegroundColor Green
Write-Host '다음 로그인부터 봇이 최소화 창으로 실행됩니다. 해제: autostart-uninstall.cmd' -ForegroundColor Cyan
Write-Host '프로젝트 폴더를 옮기면 이 등록을 다시 실행해야 합니다.' -ForegroundColor Cyan
exit 0
