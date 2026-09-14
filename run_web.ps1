$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
$proxy = $null

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
    flutter run -d chrome
}
finally {
    if ($null -ne $proxy -and -not $proxy.HasExited) {
        Stop-Process -Id $proxy.Id
    }
}
