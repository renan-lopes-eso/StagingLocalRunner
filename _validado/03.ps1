# Script 03: Setup GitHub Runner + Docker Network

param(
    [string]$GitHubToken = "",
    [string]$GitHubOrg = "",
    [string]$RunnerName = "staging-local-runner",
    [string]$RunnerPath = "C:\configs\runner"
)

$configPath = "C:\configs"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SETUP GITHUB RUNNER + DOCKER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar Git
Write-Host "1. Verificando pre-requisitos..." -ForegroundColor Yellow
try {
    $gitVersion = git --version
    Write-Host "  Git instalado: $gitVersion" -ForegroundColor Green
}
catch {
    Write-Host "  Git nao encontrado!" -ForegroundColor Red
    Read-Host
    exit 1
}

# Verificar Docker
try {
    $dockerVersion = docker --version
    Write-Host "  Docker instalado: $dockerVersion" -ForegroundColor Green
}
catch {
    Write-Host "  Docker nao encontrado!" -ForegroundColor Red
    Read-Host
    exit 1
}

# Verificar se Docker esta rodando
$dockerRunning = $false
try {
    $result = docker ps 2>&1
    if ($LASTEXITCODE -eq 0) { $dockerRunning = $true }
}
catch { $dockerRunning = $false }

if ($dockerRunning) {
    Write-Host "  Docker esta rodando" -ForegroundColor Green
}
else {
    Write-Host "  Docker nao esta rodando!" -ForegroundColor Red
    Write-Host "  Abra o Docker Desktop e execute novamente" -ForegroundColor Yellow
    Read-Host
    exit 1
}

Write-Host ""

# Criar Docker Network
Write-Host "2. Configurando Docker network..." -ForegroundColor Yellow
$networkExists = docker network ls --filter "name=staging-network" --format "{{.Name}}" | Select-String -Pattern "staging-network"

if ($networkExists) {
    Write-Host "  Network staging-network ja existe" -ForegroundColor Green
}
else {
    try {
        $dockerOs = docker version --format '{{.Server.Os}}' 2>$null
        if ($dockerOs -eq "windows") {
            docker network create --driver nat staging-network | Out-Null
        }
        else {
            docker network create staging-network | Out-Null
        }
        Write-Host "  Network staging-network criada" -ForegroundColor Green
    }
    catch {
        Write-Host "  Erro ao criar network: $_" -ForegroundColor Red
        Read-Host
        exit 1
    }
}

Write-Host ""

# Configurar Secrets
Write-Host "3. Configurando secrets..." -ForegroundColor Yellow
$secretsFile = Join-Path $configPath "secrets.json"

if (-not (Test-Path $configPath)) {
    New-Item -Path $configPath -ItemType Directory | Out-Null
    Write-Host "  Pasta config criada" -ForegroundColor Green
}

if (-not (Test-Path $secretsFile)) {
    $template = @{
        github = @{
            token = "github_pat_SEU_TOKEN_AQUI"
            org = "NOME_DA_ORGANIZACAO"
        }
    } | ConvertTo-Json -Depth 10

    Set-Content -Path $secretsFile -Value $template
    Write-Host "  Arquivo secrets.json criado" -ForegroundColor Yellow
    Write-Host "  IMPORTANTE: Edite o arquivo com suas credenciais!" -ForegroundColor Yellow
    Write-Host "  Caminho: $secretsFile" -ForegroundColor White

    $openFile = Read-Host "  Deseja abrir o arquivo agora? (s/N)"
    if ($openFile -eq "s" -or $openFile -eq "S") {
        Start-Process notepad $secretsFile
        Write-Host "  Edite e salve. Pressione Enter quando terminar..." -ForegroundColor Yellow
        Read-Host
    }
}
else {
    Write-Host "  Arquivo secrets.json ja existe" -ForegroundColor Green
}

Write-Host ""

# Ler Credenciais
Write-Host "4. Carregando credenciais..." -ForegroundColor Yellow
try {
    $secrets = Get-Content $secretsFile -Raw | ConvertFrom-Json
    Write-Host "  Arquivo secrets.json carregado" -ForegroundColor Green
}
catch {
    Write-Host "  Erro ao ler secrets.json: $_" -ForegroundColor Red
    Read-Host
    exit 1
}

if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
    if ($secrets.github -and $secrets.github.token) {
        $GitHubToken = $secrets.github.token
        if ($GitHubToken -eq "github_pat_SEU_TOKEN_AQUI") {
            Write-Host "  GitHub Token nao foi configurado!" -ForegroundColor Red
            Read-Host
            exit 1
        }
        Write-Host "  GitHub Token carregado" -ForegroundColor Green
    }
    else {
        Write-Host "  github.token nao encontrado!" -ForegroundColor Red
        Read-Host
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($GitHubOrg)) {
    if ($secrets.github -and $secrets.github.org) {
        $GitHubOrg = $secrets.github.org
        if ($GitHubOrg -eq "NOME_DA_ORGANIZACAO") {
            Write-Host "  GitHub Org nao foi configurada!" -ForegroundColor Red
            Read-Host
            exit 1
        }
        Write-Host "  GitHub Org carregada: $GitHubOrg" -ForegroundColor Green
    }
    else {
        Write-Host "  github.org nao encontrado!" -ForegroundColor Red
        Read-Host
        exit 1
    }
}

Write-Host ""

# Download e Configuracao do Runner
Write-Host "5. Configurando GitHub Runner..." -ForegroundColor Yellow

if (-not (Test-Path $RunnerPath)) {
    New-Item -Path $RunnerPath -ItemType Directory | Out-Null
    Write-Host "  Pasta do runner criada: $RunnerPath" -ForegroundColor Green
}

Set-Location $RunnerPath

$runnerVersion = "2.331.0"
$runnerPackage = "actions-runner-win-x64-$runnerVersion.zip"
$runnerUrl = "https://github.com/actions/runner/releases/download/v$runnerVersion/$runnerPackage"

if (-not (Test-Path ".\run.cmd")) {
    Write-Host "  Baixando GitHub Actions Runner v$runnerVersion..." -ForegroundColor Yellow
    if (Test-Path $runnerPackage) { Remove-Item $runnerPackage -Force }
    try {
        Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerPackage
        Write-Host "  Download concluido" -ForegroundColor Green
        Expand-Archive -Path $runnerPackage -DestinationPath . -Force
        Write-Host "  Arquivos extraidos" -ForegroundColor Green
    }
    catch {
        Write-Host "  Erro ao baixar runner: $_" -ForegroundColor Red
        Read-Host
        exit 1
    }
}
else {
    Write-Host "  Runner ja esta baixado" -ForegroundColor Green
}

# Obter registration token
Write-Host "  Obtendo token de registro..." -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer $GitHubToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    $tokenUrl = "https://api.github.com/orgs/$GitHubOrg/actions/runners/registration-token"
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers $headers
    $registrationToken = $response.token
    Write-Host "  Token de registro obtido" -ForegroundColor Green
}
catch {
    Write-Host "  Erro ao obter token: $_" -ForegroundColor Red
    Read-Host
    exit 1
}

# Configurar runner
if (Test-Path ".\.runner") {
    Write-Host "  Runner ja esta configurado" -ForegroundColor Green
}
else {
    try {
        $configArgs = @(
            "--url", "https://github.com/$GitHubOrg",
            "--token", $registrationToken,
            "--name", $RunnerName,
            "--work", "_work",
            "--labels", "self-hosted,Windows,staging",
            "--unattended"
        )
        & .\config.cmd @configArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Erro na configuracao do runner" -ForegroundColor Red
            Read-Host
            exit 1
        }
        Write-Host "  Runner configurado" -ForegroundColor Green
    }
    catch {
        Write-Host "  Erro ao configurar runner: $_" -ForegroundColor Red
        Read-Host
        exit 1
    }
}

# Verificar se runner esta rodando
$runnerProcess = Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue
$existingService = Get-Service | Where-Object { $_.Name -like "*actions.runner*" }

if ($runnerProcess) {
    Write-Host "  Runner ja esta rodando (PID: $($runnerProcess.Id))" -ForegroundColor Green
}
elseif ($existingService -and $existingService.Status -eq "Running") {
    Write-Host "  Runner ja esta rodando como servico" -ForegroundColor Green
}
else {
    if ($existingService) {
        Write-Host "  Iniciando servico..." -ForegroundColor Yellow
        try {
            Start-Service $existingService.Name -ErrorAction Stop
            Start-Sleep -Seconds 3
            Write-Host "  Servico iniciado" -ForegroundColor Green
        }
        catch {
            Write-Host "  Erro ao iniciar servico" -ForegroundColor Yellow
            sc.exe delete $existingService.Name 2>$null | Out-Null
            $existingService = $null
        }
    }

    if (-not $existingService) {
        Write-Host "  Configurando tarefa agendada..." -ForegroundColor Yellow
        try {
            $taskName = "GitHubActionsRunner-$RunnerName"
            $runCmd = Join-Path $RunnerPath "run.cmd"
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            $action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$runCmd`"" -WorkingDirectory $RunnerPath
            $trigger = New-ScheduledTaskTrigger -AtStartup
            $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 365)
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
            Write-Host "  Tarefa agendada criada: $taskName" -ForegroundColor Green
            Start-ScheduledTask -TaskName $taskName
            Start-Sleep -Seconds 5
            $runnerProcess = Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue
            if ($runnerProcess) {
                Write-Host "  Runner iniciado (PID: $($runnerProcess.Id))" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "  Erro ao configurar tarefa: $_" -ForegroundColor Red
            Write-Host "  Inicie manualmente: cd $RunnerPath; .\run.cmd" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

# Validacao
Write-Host "6. Validando instalacao..." -ForegroundColor Yellow
$runnerProcess = Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue
$networkCheck = docker network ls --filter "name=staging-network" --format "{{.Name}}"

if ($runnerProcess) {
    Write-Host "  Runner rodando (PID: $($runnerProcess.Id))" -ForegroundColor Green
}
else {
    Write-Host "  Runner nao esta rodando" -ForegroundColor Yellow
}

if ($networkCheck) {
    Write-Host "  Docker network staging-network ativa" -ForegroundColor Green
}
else {
    Write-Host "  Docker network nao encontrada!" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SETUP CONCLUIDO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Verifique o runner em:" -ForegroundColor Yellow
Write-Host "  https://github.com/organizations/$GitHubOrg/settings/actions/runners" -ForegroundColor Gray
Write-Host ""
