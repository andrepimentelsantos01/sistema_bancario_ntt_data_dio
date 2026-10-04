$ErrorActionPreference = "Stop"

if ($args.Count -ne 1 -or $args[0] -ne "--local") {
    Write-Host "Uso: .\start --local" -ForegroundColor Yellow
    exit 1
}

$projectRoot = $PSScriptRoot
$backendPort = 8000
$healthUrl = "http://127.0.0.1:$backendPort/health"

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCommand) {
    throw "Python nao foi encontrado no PATH."
}

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { $null }

if (-not $flutterPath) {
    $userFlutter = Join-Path $env:USERPROFILE "develop\flutter\bin\flutter.bat"
    if (Test-Path -LiteralPath $userFlutter) {
        $flutterPath = $userFlutter
    }
}

if (-not $flutterPath) {
    throw "Flutter nao foi encontrado. Adicione a pasta flutter\bin ao PATH."
}

$backendProcess = $null

try {
    Write-Host "Iniciando API Python na porta $backendPort..." -ForegroundColor Cyan
    $backendProcess = Start-Process `
        -FilePath $pythonCommand.Source `
        -ArgumentList @("-m", "backend.server", "--port", "$backendPort") `
        -WorkingDirectory $projectRoot `
        -WindowStyle Hidden `
        -PassThru

    $backendReady = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        if ($backendProcess.HasExited) {
            throw "A API Python foi encerrada antes de ficar disponivel."
        }

        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $healthUrl -TimeoutSec 1
            if ($response.StatusCode -eq 200) {
                $backendReady = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 250
        }
    }

    if (-not $backendReady) {
        throw "A API Python nao respondeu em $healthUrl."
    }

    Write-Host "API pronta. Localizando navegador Flutter Web..." -ForegroundColor Green
    $deviceJson = & $flutterPath devices --machine
    if ($LASTEXITCODE -ne 0) {
        throw "Nao foi possivel consultar os dispositivos Flutter."
    }

    $devices = $deviceJson | ConvertFrom-Json
    $webDevice = $devices | Where-Object { $_.id -eq "edge" } | Select-Object -First 1
    if (-not $webDevice) {
        $webDevice = $devices | Where-Object { $_.id -eq "chrome" } | Select-Object -First 1
    }
    if (-not $webDevice) {
        throw "Nenhum navegador compativel com Flutter Web foi encontrado."
    }

    Write-Host "Abrindo o aplicativo no $($webDevice.name)..." -ForegroundColor Green
    Push-Location (Join-Path $projectRoot "frontend")
    try {
        & $flutterPath run -d $webDevice.id --web-hostname 127.0.0.1
    }
    finally {
        Pop-Location
    }
}
finally {
    if ($backendProcess -and -not $backendProcess.HasExited) {
        Write-Host "Encerrando API Python..." -ForegroundColor DarkGray
        Stop-Process -Id $backendProcess.Id -Force
    }
}
