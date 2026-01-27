# 06-trust-caddy-cert.ps1
# Instala o certificado raiz do Caddy como confiavel no Windows
# Requer execucao como Administrador

#Requires -RunAsAdministrator

Write-Host "Procurando certificado raiz do Caddy..." -ForegroundColor Cyan

# Procurar em locais conhecidos primeiro (mais rapido)
$knownPaths = @(
    "$env:LOCALAPPDATA\Caddy\pki\authorities\local\root.crt",
    "$env:APPDATA\Caddy\pki\authorities\local\root.crt",
    "C:\ProgramData\Caddy\pki\authorities\local\root.crt",
    "C:\Windows\System32\config\systemprofile\AppData\Roaming\Caddy\pki\authorities\local\root.crt",
    "C:\Windows\System32\config\systemprofile\AppData\Local\Caddy\pki\authorities\local\root.crt"
)

$certPath = $null

foreach ($path in $knownPaths) {
    if (Test-Path $path) {
        $certPath = $path
        Write-Host "Encontrado em: $certPath" -ForegroundColor Green
        break
    }
}

# Se nao encontrou nos locais conhecidos, buscar no disco
if (-not $certPath) {
    Write-Host "Nao encontrado nos locais conhecidos. Buscando no disco C:\..." -ForegroundColor Yellow
    $found = Get-ChildItem -Path "C:\" -Recurse -Filter "root.crt" -ErrorAction SilentlyContinue 2>$null |
             Where-Object { $_.FullName -like "*Caddy*" } |
             Select-Object -First 1

    if ($found) {
        $certPath = $found.FullName
        Write-Host "Encontrado em: $certPath" -ForegroundColor Green
    }
}

if (-not $certPath) {
    Write-Host "Certificado raiz do Caddy nao encontrado!" -ForegroundColor Red
    Write-Host "Verifique se o Caddy esta instalado e foi executado pelo menos uma vez." -ForegroundColor Yellow
    exit 1
}

# Instalar certificado
Write-Host "`nInstalando certificado no Trusted Root Certification Authorities..." -ForegroundColor Cyan

$result = certutil -addstore -f "ROOT" $certPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nCertificado instalado com sucesso!" -ForegroundColor Green
    Write-Host "Reinicie o navegador para aplicar as alteracoes." -ForegroundColor Yellow
} else {
    Write-Host "`nErro ao instalar certificado." -ForegroundColor Red
    Write-Host $result
    exit 1
}

# Copiar certificado para a pasta do script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$destPath = Join-Path $scriptDir "caddy-root.crt"
Copy-Item -Path $certPath -Destination $destPath -Force
Write-Host "`nCertificado copiado para: $destPath" -ForegroundColor Cyan
Write-Host "Use este arquivo para instalar em outras maquinas." -ForegroundColor Yellow
