<#
.SYNOPSIS
    Testa conectividade RDP com a máquina de staging

.DESCRIPTION
    Execute este script na sua MÁQUINA LOCAL para testar se consegue
    acessar a máquina de staging via RDP

.PARAMETER Target
    IP ou hostname da máquina de staging

.EXAMPLE
    .\test-rdp-connection.ps1 -Target 192.168.1.100

.EXAMPLE
    .\test-rdp-connection.ps1 -Target staging-server
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Target
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Teste de Conectividade RDP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Testando conexao com: $Target" -ForegroundColor Yellow
Write-Host ""

# Teste 1: Ping básico
Write-Host "[1/3] Testando conectividade basica (ICMP)..." -ForegroundColor Yellow

try {
    $pingResult = Test-Connection -ComputerName $Target -Count 2 -ErrorAction Stop
    $avgLatency = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
    Write-Host "  ✓ Maquina esta acessivel" -ForegroundColor Green
    Write-Host "  Latencia media: $([math]::Round($avgLatency, 2)) ms" -ForegroundColor Cyan
}
catch {
    Write-Host "  ✗ Nao foi possivel fazer ping na maquina" -ForegroundColor Red
    Write-Host "  Isso pode ser normal se ICMP estiver bloqueado" -ForegroundColor Yellow
}

Write-Host ""

# Teste 2: Porta RDP (3389)
Write-Host "[2/3] Testando porta RDP (3389)..." -ForegroundColor Yellow

try {
    $rdpTest = Test-NetConnection -ComputerName $Target -Port 3389 -WarningAction SilentlyContinue

    if ($rdpTest.TcpTestSucceeded) {
        Write-Host "  ✓ Porta 3389 esta aberta e acessivel!" -ForegroundColor Green
        Write-Host "  IP Remoto: $($rdpTest.RemoteAddress)" -ForegroundColor Cyan

        if ($rdpTest.PingSucceeded) {
            Write-Host "  Ping: OK ($($rdpTest.PingReplyDetails.RoundtripTime) ms)" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "  ✗ Porta 3389 NAO esta acessivel!" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Possiveis causas:" -ForegroundColor Yellow
        Write-Host "    - RDP nao esta habilitado na maquina de staging" -ForegroundColor White
        Write-Host "    - Firewall bloqueando a porta 3389" -ForegroundColor White
        Write-Host "    - IP/hostname incorreto" -ForegroundColor White
        Write-Host ""
        Write-Host "  Execute na maquina de staging:" -ForegroundColor Yellow
        Write-Host "    .\scripts\setup-rdp.ps1" -ForegroundColor White
        exit 1
    }
}
catch {
    Write-Host "  ✗ Erro ao testar porta: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Teste 3: Resolução de nome (se não for IP)
Write-Host "[3/3] Informacoes adicionais..." -ForegroundColor Yellow

# Verificar se é um IP ou hostname
if ($Target -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
    Write-Host "  Tipo: Endereco IP" -ForegroundColor Cyan

    # Tentar resolver o hostname reverso
    try {
        $hostEntry = [System.Net.Dns]::GetHostEntry($Target)
        Write-Host "  Hostname: $($hostEntry.HostName)" -ForegroundColor Cyan
    }
    catch {
        Write-Host "  Hostname: Nao foi possivel resolver" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  Tipo: Hostname" -ForegroundColor Cyan

    # Tentar resolver para IP
    try {
        $ipAddresses = [System.Net.Dns]::GetHostAddresses($Target)
        Write-Host "  IPs resolvidos:" -ForegroundColor Cyan
        foreach ($ip in $ipAddresses) {
            Write-Host "    - $($ip.IPAddressToString)" -ForegroundColor White
        }
    }
    catch {
        Write-Host "  ✗ Nao foi possivel resolver hostname!" -ForegroundColor Red
        Write-Host "  Use o IP diretamente" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   ✓ TESTE CONCLUIDO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "PROXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host "----------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Conectar via RDP:" -ForegroundColor Yellow
Write-Host "   mstsc /v:$Target" -ForegroundColor White
Write-Host ""
Write-Host "2. Ou abrir Remote Desktop Connection:" -ForegroundColor Yellow
Write-Host "   - Pressione Win + R" -ForegroundColor White
Write-Host "   - Digite: mstsc" -ForegroundColor White
Write-Host "   - Insira: $Target" -ForegroundColor White
Write-Host ""
Write-Host "3. Faca login com as credenciais da maquina de staging" -ForegroundColor Yellow
Write-Host ""

Write-Host "DICA: Para criar um atalho de conexao rapida:" -ForegroundColor Cyan
Write-Host "  cmdkey /generic:$Target /user:USUARIO /pass:SENHA" -ForegroundColor White
Write-Host "  mstsc /v:$Target" -ForegroundColor White
Write-Host ""
