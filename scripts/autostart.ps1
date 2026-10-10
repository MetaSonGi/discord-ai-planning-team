# 로그인 자동 실행용 봇 실행기: 중복 실행을 막고, 비정상 종료 시 대기 후 다시 시작한다
# 부팅 중에는 setup을 실행하지 않는다. 설치가 안 되어 있으면 안내만 하고 멈춘다.
Set-Location (Split-Path $PSScriptRoot -Parent)
$Host.UI.RawUI.WindowTitle = 'Discord 기획팀 봇 (자동 실행)'

$venvPython = '.\.venv\Scripts\python.exe'
$botMutexName = 'Local\DiscordPlanningBot'
$quickRunSeconds = 60          # 이보다 빨리 끝난 실패는 설정 오류 가능성이 높다
$quickFailureLimit = 5         # 빠른 실패가 연속 이 횟수에 도달하면 재시작을 멈춘다
$initialBackoffSeconds = 10
$maxBackoffSeconds = 60

function Write-Stamped($message, $color = 'Gray') {
    Write-Host "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] $message" -ForegroundColor $color
}

if (-not (Test-Path $venvPython) -or -not (Test-Path '.env')) {
    Write-Stamped '설치가 되어 있지 않습니다. setup.cmd를 먼저 실행하세요.' Red
    Read-Host '창을 닫으려면 Enter'
    exit 1
}

$botMutex = [System.Threading.Mutex]::new($false, $botMutexName)
$hasMutex = $false
$stopReason = $null
try {
    try {
        $hasMutex = $botMutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        # 이전 실행 창이 강제로 닫히면 Mutex가 버려진 상태로 남는다. 이 경우 소유권을 넘겨받는다.
        $hasMutex = $true
    }
    if (-not $hasMutex) {
        Write-Stamped '봇이 이미 실행 중입니다. 이 창은 종료합니다.' Yellow
        exit 0
    }

    $consecutiveQuickFailures = 0
    $backoffSeconds = $initialBackoffSeconds
    while ($true) {
        $startedAt = Get-Date
        Write-Stamped '봇 시작 (종료: Ctrl+C 또는 창 닫기)' Cyan
        & $venvPython -m app.bot
        $botExitCode = $LASTEXITCODE
        if ($botExitCode -eq 0) {
            Write-Stamped '봇이 정상 종료되었습니다.' Green
            break
        }

        # 오래 실행되다 끊긴 경우는 일시적 장애로 보고 카운터와 대기 시간을 초기화한다
        if (((Get-Date) - $startedAt).TotalSeconds -lt $quickRunSeconds) {
            $consecutiveQuickFailures++
        } else {
            $consecutiveQuickFailures = 0
            $backoffSeconds = $initialBackoffSeconds
        }
        if ($consecutiveQuickFailures -ge $quickFailureLimit) {
            $stopReason = "봇이 ${quickRunSeconds}초 안에 ${quickFailureLimit}번 연속 종료되었습니다. 위 오류 메시지와 .env 설정을 확인하세요."
            break
        }

        Write-Stamped "비정상 종료(코드 $botExitCode). ${backoffSeconds}초 후 다시 시작합니다." Yellow
        Start-Sleep -Seconds $backoffSeconds
        $backoffSeconds = [Math]::Min($backoffSeconds * 2, $maxBackoffSeconds)
    }
} finally {
    if ($hasMutex) { $botMutex.ReleaseMutex() }
    $botMutex.Dispose()
}

# 원인을 읽을 수 있도록 Mutex를 놓은 뒤에 창을 열어 둔다
if ($stopReason) {
    Write-Stamped "[중단] $stopReason" Red
    Read-Host '창을 닫으려면 Enter'
    exit 1
}
exit 0
