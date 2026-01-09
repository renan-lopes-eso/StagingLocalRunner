Write-Host ""
Write-Host "[1/3] Descobrindo informacoes da maquina..." -ForegroundColor Yellow

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
}

Write-Host ""
Write-Host "[2/3] Testando servico RDP..." -ForegroundColor Yellow

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
Write-Host "[3/3] Configuracao de usuarios..." -ForegroundColor Yellow

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

Write-Host "COMO CONECTAR DA MAQUINA LOCAL:" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Cyan
Write-Host "Via GUI:" -ForegroundColor Yellow
Write-Host "  1. Pressione Win + R" -ForegroundColor White
Write-Host "  2. Digite: mstsc" -ForegroundColor White
Write-Host "  3. Insira o IP: $mainIP:3389" -ForegroundColor White
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

Write-Host "Pressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")