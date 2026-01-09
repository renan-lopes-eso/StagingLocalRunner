<#
.SYNOPSIS
    Configura acesso remoto via RDP na máquina de staging

.DESCRIPTION
    Este script:
    - Habilita Remote Desktop
    - Configura firewall para permitir RDP
    - Mostra o IP da máquina
    - Testa se o RDP está funcionando
    - Fornece instruções de conexão

.EXAMPLE
    .\setup-rdp.ps1
#>

param(
    [switch]$DisableNLA = $false  # Desabilitar Network Level Authentication (menos seguro, mas facilita conexão)
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Setup de Acesso Remoto RDP" -ForegroundColor Cyan
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

Write-Host "[1/5] Habilitando Remote Desktop..." -ForegroundColor Yellow

try {
    # Habilitar Remote Desktop
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Write-Host "  ✓ Remote Desktop habilitado com sucesso" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Erro ao habilitar Remote Desktop: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2/5] Configurando Firewall..." -ForegroundColor Yellow

try {
    # Tentar habilitar por DisplayGroup (inglês)
    $rules = Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

    if (-not $rules) {
        # Tentar em português
        $rules = Get-NetFirewallRule -DisplayGroup "Área de Trabalho Remota" -ErrorAction SilentlyContinue
    }

    if (-not $rules) {
        # Tentar em português alternativo
        $rules = Get-NetFirewallRule -DisplayGroup "*Remot*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Desktop*" -or $_.DisplayName -like "*Trabalho*" }
    }

    if ($rules) {
        # Habilitar as regras encontradas
        $rules | Enable-NetFirewallRule -ErrorAction Stop
        Write-Host "  ✓ Regras de firewall configuradas ($($rules.Count) regras)" -ForegroundColor Green
    }
    else {
        # Fallback: habilitar por nomes específicos de regras RDP
        Write-Host "  ! DisplayGroup nao encontrado, usando metodo alternativo..." -ForegroundColor Yellow

        # Habilitar regras específicas do RDP (funciona em qualquer idioma)
        netsh advfirewall firewall set rule group="remote desktop" new enable=Yes 2>$null

        # Também tentar em português
        netsh advfirewall firewall set rule group="área de trabalho remota" new enable=Yes 2>$null

        # Criar regra manualmente se necessário
        $existingRule = Get-NetFirewallRule -Name "RDP-Custom" -ErrorAction SilentlyContinue
        if (-not $existingRule) {
            New-NetFirewallRule -Name "RDP-Custom" `
                -DisplayName "Remote Desktop - Custom" `
                -Description "Allow RDP connections" `
                -Protocol TCP `
                -LocalPort 3389 `
                -Direction Inbound `
                -Action Allow `
                -Enabled True `
                -ErrorAction Stop | Out-Null
            Write-Host "  ✓ Regra de firewall customizada criada" -ForegroundColor Green
        }
        else {
            Enable-NetFirewallRule -Name "RDP-Custom" -ErrorAction Stop
            Write-Host "  ✓ Regra de firewall customizada habilitada" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "  ✗ Erro ao configurar firewall: $_" -ForegroundColor Red
    Write-Host "  Tentando metodo alternativo..." -ForegroundColor Yellow

    # Último recurso: desabilitar firewall temporariamente (não recomendado)
    Write-Host "  ! Se estiver em rede segura, voce pode desabilitar o firewall temporariamente:" -ForegroundColor Yellow
    Write-Host "    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False" -ForegroundColor White
    Write-Host "  ! Ou configurar manualmente no Windows Defender Firewall" -ForegroundColor Yellow
}

# Opcional: Desabilitar NLA (Network Level Authentication)
if ($DisableNLA) {
    Write-Host ""
    Write-Host "[OPCIONAL] Desabilitando Network Level Authentication..." -ForegroundColor Yellow
    try {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0
        Write-Host "  ✓ NLA desabilitado (menos seguro, mas facilita conexao)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ! Aviso: Nao foi possivel desabilitar NLA" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[3/5] Descobrindo informacoes da maquina..." -ForegroundColor Yellow

# Obter hostname
$hostname = $env:COMPUTERNAME
Write-Host "  Hostname: $hostname" -ForegroundColor Cyan

# Obter usuário atual
$currentUser = $env:USERNAME
Write-Host "  Usuario atual: $currentUser" -ForegroundColor Cyan

# Obter IPs da máquina
$ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -notlike "127.*" -and
    $_.IPAddress -notlike "169.254.*" -and
    ($_.IPAddress -like "192.168.*" -or $_.IPAddress -like "10.*" -or $_.IPAddress -like "172.*")
} | Select-Object IPAddress, InterfaceAlias

if ($ips) {
    Write-Host "  IPs disponiveis:" -ForegroundColor Cyan
    foreach ($ip in $ips) {
        Write-Host "    - $($ip.IPAddress) ($($ip.InterfaceAlias))" -ForegroundColor White
    }

    # Usar o primeiro IP como principal
    $mainIP = $ips[0].IPAddress
}
else {
    Write-Host "  ✗ Nenhum IP de rede local encontrado!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[4/5] Testando servico RDP..." -ForegroundColor Yellow

# Verificar se o serviço TermService está rodando
$rdpService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue

if ($rdpService -and $rdpService.Status -eq "Running") {
    Write-Host "  ✓ Servico Remote Desktop esta rodando" -ForegroundColor Green
}
else {
    Write-Host "  ! Servico Remote Desktop nao esta rodando, iniciando..." -ForegroundColor Yellow
    try {
        Start-Service -Name "TermService" -ErrorAction Stop
        Set-Service -Name "TermService" -StartupType Automatic
        Write-Host "  ✓ Servico Remote Desktop iniciado" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Erro ao iniciar servico: $_" -ForegroundColor Red
    }
}

# Testar se a porta 3389 está escutando
Start-Sleep -Seconds 2
$listening = Get-NetTCPConnection -LocalPort 3389 -State Listen -ErrorAction SilentlyContinue

if ($listening) {
    Write-Host "  ✓ Porta 3389 (RDP) esta escutando" -ForegroundColor Green
}
else {
    Write-Host "  ✗ Porta 3389 nao esta escutando!" -ForegroundColor Red
}

Write-Host ""
Write-Host "[5/5] Configuracao de usuarios..." -ForegroundColor Yellow

# Verificar se há usuários com permissão RDP
try {
    $rdpUsers = Get-LocalGroupMember -Group "Remote Desktop Users" -ErrorAction SilentlyContinue
    if ($rdpUsers) {
        Write-Host "  Usuarios com permissao RDP:" -ForegroundColor Cyan
        foreach ($user in $rdpUsers) {
            Write-Host "    - $($user.Name)" -ForegroundColor White
        }
    }
    else {
        Write-Host "  ! Nenhum usuario no grupo 'Remote Desktop Users'" -ForegroundColor Yellow
        Write-Host "  ! Apenas Administradores podem conectar" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ! Nao foi possivel verificar usuarios RDP" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   ✓ CONFIGURACAO CONCLUIDA!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "COMO CONECTAR DA MAQUINA LOCAL:" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "Opcao 1 - Via comando:" -ForegroundColor Yellow
Write-Host "  mstsc /v:$mainIP" -ForegroundColor White
Write-Host ""
Write-Host "Opcao 2 - Via GUI:" -ForegroundColor Yellow
Write-Host "  1. Pressione Win + R" -ForegroundColor White
Write-Host "  2. Digite: mstsc" -ForegroundColor White
Write-Host "  3. Insira o IP: $mainIP" -ForegroundColor White
Write-Host "  4. Usuario: $hostname\$currentUser (ou apenas: $currentUser)" -ForegroundColor White
Write-Host ""
Write-Host "Opcao 3 - Por hostname (se DNS local funcionar):" -ForegroundColor Yellow
Write-Host "  mstsc /v:$hostname" -ForegroundColor White
Write-Host ""

Write-Host "TESTE DE CONECTIVIDADE:" -ForegroundColor Cyan
Write-Host "-----------------------" -ForegroundColor Cyan
Write-Host "Da sua maquina local, execute:" -ForegroundColor White
Write-Host "  Test-NetConnection -ComputerName $mainIP -Port 3389" -ForegroundColor White
Write-Host ""

Write-Host "INFORMACOES IMPORTANTES:" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Cyan
Write-Host "  IP Principal: $mainIP" -ForegroundColor Green
Write-Host "  Hostname: $hostname" -ForegroundColor Green
Write-Host "  Porta RDP: 3389" -ForegroundColor Green
Write-Host "  Usuario: $currentUser" -ForegroundColor Green
Write-Host ""

if (-not $DisableNLA) {
    Write-Host "NOTA: Network Level Authentication (NLA) esta HABILITADO" -ForegroundColor Yellow
    Write-Host "Se tiver problemas para conectar, execute:" -ForegroundColor Yellow
    Write-Host "  .\setup-rdp.ps1 -DisableNLA" -ForegroundColor White
    Write-Host ""
}

Write-Host "SEGURANCA:" -ForegroundColor Cyan
Write-Host "----------" -ForegroundColor Cyan
Write-Host "- Use senha forte no usuario Windows" -ForegroundColor White
Write-Host "- Considere configurar IP fixo no UniFi Controller" -ForegroundColor White
Write-Host "- Apenas use em rede confiavel (como sua rede local)" -ForegroundColor White
Write-Host ""

# Salvar informações em arquivo
$infoFile = "rdp-connection-info.txt"
$infoContent = @"
========================================
  INFORMACOES DE CONEXAO RDP
========================================

Data/Hora: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

IP Principal: $mainIP
Hostname: $hostname
Usuario: $currentUser
Porta: 3389

COMANDO DE CONEXAO:
  mstsc /v:$mainIP

TESTE DE CONECTIVIDADE:
  Test-NetConnection -ComputerName $mainIP -Port 3389

TODOS OS IPS DISPONIVEIS:
$($ips | ForEach-Object { "  - $($_.IPAddress) ($($_.InterfaceAlias))" } | Out-String)
========================================
"@

try {
    $infoContent | Out-File -FilePath $infoFile -Encoding UTF8
    Write-Host "Informacoes salvas em: $infoFile" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "Nao foi possivel salvar arquivo de informacoes" -ForegroundColor Yellow
}

Write-Host "Pressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
