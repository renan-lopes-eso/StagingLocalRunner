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
    [string]$RunnerPath = "C:\configs\runner"
)
$configPath = "C:\configs"

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
	Read-Host
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
	Read-Host
    exit 1
}

# Verificar se Docker está rodando
 Write-Host "  Verificando se Docker esta rodando..." -ForegroundColor White
 $dockerRunning = $false
 try {
     $result = docker ps 2>&1
     if ($LASTEXITCODE -eq 0) {
         $dockerRunning = $true
     }
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
	 Read-Host
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
		Read-Host
        exit 1
    }
}

Write-Host ""

# ====================================
# Configurar Secrets
# ====================================
# Criar secrets.json se não existir
Write-Host "3. Configurando secrets..." -ForegroundColor Yellow

$secretsFile = Join-Path $configPath "secrets.json"

if (-not (Test-Path $configPath)) {
    New-Item -Path $configPath -ItemType Directory | Out-Null
    Write-Host "  ✓ Pasta config/ criada" -ForegroundColor Green
}

# Criar secrets.json se não existir
if (-not (Test-Path $secretsFile)) {
    $template = @{
        github = @{ 
			token = "github_token"
			repo = "repo_url" 
		}
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

# ====================================
# Ler Credenciais do secrets.json
# ====================================
Write-Host "4. Carregando credenciais..." -ForegroundColor Yellow

try {
  $secrets = Get-Content $secretsFile -Raw | ConvertFrom-Json
  Write-Host "  ✓ Arquivo secrets.json carregado" -ForegroundColor Green
}
catch {
  Write-Host "  ✗ Erro ao ler secrets.json: $_" -ForegroundColor Red
  Write-Host "  ! Verifique se o arquivo esta no formato JSON valido" -ForegroundColor Yellow
  Read-Host
  exit 1
}

# Verificar se github.token existe e está preenchido
if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
  if ($secrets.github -and $secrets.github.token) {
	  $GitHubToken = $secrets.github.token

	  # Validar se não é o valor de exemplo
	  if ($GitHubToken -eq "ghp_YOUR_GITHUB_TOKEN_HERE") {
		  Write-Host "  ✗ GitHub Token nao foi configurado no secrets.json!" -ForegroundColor Red
		  Write-Host ""
		  Read-Host
		  exit 1
	  }

	  Write-Host "  ✓ GitHub Token carregado do secrets.json" -ForegroundColor Green
  }
  else {
	  Write-Host "  ✗ github.token nao encontrado no secrets.json!" -ForegroundColor Red
	  Write-Host ""
	  Read-Host
	  exit 1
  }
}

# Verificar se github.repo existe e está preenchido
if ([string]::IsNullOrWhiteSpace($GitHubRepo)) {
  if ($secrets.github -and $secrets.github.repo) {
	  $GitHubRepo = $secrets.github.repo

	  # Validar se não é o valor de exemplo
	  if ($GitHubRepo -eq "owner/repository") {
		  Write-Host "  ✗ GitHub Repositorio nao foi configurado no secrets.json!" -ForegroundColor Red
		  Write-Host ""
		  Write-Host "  Edite o arquivo: $secretsFile" -ForegroundColor Yellow
		  Write-Host "  Configure: github.repo no formato 'owner/repository'" -ForegroundColor Yellow
		  Write-Host "  Exemplo: 'meuusuario/StagingLocalRunner'" -ForegroundColor Gray
		  Write-Host ""
		  Read-Host
		  exit 1
	  }

	  Write-Host "  ✓ GitHub Repositorio carregado: $GitHubRepo" -ForegroundColor Green
  }
  else {
	  Write-Host "  ✗ github.repo nao encontrado no secrets.json!" -ForegroundColor Red
	  Write-Host ""
	  Write-Host "  Edite o arquivo: $secretsFile" -ForegroundColor Yellow
	  Write-Host "  Adicione: github.repo no formato 'owner/repository'" -ForegroundColor Yellow
	  Read-Host
	  exit 1
  }
}

Write-Host ""
Write-Host "  Configuracao carregada:" -ForegroundColor Green
Write-Host "    Repositorio: $GitHubRepo" -ForegroundColor White
Write-Host "    Runner Name: $RunnerName" -ForegroundColor White
Write-Host "    Runner Path: $RunnerPath" -ForegroundColor White
Write-Host ""

# ====================================
# Download e Configuração do Runner
# ====================================
Write-Host "5. Configurando GitHub Runner..." -ForegroundColor Yellow

# Criar diretório do runner
if (-not (Test-Path $RunnerPath)) {
  New-Item -Path $RunnerPath -ItemType Directory | Out-Null
  Write-Host "  ✓ Pasta do runner criada: $RunnerPath" -ForegroundColor Green
}

Set-Location $RunnerPath

# Verificação removida - o script continua e verifica .runner mais adiante

# Download do runner
$runnerVersion = "2.331.0"
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
	  Write-Host "  ! URL: $runnerUrl" -ForegroundColor Yellow
	  Read-Host
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
	  "Authorization" = "Bearer $GitHubToken"
	  "Accept" = "application/vnd.github.v3+json"
  }
  $tokenUrl = "https://api.github.com/repos/$GitHubRepo/actions/runners/registration-token"
  $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers $headers
  $registrationToken = $response.token
  Write-Host "  ✓ Token de registro obtido" -ForegroundColor Green
}
catch {
  Write-Host "  ✗ Erro ao obter token de registro: $_" -ForegroundColor Red
  Write-Host "  ! Verifique se o GitHub Token e Repositorio estao corretos no secrets.json" -ForegroundColor Yellow
  Write-Host "  ! Token deve ter permissoes: repo, workflow, admin:org" -ForegroundColor Yellow
  Read-Host
  exit 1
}

# Configurar runner
Write-Host "  Configurando runner..." -ForegroundColor Yellow

# Verificar se já está configurado
if (Test-Path ".\.runner") {
  Write-Host "  ✓ Runner ja esta configurado" -ForegroundColor Green
  Write-Host "  ! Para reconfigurar, execute primeiro: .\config.cmd remove" -ForegroundColor Yellow
}
else {
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
		  Write-Host "  ✗ Erro na configuracao do runner" -ForegroundColor Red
		  Write-Host "  ! Verifique os logs acima para mais detalhes" -ForegroundColor Yellow
		  Read-Host "  Pressione Enter para sair"
		  exit 1
	  }

	  Write-Host "  ✓ Runner configurado com sucesso" -ForegroundColor Green
  }
  catch {
	  Write-Host "  ✗ Erro ao configurar runner: $_" -ForegroundColor Red
	  Read-Host "  Pressione Enter para sair"
	  exit 1
  }
}

# Verificar se runner já está rodando (processo ou serviço)
$runnerProcess = Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue
$existingService = Get-Service | Where-Object {$_.Name -like "*actions.runner*"}

if ($runnerProcess) {
  # Runner já está rodando como processo
  Write-Host "  ✓ Runner ja esta rodando (processo ativo)" -ForegroundColor Green
  Write-Host "    PID: $($runnerProcess.Id)" -ForegroundColor Gray
}
elseif ($existingService -and $existingService.Status -eq "Running") {
  # Runner já está rodando como serviço
  Write-Host "  ✓ Runner ja esta rodando como servico" -ForegroundColor Green
  Write-Host "    Servico: $($existingService.Name)" -ForegroundColor Gray
}
else {
  # Runner não está rodando - tentar iniciar ou instalar

  if ($existingService) {
    # Serviço existe mas não está rodando - tentar iniciar
    Write-Host "  ! Servico existe mas nao esta rodando" -ForegroundColor Yellow
    Write-Host "  Iniciando servico..." -ForegroundColor Yellow

    $serviceStarted = $false
    try {
      Start-Service $existingService.Name -ErrorAction Stop
      Start-Sleep -Seconds 3
      Write-Host "  ✓ Servico iniciado" -ForegroundColor Green
      $serviceStarted = $true
    }
    catch {
      Write-Host "  ✗ Erro ao iniciar servico - removendo servico quebrado..." -ForegroundColor Yellow
      # Remover serviço quebrado
      try {
        sc.exe delete $existingService.Name 2>$null | Out-Null
        Write-Host "  ✓ Servico removido" -ForegroundColor Green
      }
      catch {
        # Ignorar
      }
    }

    # Se serviço não iniciou, usar tarefa agendada
    if (-not $serviceStarted) {
      $existingService = $null  # Forçar criação de tarefa agendada no próximo bloco
    }
  }

  if (-not $existingService) {
    # Serviço não existe - criar tarefa agendada
    Write-Host "  Configurando inicializacao automatica..." -ForegroundColor Yellow

    try {
      $taskName = "GitHubActionsRunner-$RunnerName"
      $runCmd = Join-Path $RunnerPath "run.cmd"

      # Remover tarefa existente se houver
      Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

      # Criar tarefa agendada para iniciar no boot
      $action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$runCmd`"" -WorkingDirectory $RunnerPath
      $trigger = New-ScheduledTaskTrigger -AtStartup
      $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
      $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 365)

      Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

      Write-Host "  ✓ Tarefa agendada criada: $taskName" -ForegroundColor Green

      # Iniciar a tarefa agora
      Write-Host "  Iniciando runner..." -ForegroundColor Yellow
      Start-ScheduledTask -TaskName $taskName
      Start-Sleep -Seconds 5

      # Verificar se iniciou
      $runnerProcess = Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue
      if ($runnerProcess) {
        Write-Host "  ✓ Runner iniciado com sucesso (PID: $($runnerProcess.Id))" -ForegroundColor Green
      }
      else {
        Write-Host "  ! Runner pode demorar alguns segundos para conectar ao GitHub" -ForegroundColor Yellow
      }
    }
    catch {
      Write-Host "  ✗ Erro ao configurar tarefa: $_" -ForegroundColor Red
      Write-Host ""
      Write-Host "  Voce pode iniciar o runner manualmente com:" -ForegroundColor Yellow
      Write-Host "    cd $RunnerPath" -ForegroundColor Gray
      Write-Host "    .\run.cmd" -ForegroundColor Gray
    }
  }
}

Write-Host ""

# ====================================
# Validação
# ====================================
Write-Host "6. Validando instalacao..." -ForegroundColor Yellow

# Verificar se runner está rodando (processo ou serviço)
$runnerProcess = Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue
$service = Get-Service | Where-Object {$_.Name -like "*actions.runner*"}
$scheduledTask = Get-ScheduledTask -TaskName "GitHubActionsRunner-$RunnerName" -ErrorAction SilentlyContinue

if ($runnerProcess) {
  Write-Host "  ✓ Runner esta rodando (PID: $($runnerProcess.Id))" -ForegroundColor Green
}
elseif ($service -and $service.Status -eq "Running") {
  Write-Host "  ✓ Runner esta rodando como servico" -ForegroundColor Green
}
else {
  Write-Host "  ! Runner nao esta rodando no momento" -ForegroundColor Yellow
  if ($scheduledTask) {
    Write-Host "    Tarefa agendada configurada: $($scheduledTask.TaskName)" -ForegroundColor Gray
    Write-Host "    O runner iniciara automaticamente no proximo boot" -ForegroundColor Gray
  }
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
Write-Host "     (a mesma que esta em C:\configs\secrets.json)" -ForegroundColor Gray
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
Write-Host "    Get-Process -Name Runner.Listener" -ForegroundColor Gray
Write-Host ""
Write-Host "  Ver logs do runner:" -ForegroundColor White
Write-Host "    Get-Content $RunnerPath\_diag\*.log -Tail 50" -ForegroundColor Gray
Write-Host ""
Write-Host "  Iniciar runner manualmente:" -ForegroundColor White
Write-Host "    cd $RunnerPath; .\run.cmd" -ForegroundColor Gray
Write-Host ""
Write-Host "  Parar runner:" -ForegroundColor White
Write-Host "    Stop-Process -Name Runner.Listener -Force" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan