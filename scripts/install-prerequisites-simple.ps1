<#
.SYNOPSIS
    Instalação simplificada de pré-requisitos

.DESCRIPTION
    Versão simplificada sem funções complexas
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Instalacao de Pre-requisitos" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERRO: Execute como Administrador!" -ForegroundColor Red
    exit 1
}

Write-Host "VERIFICANDO O QUE JA ESTA INSTALADO..." -ForegroundColor Yellow
Write-Host ""

# Verificar Git
Write-Host "[1/4] Verificando Git..." -ForegroundColor Cyan
try {
    $gitVer = git --version 2>$null
    if ($gitVer) {
        Write-Host "  ✓ Git instalado: $gitVer" -ForegroundColor Green
        $needGit = $false
    }
}
catch {
    Write-Host "  ✗ Git nao encontrado" -ForegroundColor Red
    $needGit = $true
}

# Verificar .NET
Write-Host ""
Write-Host "[2/4] Verificando .NET SDK..." -ForegroundColor Cyan
try {
    $dotnetVer = dotnet --version 2>$null
    if ($dotnetVer) {
        Write-Host "  ✓ .NET SDK instalado: $dotnetVer" -ForegroundColor Green

        # Verificar se tem .NET 8
        $sdks = dotnet --list-sdks 2>$null
        if ($sdks -match "8\.") {
            Write-Host "  ✓ .NET 8.0 encontrado" -ForegroundColor Green
            $needDotnet = $false
        }
        else {
            Write-Host "  ! .NET 8.0 nao encontrado" -ForegroundColor Yellow
            $needDotnet = $true
        }
    }
}
catch {
    Write-Host "  ✗ .NET SDK nao encontrado" -ForegroundColor Red
    $needDotnet = $true
}

# Verificar Docker
Write-Host ""
Write-Host "[3/4] Verificando Docker..." -ForegroundColor Cyan
try {
    $dockerVer = docker --version 2>$null
    if ($dockerVer) {
        Write-Host "  ✓ Docker instalado: $dockerVer" -ForegroundColor Green

        # Verificar se está rodando
        docker ps 2>$null | Out-Null
        if ($?) {
            Write-Host "  ✓ Docker esta rodando" -ForegroundColor Green
            $needDocker = $false
        }
        else {
            Write-Host "  ! Docker instalado mas nao esta rodando" -ForegroundColor Yellow
            Write-Host "  ! Inicie o Docker Desktop" -ForegroundColor Yellow
            $needDocker = $false
        }
    }
}
catch {
    Write-Host "  ✗ Docker nao encontrado" -ForegroundColor Red
    $needDocker = $true
}

# Verificar Chocolatey
Write-Host ""
Write-Host "[4/4] Verificando Chocolatey..." -ForegroundColor Cyan
try {
    $chocoVer = choco --version 2>$null
    if ($chocoVer) {
        Write-Host "  ✓ Chocolatey instalado: $chocoVer" -ForegroundColor Green
        $needChoco = $false
    }
}
catch {
    Write-Host "  ✗ Chocolatey nao encontrado" -ForegroundColor Red
    $needChoco = $true
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Se tudo está instalado
if (-not $needGit -and -not $needDotnet -and -not $needDocker) {
    Write-Host "✓ TODOS OS PRE-REQUISITOS JA ESTAO INSTALADOS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proximo passo:" -ForegroundColor Cyan
    Write-Host "  docker network create staging-network" -ForegroundColor White
    Write-Host ""
    exit 0
}

# Mostrar o que será instalado
Write-Host "SERA INSTALADO:" -ForegroundColor Yellow
if ($needChoco) { Write-Host "  - Chocolatey (gerenciador de pacotes)" -ForegroundColor White }
if ($needGit) { Write-Host "  - Git" -ForegroundColor White }
if ($needDotnet) { Write-Host "  - .NET 8.0 SDK" -ForegroundColor White }
if ($needDocker) { Write-Host "  - Docker Desktop" -ForegroundColor White }
Write-Host ""

Write-Host "Continuar? (S/n): " -ForegroundColor Yellow -NoNewline
$confirm = Read-Host
if ($confirm -ne "" -and $confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Cancelado." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "INSTALANDO..." -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Instalar Chocolatey
if ($needChoco) {
    Write-Host "[PASSO 1] Instalando Chocolatey..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        # Recarregar PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        Write-Host "  ✓ Chocolatey instalado" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ ERRO: $_" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Instalar Git
if ($needGit) {
    Write-Host "[PASSO 2] Instalando Git..." -ForegroundColor Yellow
    choco install git -y
    Write-Host "  ✓ Git instalado" -ForegroundColor Green
    Write-Host ""
}

# Instalar .NET
if ($needDotnet) {
    Write-Host "[PASSO 3] Instalando .NET 8.0 SDK..." -ForegroundColor Yellow
    Write-Host "  ! Isso pode demorar..." -ForegroundColor Yellow
    choco install dotnet-sdk -y --version=8.0.0
    Write-Host "  ✓ .NET 8.0 SDK instalado" -ForegroundColor Green
    Write-Host ""
}

# Instalar Docker
if ($needDocker) {
    Write-Host "[PASSO 4] Instalando Docker Desktop..." -ForegroundColor Yellow
    Write-Host "  ! Isso pode demorar..." -ForegroundColor Yellow
    choco install docker-desktop -y
    Write-Host "  ✓ Docker Desktop instalado" -ForegroundColor Green
    Write-Host ""
    Write-Host "  ! IMPORTANTE:" -ForegroundColor Yellow
    Write-Host "    1. Reinicie o computador" -ForegroundColor White
    Write-Host "    2. Inicie o Docker Desktop" -ForegroundColor White
    Write-Host "    3. Aguarde inicializacao completa" -ForegroundColor White
    Write-Host ""
}

# Recarregar PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host "   ✓ INSTALACAO CONCLUIDA!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""

Write-Host "PROXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host ""

if ($needDocker) {
    Write-Host "1. REINICIE O COMPUTADOR" -ForegroundColor Yellow
    Write-Host "2. Inicie o Docker Desktop" -ForegroundColor Yellow
    Write-Host "3. Execute:" -ForegroundColor Yellow
}
else {
    Write-Host "1. Execute:" -ForegroundColor Yellow
}

Write-Host "   docker network create staging-network" -ForegroundColor White
Write-Host ""

Write-Host "Pressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
