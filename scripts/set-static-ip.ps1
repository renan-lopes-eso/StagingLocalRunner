<#
.SYNOPSIS
    Configura IP estático na máquina Windows

.DESCRIPTION
    Este script configura um IP estático na interface de rede especificada.
    ATENÇÃO: Execute este script na máquina de staging, não remotamente!

.PARAMETER IPAddress
    O IP estático que você quer configurar (ex: 192.168.1.100)

.PARAMETER SubnetMask
    Máscara de sub-rede (padrão: 255.255.255.0 = /24)

.PARAMETER Gateway
    Gateway padrão (normalmente o IP do roteador UniFi)

.PARAMETER DNS
    Servidores DNS (padrão: usa o gateway como DNS)

.PARAMETER InterfaceAlias
    Nome da interface de rede (deixe vazio para escolher interativamente)

.EXAMPLE
    .\set-static-ip.ps1 -IPAddress 192.168.1.100 -Gateway 192.168.1.1

.EXAMPLE
    .\set-static-ip.ps1 -IPAddress 192.168.1.100 -Gateway 192.168.1.1 -DNS "8.8.8.8","8.8.4.4"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$IPAddress,

    [Parameter(Mandatory=$false)]
    [int]$PrefixLength = 24,  # Equivalente a 255.255.255.0

    [Parameter(Mandatory=$false)]
    [string]$Gateway,

    [Parameter(Mandatory=$false)]
    [string[]]$DNS,

    [Parameter(Mandatory=$false)]
    [string]$InterfaceAlias
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Configurar IP Estatico" -ForegroundColor Cyan
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

# Listar interfaces de rede ativas
Write-Host "Interfaces de rede disponiveis:" -ForegroundColor Yellow
Write-Host ""

$interfaces = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

if ($interfaces.Count -eq 0) {
    Write-Host "ERRO: Nenhuma interface de rede ativa encontrada!" -ForegroundColor Red
    exit 1
}

$index = 1
foreach ($iface in $interfaces) {
    $ipConfig = Get-NetIPAddress -InterfaceIndex $iface.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $currentIP = if ($ipConfig) { $ipConfig.IPAddress } else { "Nenhum IP" }

    Write-Host "  [$index] $($iface.Name) ($($iface.InterfaceDescription))" -ForegroundColor Cyan
    Write-Host "      Status: $($iface.Status)" -ForegroundColor White
    Write-Host "      IP Atual: $currentIP" -ForegroundColor White
    Write-Host "      MAC: $($iface.MacAddress)" -ForegroundColor White
    Write-Host ""
    $index++
}

# Selecionar interface
if (-not $InterfaceAlias) {
    Write-Host "Selecione a interface de rede (1-$($interfaces.Count)): " -ForegroundColor Yellow -NoNewline
    $selection = Read-Host

    if (-not $selection -or $selection -lt 1 -or $selection -gt $interfaces.Count) {
        Write-Host "Selecao invalida!" -ForegroundColor Red
        exit 1
    }

    $selectedInterface = $interfaces[$selection - 1]
}
else {
    $selectedInterface = Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue
    if (-not $selectedInterface) {
        Write-Host "Interface '$InterfaceAlias' nao encontrada!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Interface selecionada: $($selectedInterface.Name)" -ForegroundColor Green
Write-Host ""

# Obter configuração atual
$currentIPConfig = Get-NetIPAddress -InterfaceIndex $selectedInterface.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
$currentGateway = Get-NetRoute -InterfaceIndex $selectedInterface.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
$currentDNS = Get-DnsClientServerAddress -InterfaceIndex $selectedInterface.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue

Write-Host "Configuracao atual:" -ForegroundColor Yellow
if ($currentIPConfig) {
    Write-Host "  IP: $($currentIPConfig.IPAddress)/$($currentIPConfig.PrefixLength)" -ForegroundColor White
}
if ($currentGateway) {
    Write-Host "  Gateway: $($currentGateway.NextHop)" -ForegroundColor White
}
if ($currentDNS -and $currentDNS.ServerAddresses) {
    Write-Host "  DNS: $($currentDNS.ServerAddresses -join ', ')" -ForegroundColor White
}
Write-Host ""

# Solicitar configurações se não foram fornecidas
if (-not $IPAddress) {
    Write-Host "Digite o IP estatico desejado (ex: 192.168.1.100): " -ForegroundColor Yellow -NoNewline
    $IPAddress = Read-Host
}

if (-not $Gateway) {
    # Tentar sugerir o gateway atual
    $suggestedGateway = if ($currentGateway) { $currentGateway.NextHop } else { "" }

    if ($suggestedGateway) {
        Write-Host "Gateway padrao (Enter para usar $suggestedGateway): " -ForegroundColor Yellow -NoNewline
        $inputGateway = Read-Host
        $Gateway = if ($inputGateway) { $inputGateway } else { $suggestedGateway }
    }
    else {
        Write-Host "Gateway padrao (ex: 192.168.1.1): " -ForegroundColor Yellow -NoNewline
        $Gateway = Read-Host
    }
}

if (-not $DNS) {
    Write-Host "Usar o gateway como DNS? (S/n): " -ForegroundColor Yellow -NoNewline
    $useDNS = Read-Host

    if ($useDNS -eq "" -or $useDNS -eq "S" -or $useDNS -eq "s") {
        $DNS = @($Gateway)
    }
    else {
        Write-Host "Servidores DNS separados por virgula (ex: 8.8.8.8,8.8.4.4): " -ForegroundColor Yellow -NoNewline
        $dnsInput = Read-Host
        $DNS = $dnsInput -split "," | ForEach-Object { $_.Trim() }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Resumo da configuracao:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Interface: $($selectedInterface.Name)" -ForegroundColor White
Write-Host "IP: $IPAddress/$PrefixLength" -ForegroundColor White
Write-Host "Gateway: $Gateway" -ForegroundColor White
Write-Host "DNS: $($DNS -join ', ')" -ForegroundColor White
Write-Host ""

Write-Host "ATENCAO: Isso vai alterar as configuracoes de rede!" -ForegroundColor Yellow
Write-Host "Continuar? (S/n): " -ForegroundColor Yellow -NoNewline
$confirm = Read-Host

if ($confirm -ne "" -and $confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Operacao cancelada." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Aplicando configuracoes..." -ForegroundColor Yellow
Write-Host ""

try {
    # Remover configuração DHCP existente
    Write-Host "[1/4] Removendo configuracao DHCP..." -ForegroundColor Yellow

    if ($currentIPConfig) {
        Remove-NetIPAddress -InterfaceIndex $selectedInterface.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    }

    if ($currentGateway) {
        Remove-NetRoute -InterfaceIndex $selectedInterface.ifIndex -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
    }

    Write-Host "  ✓ Configuracao antiga removida" -ForegroundColor Green

    # Configurar IP estático
    Write-Host ""
    Write-Host "[2/4] Configurando IP estatico..." -ForegroundColor Yellow

    New-NetIPAddress -InterfaceIndex $selectedInterface.ifIndex `
        -IPAddress $IPAddress `
        -PrefixLength $PrefixLength `
        -DefaultGateway $Gateway `
        -ErrorAction Stop | Out-Null

    Write-Host "  ✓ IP estatico configurado: $IPAddress/$PrefixLength" -ForegroundColor Green

    # Configurar DNS
    Write-Host ""
    Write-Host "[3/4] Configurando servidores DNS..." -ForegroundColor Yellow

    Set-DnsClientServerAddress -InterfaceIndex $selectedInterface.ifIndex `
        -ServerAddresses $DNS `
        -ErrorAction Stop

    Write-Host "  ✓ DNS configurado: $($DNS -join ', ')" -ForegroundColor Green

    # Testar conectividade
    Write-Host ""
    Write-Host "[4/4] Testando conectividade..." -ForegroundColor Yellow

    Start-Sleep -Seconds 2

    # Testar gateway
    $gatewayTest = Test-Connection -ComputerName $Gateway -Count 1 -ErrorAction SilentlyContinue
    if ($gatewayTest) {
        Write-Host "  ✓ Gateway acessivel" -ForegroundColor Green
    }
    else {
        Write-Host "  ! Gateway nao responde (pode ser normal se ICMP bloqueado)" -ForegroundColor Yellow
    }

    # Testar DNS
    $dnsTest = Resolve-DnsName "google.com" -Server $DNS[0] -ErrorAction SilentlyContinue
    if ($dnsTest) {
        Write-Host "  ✓ DNS funcionando" -ForegroundColor Green
    }
    else {
        Write-Host "  ! DNS nao responde" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "   ✓ CONFIGURACAO CONCLUIDA!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "Configuracao aplicada com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Nova configuracao:" -ForegroundColor Cyan
    Write-Host "  IP: $IPAddress/$PrefixLength" -ForegroundColor White
    Write-Host "  Gateway: $Gateway" -ForegroundColor White
    Write-Host "  DNS: $($DNS -join ', ')" -ForegroundColor White
    Write-Host ""

    Write-Host "IMPORTANTE: Anote este IP para conexoes futuras!" -ForegroundColor Yellow
    Write-Host ""

    # Salvar configuração em arquivo
    $configFile = "static-ip-config.txt"
    $configContent = @"
========================================
  CONFIGURACAO DE IP ESTATICO
========================================

Data/Hora: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Interface: $($selectedInterface.Name)
MAC: $($selectedInterface.MacAddress)

IP: $IPAddress/$PrefixLength
Gateway: $Gateway
DNS: $($DNS -join ', ')

PARA CONECTAR VIA RDP:
  mstsc /v:$IPAddress

PARA REVERTER PARA DHCP:
  Set-NetIPInterface -InterfaceIndex $($selectedInterface.ifIndex) -Dhcp Enabled
  Set-DnsClientServerAddress -InterfaceIndex $($selectedInterface.ifIndex) -ResetServerAddresses

========================================
"@

    $configContent | Out-File -FilePath $configFile -Encoding UTF8
    Write-Host "Configuracao salva em: $configFile" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "ERRO ao aplicar configuracao: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Revertendo para DHCP..." -ForegroundColor Yellow

    try {
        Set-NetIPInterface -InterfaceIndex $selectedInterface.ifIndex -Dhcp Enabled
        Set-DnsClientServerAddress -InterfaceIndex $selectedInterface.ifIndex -ResetServerAddresses
        Write-Host "  ✓ Revertido para DHCP" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Erro ao reverter: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Voce pode precisar reconfigurar manualmente em:" -ForegroundColor Yellow
        Write-Host "  Painel de Controle → Rede e Internet → Conexoes de Rede" -ForegroundColor White
    }

    exit 1
}

Write-Host "Pressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
