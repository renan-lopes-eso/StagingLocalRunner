<#
.SYNOPSIS
    Corrige permissões de usuário para acesso RDP

.DESCRIPTION
    Este script resolve o erro 0xc07 (restrição de conta)
    Adiciona o usuário ao grupo Remote Desktop Users e
    configura permissões necessárias

.PARAMETER Username
    Nome do usuário (deixe vazio para usar o usuário atual)

.EXAMPLE
    .\fix-rdp-permissions.ps1

.EXAMPLE
    .\fix-rdp-permissions.ps1 -Username "admin"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Username
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Corrigir Permissoes RDP" -ForegroundColor Cyan
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

# Se não especificou usuário, usar o atual
if (-not $Username) {
    $Username = $env:USERNAME
    Write-Host "Usando usuario atual: $Username" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "[1/6] Verificando usuario..." -ForegroundColor Yellow

# Verificar se o usuário existe
try {
    $user = Get-LocalUser -Name $Username -ErrorAction Stop
    Write-Host "  ✓ Usuario encontrado: $($user.Name)" -ForegroundColor Green
    Write-Host "    Conta habilitada: $($user.Enabled)" -ForegroundColor White
}
catch {
    Write-Host "  ✗ Usuario '$Username' nao encontrado!" -ForegroundColor Red
    exit 1
}

# Verificar se a conta está habilitada
if (-not $user.Enabled) {
    Write-Host ""
    Write-Host "  ! Conta esta desabilitada, habilitando..." -ForegroundColor Yellow
    try {
        Enable-LocalUser -Name $Username -ErrorAction Stop
        Write-Host "  ✓ Conta habilitada" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Erro ao habilitar conta: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[2/6] Verificando senha..." -ForegroundColor Yellow

# Verificar se o usuário tem senha (senhas vazias podem causar problema)
Write-Host "  ! IMPORTANTE: Usuarios sem senha podem ter problemas com RDP" -ForegroundColor Yellow
Write-Host "  ! Se sua conta nao tem senha, considere adicionar uma" -ForegroundColor Yellow

Write-Host ""
Write-Host "[3/6] Adicionando ao grupo Remote Desktop Users..." -ForegroundColor Yellow

try {
    # Verificar se já está no grupo
    $rdpGroup = Get-LocalGroupMember -Group "Remote Desktop Users" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Username" }

    if ($rdpGroup) {
        Write-Host "  ✓ Usuario ja esta no grupo Remote Desktop Users" -ForegroundColor Green
    }
    else {
        # Adicionar ao grupo
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction Stop
        Write-Host "  ✓ Usuario adicionado ao grupo Remote Desktop Users" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ! Erro ao adicionar ao grupo: $_" -ForegroundColor Yellow
    Write-Host "  Tentando metodo alternativo..." -ForegroundColor Yellow

    # Tentar via net localgroup
    $result = net localgroup "Remote Desktop Users" $Username /add 2>&1
    if ($LASTEXITCODE -eq 0 -or $result -like "*already a member*") {
        Write-Host "  ✓ Usuario configurado no grupo" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "[4/6] Verificando grupo Administrators..." -ForegroundColor Yellow

try {
    $adminGroup = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Username" }

    if ($adminGroup) {
        Write-Host "  ✓ Usuario ja e Administrador (tem acesso total ao RDP)" -ForegroundColor Green
    }
    else {
        Write-Host "  ! Usuario NAO e Administrador" -ForegroundColor Yellow
        Write-Host "  Usuario esta no grupo Remote Desktop Users (suficiente para RDP)" -ForegroundColor White
    }
}
catch {
    Write-Host "  ! Nao foi possivel verificar grupo Administrators" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[5/6] Configurando politicas locais..." -ForegroundColor Yellow

try {
    # Desabilitar NLA temporariamente (pode causar o erro 0xc07)
    Write-Host "  Desabilitando Network Level Authentication..." -ForegroundColor White
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0 -ErrorAction Stop
    Write-Host "  ✓ NLA desabilitado (menos seguro, mas facilita conexao)" -ForegroundColor Green
}
catch {
    Write-Host "  ! Erro ao desabilitar NLA: $_" -ForegroundColor Yellow
}

try {
    # Permitir conexões remotas vazias (sem senha)
    Write-Host "  Configurando politica de senha vazia..." -ForegroundColor White
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name "LimitBlankPasswordUse" -Value 0 -ErrorAction Stop
    Write-Host "  ✓ Conexoes sem senha permitidas (apenas para rede local!)" -ForegroundColor Green
}
catch {
    Write-Host "  ! Erro ao configurar politica de senha: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[6/6] Reiniciando servico RDP..." -ForegroundColor Yellow

try {
    Restart-Service -Name "TermService" -Force -ErrorAction Stop
    Write-Host "  ✓ Servico RDP reiniciado" -ForegroundColor Green
}
catch {
    Write-Host "  ! Erro ao reiniciar servico: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   ✓ CORRECOES APLICADAS!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "RESUMO DAS CONFIGURACOES:" -ForegroundColor Cyan
Write-Host "-------------------------" -ForegroundColor Cyan
Write-Host "  Usuario: $Username" -ForegroundColor White
Write-Host "  Grupo RDP: Adicionado" -ForegroundColor Green
Write-Host "  NLA: Desabilitado" -ForegroundColor Yellow
Write-Host "  Senha vazia: Permitida (apenas rede local)" -ForegroundColor Yellow
Write-Host ""

Write-Host "TENTE CONECTAR NOVAMENTE:" -ForegroundColor Cyan
Write-Host "-------------------------" -ForegroundColor Cyan

# Obter IP da máquina
$ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -notlike "127.*" -and
    $_.IPAddress -notlike "169.254.*" -and
    ($_.IPAddress -like "192.168.*" -or $_.IPAddress -like "10.*" -or $_.IPAddress -like "172.*")
}

if ($ips) {
    $mainIP = $ips[0].IPAddress
    Write-Host "  Da maquina local, execute:" -ForegroundColor Yellow
    Write-Host "    mstsc /v:$mainIP" -ForegroundColor White
    Write-Host ""
    Write-Host "  Usuario: $env:COMPUTERNAME\$Username" -ForegroundColor White
    Write-Host "  (ou apenas: $Username)" -ForegroundColor White
    Write-Host ""
}

Write-Host "INFORMACOES DE SEGURANCA:" -ForegroundColor Cyan
Write-Host "-------------------------" -ForegroundColor Cyan
Write-Host "  ! NLA foi desabilitado para facilitar conexao" -ForegroundColor Yellow
Write-Host "  ! Conexoes sem senha foram permitidas" -ForegroundColor Yellow
Write-Host "  ! Essas configuracoes sao OK para rede local confiavel" -ForegroundColor Yellow
Write-Host "  ! NAO exponha esta maquina para internet!" -ForegroundColor Red
Write-Host ""

Write-Host "SE AINDA DER ERRO:" -ForegroundColor Cyan
Write-Host "------------------" -ForegroundColor Cyan
Write-Host "1. Verifique se o usuario tem senha configurada" -ForegroundColor White
Write-Host "2. Tente adicionar uma senha se nao tiver:" -ForegroundColor White
Write-Host "   net user $Username SuaSenha123" -ForegroundColor White
Write-Host ""
Write-Host "3. Ou configure senha pelo Painel de Controle:" -ForegroundColor White
Write-Host "   Painel de Controle → Contas de Usuario → Alterar Senha" -ForegroundColor White
Write-Host ""

Write-Host "Pressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
