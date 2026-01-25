<#
.SYNOPSIS
    Configura acesso remoto via RDP na máquina de staging

.DESCRIPTION
    Este script:
    - Habilita Remote Desktop
    - Configura firewall para permitir RDP

.EXAMPLE
    .\setup-rdp.ps1
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Setup de Acesso Remoto RDP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
788]
# Verificar se está rodando como administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERRO: Este script precisa ser executado como Administrador!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Clique com botao direito no PowerShell e selecione 'Executar como Administrador'" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/2] Habilitando Remote Desktop..." -ForegroundColor Yellow

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
Write-Host "[2/2] Configurando Firewall..." -ForegroundColor Yellow

try {
    # Tentar habilitar por DisplayGroup (inglês)
    $rules = Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

    if (-not $rules) {
        # Tentar em português
        $rules = Get-NetFirewallRule -DisplayGroup "Área de Trabalho Remota" -ErrorAction SilentlyContinue
    }

    if ($rules) {
        # Habilitar as regras encontradas
        $rules | Enable-NetFirewallRule -ErrorAction Stop
        Write-Host "  ✓ Regras de firewall configuradas ($($rules.Count) regras)" -ForegroundColor Green
    }
    else {
	Write-Host "  ✗ Nenhuma regra encontrada: $_" -ForegroundColor Red
    }
}
catch {
    Write-Host "  ✗ Erro ao configurar firewall: $_" -ForegroundColor Red
}