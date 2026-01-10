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
try {
    docker ps | Out-Null
    Write-Host "  ✓ Docker esta rodando" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Docker nao esta rodando!" -ForegroundColor Red
    Write-Host "  ! Abra o Docker Desktop e aguarde ele iniciar completamente." -ForegroundColor Yellow
    Write-Host "  ! Depois execute este script novamente." -ForegroundColor Yellow
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

$configPath = Join-Path (Get-Location) "config"
$secretsTemplate = Join-Path $configPath "secrets.template.json"
$secretsFile = Join-Path $configPath "secrets.json"

if (-not (Test-Path $configPath)) {
    New-Item -Path $configPath -ItemType Directory | Out-Null
    Write-Host "  ✓ Pasta config/ criada" -ForegroundColor Green
}

# Criar template se não existir
if (-not (Test-Path $secretsTemplate)) {
    $template = @{
        mysql = @{
            connectionString = "Server=your-mysql-server.com;Port=3306;Database=staging;Uid=staging_user;Pwd=your_password_here;"
        }
        github = @{
            token = "ghp_YOUR_GITHUB_TOKEN_HERE"
        }
    } | ConvertTo-Json -Depth 10

    Set-Content -Path $secretsTemplate -Value $template
    Write-Host "  ✓ Template secrets.template.json criado" -ForegroundColor Green
}

# Criar secrets.json se não existir
if (-not (Test-Path $secretsFile)) {
    Copy-Item $secretsTemplate $secretsFile
    Write-Host "  ✓ Arquivo secrets.json criado" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ! IMPORTANTE: Edite o arquivo config/secrets.json com suas credenciais reais!" -ForegroundColor Yellow
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

# ====================================
# Obter Informações do GitHub
# ====================================
Write-Host "4. Configurando GitHub Runner..." -ForegroundColor Yellow
Write-Host ""

# Tentar obter repo do git se não foi fornecido
if ([string]::IsNullOrWhiteSpace($GitHubRepo)) {
    try {
        $repoUrl = git config --get remote.origin.url
        if ($repoUrl -match 'github\.com[:/](.*)\.git') {
            $GitHubRepo = $matches[1]
            Write-Host "  Repositorio detectado: $GitHubRepo" -ForegroundColor Green
        }
        else {
            Write-Host "  ! Nao foi possivel detectar o repositorio automaticamente" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ! Nao foi possivel detectar o repositorio automaticamente" -ForegroundColor Yellow
    }
}

# Solicitar repo se ainda não tiver
if ([string]::IsNullOrWhiteSpace($GitHubRepo)) {
    Write-Host ""
    Write-Host "  Digite o repositorio GitHub (formato: owner/repo)" -ForegroundColor White
    Write-Host "  Exemplo: meuusuario/StagingLocalRunner" -ForegroundColor Gray
    $GitHubRepo = Read-Host "  Repositorio"

    if ([string]::IsNullOrWhiteSpace($GitHubRepo)) {
        Write-Host "  ✗ Repositorio nao pode ser vazio!" -ForegroundColor Red
        exit 1
    }
}

# Solicitar GitHub Token se não foi fornecido
if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host "  GITHUB PERSONAL ACCESS TOKEN" -ForegroundColor Cyan
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Voce precisa de um GitHub Personal Access Token (Classic)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Como criar:" -ForegroundColor Yellow
    Write-Host "    1. Va em: https://github.com/settings/tokens" -ForegroundColor White
    Write-Host "    2. Clique em 'Generate new token (classic)'" -ForegroundColor White
    Write-Host "    3. Selecione os scopes:" -ForegroundColor White
    Write-Host "       - repo (todas)" -ForegroundColor Gray
    Write-Host "       - workflow" -ForegroundColor Gray
    Write-Host "       - admin:org (read:org)" -ForegroundColor Gray
    Write-Host "    4. Clique em 'Generate token'" -ForegroundColor White
    Write-Host "    5. Copie o token (comeca com 'ghp_')" -ForegroundColor White
    Write-Host ""

    $GitHubToken = Read-Host "  Cole o GitHub Token aqui" -AsSecureString
    $GitHubToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($GitHubToken))

    if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
        Write-Host "  ✗ Token nao pode ser vazio!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "  Configuracao:" -ForegroundColor Green
Write-Host "    Repositorio: $GitHubRepo" -ForegroundColor White
Write-Host "    Runner Name: $RunnerName" -ForegroundColor White
Write-Host "    Runner Path: $RunnerPath" -ForegroundColor White
Write-Host ""

# ====================================
# Download e Configuração do Runner
# ====================================

# Criar diretório do runner
if (-not (Test-Path $RunnerPath)) {
    New-Item -Path $RunnerPath -ItemType Directory | Out-Null
    Write-Host "  ✓ Pasta do runner criada: $RunnerPath" -ForegroundColor Green
}

Set-Location $RunnerPath

# Verificar se já está configurado
if (Test-Path ".\config.sh") {
    Write-Host "  ! Runner ja esta configurado neste diretorio" -ForegroundColor Yellow

    $reconfigure = Read-Host "  Deseja reconfigurar? Isso vai remover a configuracao atual (s/N)"
    if ($reconfigure -eq "s" -or $reconfigure -eq "S") {
        Write-Host "  Removendo configuracao anterior..." -ForegroundColor Yellow

        # Parar servico se existir
        try {
            & .\svc.sh stop
            & .\svc.sh uninstall
        }
        catch {
            # Ignorar se não houver serviço
        }

        # Remover configuração
        & .\config.cmd remove --token $GitHubToken
    }
    else {
        Write-Host "  Pulando configuracao do runner..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Setup concluido!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        exit 0
    }
}

# Download do runner
$runnerVersion = "2.319.1"
$runnerPackage = "actions-runner-win-x64-$runnerVersion.zip"
$runnerUrl = "https://github.com/actions/runner/releases/download/v$runnerVersion/$runnerPackage"

if (-not (Test-Path ".\run.cmd")) {
    Write-Host "  Baixando GitHub Actions Runner v$runnerVersion..." -ForegroundColor Yellow

    if (Test-Path $runnerPackage) {
        Remove-Item $runnerPackage -Force
    }

    try {
        Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerPackage
        Write-Host "  ✓ Download concluido" -ForegroundColor Green

        Write-Host "  Extraindo arquivos..." -ForegroundColor Yellow
        Expand-Archive -Path $runnerPackage -DestinationPath . -Force
        Write-Host "  ✓ Arquivos extraidos" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Erro ao baixar/extrair runner: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "  ✓ Runner ja esta baixado" -ForegroundColor Green
}

# Obter registration token do GitHub
Write-Host "  Obtendo token de registro do GitHub..." -ForegroundColor Yellow

try {
    $headers = @{
        "Authorization" = "token $GitHubToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    $tokenUrl = "https://api.github.com/repos/$GitHubRepo/actions/runners/registration-token"
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers $headers
    $registrationToken = $response.token
    Write-Host "  ✓ Token de registro obtido" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Erro ao obter token de registro: $_" -ForegroundColor Red
    Write-Host "  ! Verifique se o GitHub Token esta correto e tem permissoes necessarias" -ForegroundColor Yellow
    exit 1
}

# Configurar runner
Write-Host "  Configurando runner..." -ForegroundColor Yellow

try {
    $configArgs = @(
        "--url", "https://github.com/$GitHubRepo",
        "--token", $registrationToken,
        "--name", $RunnerName,
        "--work", "_work",
        "--labels", "self-hosted,Windows,staging",
        "--unattended"
    )

    & .\config.cmd @configArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Erro na configuracao do runner"
    }

    Write-Host "  ✓ Runner configurado com sucesso" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Erro ao configurar runner: $_" -ForegroundColor Red
    exit 1
}

# Instalar como serviço
Write-Host "  Instalando como servico Windows..." -ForegroundColor Yellow

try {
    & .\svc.sh install
    Write-Host "  ✓ Servico instalado" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Erro ao instalar servico: $_" -ForegroundColor Red
    exit 1
}

# Iniciar serviço
Write-Host "  Iniciando servico..." -ForegroundColor Yellow

try {
    & .\svc.sh start
    Start-Sleep -Seconds 3
    Write-Host "  ✓ Servico iniciado" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Erro ao iniciar servico: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ====================================
# Validação
# ====================================
Write-Host "5. Validando instalacao..." -ForegroundColor Yellow

# Verificar serviço
$service = Get-Service | Where-Object {$_.Name -like "*actions.runner*"}
if ($service -and $service.Status -eq "Running") {
    Write-Host "  ✓ Servico do runner esta rodando" -ForegroundColor Green
}
else {
    Write-Host "  ✗ Servico do runner nao esta rodando!" -ForegroundColor Red
}

# Verificar network Docker
$networkCheck = docker network ls --filter "name=staging-network" --format "{{.Name}}"
if ($networkCheck) {
    Write-Host "  ✓ Docker network 'staging-network' esta ativa" -ForegroundColor Green
}
else {
    Write-Host "  ✗ Docker network nao encontrada!" -ForegroundColor Red
}

Write-Host ""

# ====================================
# Resumo Final
# ====================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SETUP CONCLUIDO COM SUCESSO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Proximo passo:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Configure o GitHub Secret no repositorio:" -ForegroundColor White
Write-Host "   - Va em: https://github.com/$GitHubRepo/settings/secrets/actions" -ForegroundColor Gray
Write-Host "   - Clique em 'New repository secret'" -ForegroundColor Gray
Write-Host "   - Name: MYSQL_CONNECTION_STRING" -ForegroundColor Gray
Write-Host "   - Value: Sua connection string do MySQL" -ForegroundColor Gray
Write-Host "     Exemplo: Server=mysql.example.com;Port=3306;Database=staging;Uid=user;Pwd=pass;" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Verifique o runner no GitHub:" -ForegroundColor White
Write-Host "   - Va em: https://github.com/$GitHubRepo/settings/actions/runners" -ForegroundColor Gray
Write-Host "   - Voce deve ver '$RunnerName' com status 'Idle'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Teste o sistema:" -ForegroundColor White
Write-Host "   - Crie uma branch: git checkout -b staging/test" -ForegroundColor Gray
Write-Host "   - Faca push: git push origin staging/test" -ForegroundColor Gray
Write-Host "   - Acompanhe em: https://github.com/$GitHubRepo/actions" -ForegroundColor Gray
Write-Host ""
Write-Host "Comandos uteis:" -ForegroundColor Yellow
Write-Host "  Ver status do runner:" -ForegroundColor White
Write-Host "    cd $RunnerPath" -ForegroundColor Gray
Write-Host "    .\svc.sh status" -ForegroundColor Gray
Write-Host ""
Write-Host "  Ver logs do runner:" -ForegroundColor White
Write-Host "    cd $RunnerPath" -ForegroundColor Gray
Write-Host "    Get-Content .\_diag\*.log -Tail 50" -ForegroundColor Gray
Write-Host ""
Write-Host "  Reiniciar runner:" -ForegroundColor White
Write-Host "    cd $RunnerPath" -ForegroundColor Gray
Write-Host "    .\svc.sh stop && .\svc.sh start" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
