<#
.SYNOPSIS
    Instala todos os pré-requisitos necessários na máquina de staging

.DESCRIPTION
    Este script instala e configura:
    - Docker Desktop for Windows
    - .NET 8.0 SDK
    - Git for Windows
    - Verifica configurações necessárias

.PARAMETER SkipDocker
    Pula instalação do Docker (se já estiver instalado)

.PARAMETER SkipDotnet
    Pula instalação do .NET SDK (se já estiver instalado)

.PARAMETER SkipGit
    Pula instalação do Git (se já estiver instalado)

.EXAMPLE
    .\install-prerequisites.ps1

.EXAMPLE
    .\install-prerequisites.ps1 -SkipDocker
#>

param(
    [switch]$SkipDocker = $false,
    [switch]$SkipDotnet = $false,
    [switch]$SkipGit = $false
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Instalacao de Pre-requisitos" -ForegroundColor Cyan
Write-Host "   Sistema Multi-Staging" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se está rodando como administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERRO: Este script precisa ser executado como Administrador!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Clique com botao direito no PowerShell e selecione 'Executar como Administrador'" -ForegroundColor Yellow
    exit 1
}

# Função para verificar se um comando existe
function Test-Command {
    param($Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    }
    catch {
        return $false
    }
}

Write-Host "VERIFICANDO ESTADO ATUAL DO SISTEMA" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow
Write-Host ""

# Verificar Git
Write-Host "[1/3] Verificando Git..." -ForegroundColor Cyan
$gitInstalled = Test-Command "git"
if ($gitInstalled) {
    $gitVersion = git --version
    Write-Host "  ✓ Git ja instalado: $gitVersion" -ForegroundColor Green
    $SkipGit = $true
}
else {
    Write-Host "  ✗ Git nao encontrado" -ForegroundColor Red
}

# Verificar .NET
Write-Host ""
Write-Host "[2/3] Verificando .NET SDK..." -ForegroundColor Cyan
$dotnetInstalled = Test-Command "dotnet"
if ($dotnetInstalled) {
    $dotnetVersion = dotnet --version
    Write-Host "  ✓ .NET SDK ja instalado: $dotnetVersion" -ForegroundColor Green

    # Verificar se é .NET 8.0 ou superior
    $dotnetSdks = dotnet --list-sdks
    $hasDotnet8 = $dotnetSdks | Select-String "8\."

    if ($hasDotnet8) {
        Write-Host "  ✓ .NET 8.0 SDK encontrado" -ForegroundColor Green
        $SkipDotnet = $true
    }
    else {
        Write-Host "  ! .NET 8.0 SDK nao encontrado, sera instalado" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  ✗ .NET SDK nao encontrado" -ForegroundColor Red
}

# Verificar Docker
Write-Host ""
Write-Host "[3/3] Verificando Docker..." -ForegroundColor Cyan
$dockerInstalled = Test-Command "docker"
if ($dockerInstalled) {
    $dockerVersion = docker --version
    Write-Host "  ✓ Docker ja instalado: $dockerVersion" -ForegroundColor Green

    # Verificar se está rodando
    try {
        docker ps | Out-Null
        Write-Host "  ✓ Docker esta rodando" -ForegroundColor Green
        $SkipDocker = $true
    }
    catch {
        Write-Host "  ! Docker instalado mas nao esta rodando" -ForegroundColor Yellow
        Write-Host "  ! Inicie o Docker Desktop manualmente" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  ✗ Docker nao encontrado" -ForegroundColor Red
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Resumo do que será instalado
$toInstall = @()
if (-not $SkipGit) { $toInstall += "Git" }
if (-not $SkipDotnet) { $toInstall += ".NET 8.0 SDK" }
if (-not $SkipDocker) { $toInstall += "Docker Desktop" }

if ($toInstall.Count -eq 0) {
    Write-Host "✓ TODOS OS PRE-REQUISITOS JA ESTAO INSTALADOS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proximo passo: Configurar o ambiente" -ForegroundColor Cyan
    Write-Host "  1. Criar Docker network: docker network create staging-network" -ForegroundColor White
    Write-Host "  2. Configurar secrets: config\secrets.json" -ForegroundColor White
    Write-Host "  3. Setup GitHub Runner" -ForegroundColor White
    Write-Host ""
    exit 0
}

Write-Host "SERA INSTALADO:" -ForegroundColor Yellow
foreach ($item in $toInstall) {
    Write-Host "  - $item" -ForegroundColor White
}
Write-Host ""

Write-Host "ATENCAO: Este processo pode demorar varios minutos!" -ForegroundColor Yellow
Write-Host "Continuar? (S/n): " -ForegroundColor Yellow -NoNewline
$confirm = Read-Host

if ($confirm -ne "" -and $confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Instalacao cancelada." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "INICIANDO INSTALACAO" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Instalar Chocolatey (gerenciador de pacotes)
Write-Host "Verificando Chocolatey..." -ForegroundColor Yellow
$chocoInstalled = Test-Command "choco"

if (-not $chocoInstalled) {
    Write-Host "  Instalando Chocolatey..." -ForegroundColor White
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "  ✓ Chocolatey instalado" -ForegroundColor Green

        # Recarregar PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Host "  ✗ Erro ao instalar Chocolatey: $_" -ForegroundColor Red
        Write-Host "  ! Voce precisara instalar os programas manualmente" -ForegroundColor Yellow
        exit 1
    }
}
else {
    Write-Host "  ✓ Chocolatey ja instalado" -ForegroundColor Green
}

Write-Host ""

# Instalar Git
if (-not $SkipGit) {
    Write-Host "[1/$($toInstall.Count)] Instalando Git..." -ForegroundColor Yellow
    try {
        choco install git -y --no-progress
        Write-Host "  ✓ Git instalado com sucesso" -ForegroundColor Green

        # Recarregar PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Host "  ✗ Erro ao instalar Git: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Instalar .NET 8.0 SDK
if (-not $SkipDotnet) {
    Write-Host "[2/$($toInstall.Count)] Instalando .NET 8.0 SDK..." -ForegroundColor Yellow
    Write-Host "  ! Isso pode demorar varios minutos..." -ForegroundColor Yellow
    try {
        choco install dotnet-sdk -y --version=8.0.0 --no-progress
        Write-Host "  ✓ .NET 8.0 SDK instalado com sucesso" -ForegroundColor Green

        # Recarregar PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Host "  ✗ Erro ao instalar .NET SDK: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Instalar Docker Desktop
if (-not $SkipDocker) {
    Write-Host "[3/$($toInstall.Count)] Instalando Docker Desktop..." -ForegroundColor Yellow
    Write-Host "  ! ATENCAO: Docker Desktop pode precisar de reinicializacao!" -ForegroundColor Yellow
    Write-Host "  ! Isso pode demorar varios minutos..." -ForegroundColor Yellow
    try {
        choco install docker-desktop -y --no-progress
        Write-Host "  ✓ Docker Desktop instalado" -ForegroundColor Green
        Write-Host ""
        Write-Host "  ! IMPORTANTE: Apos a instalacao:" -ForegroundColor Yellow
        Write-Host "    1. Reinicie o computador" -ForegroundColor White
        Write-Host "    2. Inicie o Docker Desktop" -ForegroundColor White
        Write-Host "    3. Aceite os termos de uso" -ForegroundColor White
        Write-Host "    4. Aguarde o Docker inicializar completamente" -ForegroundColor White
    }
    catch {
        Write-Host "  ✗ Erro ao instalar Docker Desktop: $_" -ForegroundColor Red
        Write-Host "  ! Instale manualmente: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host "   ✓ INSTALACAO CONCLUIDA!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""

# Verificar instalações
Write-Host "VERIFICANDO INSTALACOES..." -ForegroundColor Cyan
Write-Host ""

# Recarregar PATH para detectar novos programas
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

$allInstalled = $true

if (Test-Command "git") {
    $gitVer = git --version
    Write-Host "  ✓ Git: $gitVer" -ForegroundColor Green
}
else {
    Write-Host "  ✗ Git: Nao detectado (pode precisar reiniciar PowerShell)" -ForegroundColor Yellow
    $allInstalled = $false
}

if (Test-Command "dotnet") {
    $dotnetVer = dotnet --version
    Write-Host "  ✓ .NET SDK: $dotnetVer" -ForegroundColor Green
}
else {
    Write-Host "  ✗ .NET SDK: Nao detectado (pode precisar reiniciar PowerShell)" -ForegroundColor Yellow
    $allInstalled = $false
}

if (Test-Command "docker") {
    $dockerVer = docker --version
    Write-Host "  ✓ Docker: $dockerVer" -ForegroundColor Green
}
else {
    Write-Host "  ✗ Docker: Nao detectado (pode precisar reiniciar)" -ForegroundColor Yellow
    $allInstalled = $false
}

Write-Host ""

if (-not $allInstalled) {
    Write-Host "! IMPORTANTE: Feche e abra o PowerShell novamente" -ForegroundColor Yellow
    Write-Host "! Se Docker foi instalado, REINICIE o computador" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "PROXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Se Docker foi instalado:" -ForegroundColor Yellow
Write-Host "   - Reinicie o computador" -ForegroundColor White
Write-Host "   - Inicie o Docker Desktop" -ForegroundColor White
Write-Host "   - Aguarde inicializacao completa" -ForegroundColor White
Write-Host ""
Write-Host "2. Criar Docker network:" -ForegroundColor Yellow
Write-Host "   docker network create staging-network" -ForegroundColor White
Write-Host ""
Write-Host "3. Configurar secrets MySQL:" -ForegroundColor Yellow
Write-Host "   cd D:\git\StaggingLocalRunner" -ForegroundColor White
Write-Host "   cp config\secrets.template.json config\secrets.json" -ForegroundColor White
Write-Host "   notepad config\secrets.json" -ForegroundColor White
Write-Host ""
Write-Host "4. Setup GitHub Runner:" -ForegroundColor Yellow
Write-Host "   .\scripts\setup-runner.ps1 -GitHubToken ""ghp_SEU_TOKEN""" -ForegroundColor White
Write-Host ""
Write-Host "5. Iniciar Traefik (opcional):" -ForegroundColor Yellow
Write-Host "   cd traefik" -ForegroundColor White
Write-Host "   docker-compose up -d" -ForegroundColor White
Write-Host ""

Write-Host "Consulte o README.md para documentacao completa" -ForegroundColor Cyan
Write-Host ""

# Salvar log de instalação
$logFile = "installation-log.txt"
$logContent = @"
========================================
  LOG DE INSTALACAO - PRE-REQUISITOS
========================================

Data/Hora: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

INSTALADO:
$($toInstall -join "`n")

PROXIMOS PASSOS:
1. Reiniciar computador (se Docker foi instalado)
2. Criar Docker network
3. Configurar secrets
4. Setup GitHub Runner
5. Testar deploy

========================================
"@

$logContent | Out-File -FilePath $logFile -Encoding UTF8
Write-Host "Log salvo em: $logFile" -ForegroundColor Green
Write-Host ""

Write-Host "Pressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
