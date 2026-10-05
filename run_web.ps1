$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
$proxy = $null

# Limpa processos órfãos de sessões anteriores que fecharam com Ctrl+C
Write-Host 'Limpando processos antigos...'
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'tool/brapi_proxy.dart' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

try {
    Write-Host 'Iniciando proxy seguro da brapi em http://localhost:8080...'
    $proxy = Start-Process `
        -FilePath 'dart' `
        -ArgumentList @('run', 'tool/brapi_proxy.dart') `
        -WorkingDirectory $projectDirectory `
        -WindowStyle Hidden `
        -PassThru

    Start-Sleep -Seconds 2
    if ($proxy.HasExited) {
        throw 'O proxy não iniciou. Confira se BRAPI_TOKEN está preenchido no .env.'
    }

    Write-Host 'Iniciando Bolsa Fácil no Chrome...'
    Set-Location -LiteralPath $projectDirectory
    $chromeDataDir = Join-Path $projectDirectory '.chrome-data'
    flutter run -d chrome --web-port 3000 --web-browser-flag="--user-data-dir=$chromeDataDir"
}
finally {
    if ($null -ne $proxy -and -not $proxy.HasExited) {
        Stop-Process -Id $proxy.Id
    }
}
