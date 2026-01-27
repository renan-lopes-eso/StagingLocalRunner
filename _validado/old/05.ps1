# ============================================
# 05 - Setup Caddy Reverse Proxy com HTTPS
# ============================================
# Executa como Administrador
# Instala e configura Caddy como proxy reverso com SSL automatico

param(
    [string]$IP = "10.0.1.34"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Setup Caddy - Reverse Proxy com HTTPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se esta rodando como admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERRO: Execute este script como Administrador!" -ForegroundColor Red
    exit 1
}

# ============================================
# 1. Instalar Caddy via Chocolatey
# ============================================
Write-Host "[1/5] Instalando Caddy..." -ForegroundColor Yellow

if (Get-Command caddy -ErrorAction SilentlyContinue) {
    Write-Host "  Caddy ja esta instalado" -ForegroundColor Green
    caddy version
} else {
    Write-Host "  Instalando via Chocolatey..."
    choco install caddy -y

    # Atualizar PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    if (Get-Command caddy -ErrorAction SilentlyContinue) {
        Write-Host "  Caddy instalado com sucesso!" -ForegroundColor Green
        caddy version
    } else {
        Write-Host "  ERRO: Falha ao instalar Caddy" -ForegroundColor Red
        exit 1
    }
}

# ============================================
# 2. Criar diretorio de configuracao
# ============================================
Write-Host ""
Write-Host "[2/5] Criando diretorio de configuracao..." -ForegroundColor Yellow

$configDir = "C:\configs"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    Write-Host "  Diretorio $configDir criado" -ForegroundColor Green
} else {
    Write-Host "  Diretorio $configDir ja existe" -ForegroundColor Green
}

# ============================================
# 3. Criar Caddyfile
# ============================================
Write-Host ""
Write-Host "[3/5] Criando Caddyfile..." -ForegroundColor Yellow

$caddyfile = @"
# Caddyfile - Reverse Proxy para Staging
# Gerado automaticamente pelo script 05-setup-caddy.ps1

# Configuracao global
{
    # Usar certificados internos (auto-assinados)
    # Para certificados Let's Encrypt, remover esta linha
    local_certs
}

# HTTPS para todos os subdominios do staging
*.$IP.nip.io {
    reverse_proxy localhost:5000 {
        header_up X-Forwarded-Host {host}
        header_up X-Forwarded-Proto {scheme}
    }
    tls internal
}

# Dashboard direto pelo IP
$IP.nip.io {
    reverse_proxy localhost:5000 {
        header_up X-Forwarded-Host {host}
        header_up X-Forwarded-Proto {scheme}
    }
    tls internal
}
"@

$caddyfilePath = Join-Path $configDir "Caddyfile"
$caddyfile | Out-File -FilePath $caddyfilePath -Encoding UTF8 -Force
Write-Host "  Caddyfile criado em $caddyfilePath" -ForegroundColor Green

# ============================================
# 4. Configurar Firewall
# ============================================
Write-Host ""
Write-Host "[4/5] Configurando Firewall..." -ForegroundColor Yellow

$firewallRuleName = "Caddy HTTPS"
$existingRule = Get-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "  Regra de firewall ja existe" -ForegroundColor Green
} else {
    New-NetFirewallRule -DisplayName $firewallRuleName -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow | Out-Null
    Write-Host "  Regra de firewall criada (porta 443)" -ForegroundColor Green
}

# Verificar se porta 80 tambem esta liberada (para redirect)
$httpRuleName = "Caddy HTTP"
$existingHttpRule = Get-NetFirewallRule -DisplayName $httpRuleName -ErrorAction SilentlyContinue

if (-not $existingHttpRule) {
    New-NetFirewallRule -DisplayName $httpRuleName -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow | Out-Null
    Write-Host "  Regra de firewall criada (porta 80)" -ForegroundColor Green
}

# ============================================
# 5. Criar Scheduled Task para iniciar no boot
# ============================================
Write-Host ""
Write-Host "[5/5] Configurando Scheduled Task do Caddy..." -ForegroundColor Yellow

$taskName = "Caddy Reverse Proxy"
$caddyExe = (Get-Command caddy).Source
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

# Verificar se Caddy ja esta rodando
$caddyProcess = Get-Process -Name "caddy" -ErrorAction SilentlyContinue

if ($caddyProcess) {
    Write-Host "  Caddy ja esta rodando (PID: $($caddyProcess.Id))" -ForegroundColor Green
    if (-not $existingTask) {
        Write-Host "  Criando Scheduled Task para iniciar no boot..."
    }
} else {
    Write-Host "  Caddy nao esta rodando"
}

if (-not $existingTask) {
    Write-Host "  Registrando Scheduled Task..."
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    $action = New-ScheduledTaskAction -Execute $caddyExe -Argument "run --config `"$caddyfilePath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 365)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host "  Scheduled Task criada" -ForegroundColor Green
} else {
    Write-Host "  Scheduled Task ja existe" -ForegroundColor Green
}

# Iniciar se nao estiver rodando
if (-not $caddyProcess) {
    Write-Host "  Iniciando Caddy..."
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 1
    $caddyProcess = Get-Process -Name "caddy" -ErrorAction SilentlyContinue
    if ($caddyProcess) {
        Write-Host "  Caddy iniciado (PID: $($caddyProcess.Id))" -ForegroundColor Green
    } else {
        Write-Host "  Falha ao iniciar. Execute: caddy run --config $caddyfilePath" -ForegroundColor Red
    }
}

# ============================================
# Resumo
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Setup Concluido!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Caddy esta rodando como servico Windows" -ForegroundColor Green
Write-Host ""
Write-Host "URLs de acesso:" -ForegroundColor Yellow
Write-Host "  Dashboard:  https://$IP.nip.io" -ForegroundColor White
Write-Host "  Containers: https://{nome-container}.$IP.nip.io" -ForegroundColor White
Write-Host ""
Write-Host "Exemplos:" -ForegroundColor Yellow
Write-Host "  https://eso-core-staging-test.$IP.nip.io" -ForegroundColor White
Write-Host "  https://eso-portal-staging-test.$IP.nip.io" -ForegroundColor White
Write-Host ""
Write-Host "Comandos uteis:" -ForegroundColor Yellow
Write-Host "  Ver processo:  Get-Process caddy" -ForegroundColor White
Write-Host "  Ver task:      Get-ScheduledTask 'Caddy Reverse Proxy'" -ForegroundColor White
Write-Host "  Parar:         Stop-Process -Name caddy" -ForegroundColor White
Write-Host "  Iniciar:       Start-ScheduledTask 'Caddy Reverse Proxy'" -ForegroundColor White
Write-Host "  Recarregar:    caddy reload --config C:\configs\Caddyfile" -ForegroundColor White
Write-Host "  Testar config: caddy validate --config C:\configs\Caddyfile" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANTE: Adicione UseForwardedHeaders no Program.cs do Core:" -ForegroundColor Yellow
Write-Host '  app.UseForwardedHeaders(new ForwardedHeadersOptions' -ForegroundColor Gray
Write-Host '  {' -ForegroundColor Gray
Write-Host '      ForwardedHeaders = ForwardedHeaders.XForwardedProto' -ForegroundColor Gray
Write-Host '  });' -ForegroundColor Gray
Write-Host ""
