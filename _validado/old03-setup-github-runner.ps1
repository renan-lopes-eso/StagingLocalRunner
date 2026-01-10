# ====================================
# Script 03: Setup GitHub Runner + Docker Network
# ====================================
# Este script deve ser executado NA MÁQUINA DE STAGING
# Pré-requisitos: Git e Docker Desktop já instalados (script 02)
#
# O que este script faz:
# 1. Cria Docker network para staging
# 2. Cria template de secrets.json
# 3. Configura GitHub Self-Hosted Runner
# 4. Instala runner como serviço Windows
# 5. Valida a instalação

param(
    [Parameter(Mandatory=$false)]
    [string]$GitHubToken = "",

    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = "",

    [Parameter(Mandatory=$false)]
    [string]$RunnerName = "staging-local-runner",

    [Parameter(Mandatory=$false)]
    [string]$RunnerPath = "C:\github-runner"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SETUP GITHUB RUNNER + DOCKER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ====================================
# Verificar Pré-requisitos
# ====================================
Write-Host "1. Verificando pre-requisitos..." -ForegroundColor Yellow

# Verificar Git
try {
    $gitVersion = git --version
    Write-Host "  ✓ Git instalado: $gitVersion" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Git nao encontrado! Execute o script 02-install-dependencies.ps1 primeiro." -ForegroundColor Red
    exit 1
}

# Verificar Docker
try {
    $dockerVersion = docker --version
    Write-Host "  ✓ Docker instalado: $dockerVersion" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Docker nao encontrado! Execute o script 02-install-dependencies.ps1 primeiro." -ForegroundColor Red
    Write-Host "  ! Se Docker foi instalado agora, reinicie o computador primeiro." -ForegroundColor Yellow
    exit 1
}

# Verificar se Docker está rodando
 Write-Host "  Verificando se Docker esta rodando..." -ForegroundColor White
 $dockerRunning = $false
 try {
     $ErrorActionPreference = "SilentlyContinue"
     $result = docker ps 2>&1
     if ($LASTEXITCODE -eq 0) {
         $dockerRunning = $true
     }
     $ErrorActionPreference = "Stop"
 }
 catch {
     $dockerRunning = $false
 }

 if ($dockerRunning) {
     Write-Host "  ✓ Docker esta rodando" -ForegroundColor Green
 }
 else {
     Write-Host "  ✗ Docker nao esta rodando!" -ForegroundColor Red
     Write-Host ""
     Write-Host "  Como resolver:" -ForegroundColor Yellow
     Write-Host "    1. Abra o Docker Desktop" -ForegroundColor White
     Write-Host "    2. Aguarde ele iniciar completamente (icone deve ficar verde)" -ForegroundColor White
     Write-Host "    3. Execute este script novamente" -ForegroundColor White
     Write-Host ""
     exit 1
 }

 Write-Host ""

# ====================================
# Criar Docker Network
# ====================================
Write-Host "2. Configurando Docker network..." -ForegroundColor Yellow

$networkExists = docker network ls --filter "name=staging-network" --format "{{.Name}}" | Select-String -Pattern "staging-network"

if ($networkExists) {
    Write-Host "  ✓ Network 'staging-network' ja existe" -ForegroundColor Green
}
else {
    try {
        docker network create staging-network | Out-Null
        Write-Host "  ✓ Network 'staging-network' criada com sucesso" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Erro ao criar network: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# ====================================
# Configurar Secrets
# ====================================
Write-Host "3. Configurando secrets..." -ForegroundColor Yellow

$configPath = "C:\configs"
$secretsFile = Join-Path $configPath "secrets.json"

if (-not (Test-Path $configPath)) {
    New-Item -Path $configPath -ItemType Directory | Out-Null
    Write-Host "  ✓ Pasta config/ criada" -ForegroundColor Green
}

# Criar secrets.json se não existir
if (-not (Test-Path $secretsFile)) {
    $template = @{
        mysql = @{ connectionString = "Server=your-mysql-server.com;Port=3306;Database=staging;Uid=staging_user;Pwd=your_password_here;" }
        github = @{ token = "ghp_YOUR_GITHUB_TOKEN_HERE" }
    } | ConvertTo-Json -Depth 10

    Set-Content -Path $secretsFile -Value $template
	
    Write-Host "  ✓ Arquivo secrets.json criado" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ! IMPORTANTE: Edite o arquivo secrets.json com suas credenciais reais!" -ForegroundColor Yellow
    Write-Host "  ! Caminho: $secretsFile" -ForegroundColor White
    Write-Host ""

    # Perguntar se quer abrir o arquivo agora
    $openFile = Read-Host "  Deseja abrir o arquivo agora para editar? (s/N)"
    if ($openFile -eq "s" -or $openFile -eq "S") {
        Start-Process notepad $secretsFile
        Write-Host ""
        Write-Host "  Edite o arquivo e salve. Pressione Enter quando terminar..." -ForegroundColor Yellow
        Read-Host
    }
}
else {
    Write-Host "  ✓ Arquivo secrets.json ja existe" -ForegroundColor Green
}

Write-Host ""