# 로그인 시 자동 실행 해제: 시작프로그램 폴더의 바로가기를 삭제한다
# 이미 실행 중인 봇은 종료하지 않는다. 최소화된 봇 창을 직접 닫는다.
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'DiscordPlanningBot.lnk'

if (-not (Test-Path $shortcutPath)) {
    Write-Host '등록된 자동 실행이 없습니다.' -ForegroundColor Yellow
    exit 0
}

try {
    Remove-Item $shortcutPath -ErrorAction Stop
} catch {
    Write-Host "[중단] 바로가기 삭제 실패: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host '자동 실행 해제 완료. 실행 중인 봇은 봇 창을 닫아 종료하세요.' -ForegroundColor Green
exit 0
