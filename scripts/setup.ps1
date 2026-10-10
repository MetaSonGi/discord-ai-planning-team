# 초기 설정: Python 확인 → .venv 생성 → 패키지 설치 → .env 생성 → Ollama 모델 준비 → 누락 설정 안내
# 여러 번 실행해도 안전하다. 기존 .venv와 .env는 덮어쓰지 않는다.
Set-Location (Split-Path $PSScriptRoot -Parent)

function Write-Step($message) { Write-Host "`n==> $message" -ForegroundColor Cyan }
function Write-Ok($message) { Write-Host "    $message" -ForegroundColor Green }
function Write-Warn($message) { Write-Host "    $message" -ForegroundColor Yellow }
function Stop-Setup($message) { Write-Host "`n[중단] $message" -ForegroundColor Red; exit 1 }

# .env를 KEY=VALUE 사전으로 읽는다 (주석·빈 줄 무시)
function Read-EnvFile($path) {
    $envValues = @{}
    foreach ($line in Get-Content $path -Encoding UTF8) {
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') { $envValues[$Matches[1]] = $Matches[2].Trim() }
    }
    return $envValues
}

# 1. Python 3.12 이상 찾기: py 런처 우선, 없으면 PATH의 python
Write-Step 'Python 확인'
$pythonExe = $null
$pythonArgs = @()
if (Get-Command py -ErrorAction SilentlyContinue) {
    foreach ($version in '3.13', '3.12', '3.14') {
        & py "-$version" -c "import sys" 2>$null
        if ($LASTEXITCODE -eq 0) { $pythonExe = 'py'; $pythonArgs = @("-$version"); break }
    }
}
if (-not $pythonExe -and (Get-Command python -ErrorAction SilentlyContinue)) {
    & python -c "import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)" 2>$null
    if ($LASTEXITCODE -eq 0) { $pythonExe = 'python' }
}
if (-not $pythonExe) { Stop-Setup 'Python 3.12 이상이 필요합니다. https://www.python.org/downloads/ 에서 설치하세요.' }
Write-Ok ((& $pythonExe @pythonArgs --version) + " 사용")

# 2. 가상환경
Write-Step '가상환경(.venv) 준비'
$venvPython = '.\.venv\Scripts\python.exe'
if (Test-Path $venvPython) {
    Write-Ok '기존 .venv 사용'
} else {
    & $pythonExe @pythonArgs -m venv .venv
    if ($LASTEXITCODE -ne 0) { Stop-Setup '.venv 생성 실패' }
    Write-Ok '.venv 생성 완료'
}

# 3. 패키지 설치
Write-Step '패키지 설치 (requirements.txt)'
& $venvPython -m pip install --disable-pip-version-check -q -r requirements.txt
if ($LASTEXITCODE -ne 0) { Stop-Setup '패키지 설치 실패. 인터넷 연결을 확인하세요.' }
Write-Ok '설치 완료'

# 4. .env 생성 (기존 파일은 절대 덮어쓰지 않음)
Write-Step '.env 준비'
if (Test-Path .env) {
    Write-Ok '기존 .env 유지'
} else {
    Copy-Item .env.example .env
    Write-Ok '.env.example → .env 복사 완료'
}
$envValues = Read-EnvFile '.env'

# 5. Ollama 준비 (LLM_PROVIDER=ollama일 때)
$llmProvider = if ($envValues['LLM_PROVIDER']) { $envValues['LLM_PROVIDER'].ToLower() } else { 'openai' }
if ($llmProvider -eq 'ollama') {
    Write-Step 'Ollama 준비'
    $ollamaModel = if ($envValues['OLLAMA_MODEL']) { $envValues['OLLAMA_MODEL'] } else { 'gemma3:4b' }
    $ollamaBaseUrl = if ($envValues['OLLAMA_BASE_URL']) { $envValues['OLLAMA_BASE_URL'].TrimEnd('/') } else { 'http://localhost:11434' }

    # PATH에 없으면 기본 설치 경로에서 찾는다
    $ollamaExe = (Get-Command ollama -ErrorAction SilentlyContinue).Source
    if (-not $ollamaExe -and (Test-Path "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe")) {
        $ollamaExe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
    }

    $installedModels = $null
    try {
        $installedModels = (Invoke-RestMethod "$ollamaBaseUrl/api/tags" -TimeoutSec 5).models | ForEach-Object { $_.name }
    } catch {
        $installedModels = $null
    }

    if ($null -eq $installedModels -and -not $ollamaExe) {
        Write-Warn 'Ollama가 설치되지 않았습니다. https://ollama.com/download 에서 설치 후 setup을 다시 실행하세요.'
        Write-Warn '(또는: winget install Ollama.Ollama)'
    } elseif ($null -eq $installedModels) {
        Write-Warn "Ollama 서버($ollamaBaseUrl)가 응답하지 않습니다. Ollama 앱을 실행한 뒤 setup을 다시 실행하세요."
    } elseif ($installedModels -contains $ollamaModel -or $installedModels -contains "$ollamaModel`:latest") {
        Write-Ok "모델 $ollamaModel 설치됨"
    } elseif ($ollamaExe) {
        Write-Ok "모델 $ollamaModel 다운로드 중 (수 GB, 시간이 걸릴 수 있음)"
        & $ollamaExe pull $ollamaModel
        if ($LASTEXITCODE -ne 0) { Write-Warn "모델 다운로드 실패. 직접 실행: ollama pull $ollamaModel" }
    } else {
        Write-Warn "모델이 없습니다. 직접 실행: ollama pull $ollamaModel"
    }
}

# 6. 테스트
Write-Step '단위 테스트'
& $venvPython -m unittest discover -s tests 2>&1 | Select-String -Pattern '^Ran |^OK|FAILED' | ForEach-Object { Write-Ok $_.Line }

# 7. 비어 있는 필수 설정 안내 (값은 출력하지 않음)
Write-Step '필수 설정 확인'
$requiredKeys = @('DISCORD_TOKEN', 'DISCORD_GUILD_ID', 'DISCORD_CHANNEL_ID', 'ALLOWED_USER_IDS', 'NOTION_TOKEN', 'NOTION_PARENT_PAGE_ID')
if ($llmProvider -eq 'openai') { $requiredKeys += 'OPENAI_API_KEY' }
$missingKeys = $requiredKeys | Where-Object { -not $envValues[$_] }
if ($missingKeys) {
    Write-Warn '.env에 아래 값을 입력하세요 (발급 방법은 .env 주석 참고):'
    $missingKeys | ForEach-Object { Write-Warn "  - $_" }
    Write-Host "`n입력 후 run.cmd 를 실행하면 봇이 시작됩니다." -ForegroundColor Cyan
} else {
    Write-Ok '모든 필수 설정 입력됨'
    Write-Host "`n준비 완료. run.cmd 를 실행하면 봇이 시작됩니다." -ForegroundColor Cyan
}
exit 0
