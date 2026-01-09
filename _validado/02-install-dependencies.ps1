# Função para verificar se um comando existe
function Test-Command {
    param($Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    }
    catch {
        return $false
    }
}

# Configurar Opções de Energia
Write-Host "Configurando opcoes de energia..." -ForegroundColor Yellow
try {
  # Definir plano de energia para Alto Desempenho
  Write-Host "  Configurando plano Alto Desempenho..." -ForegroundColor White
  powercfg -setactive SCHEME_MIN

  # Desabilitar Sleep/Suspensão (quando conectado na tomada)
  Write-Host "  Desabilitando Sleep/Suspensao..." -ForegroundColor White
  powercfg -change -standby-timeout-ac 0

  # Desabilitar Hibernação (quando conectado na tomada)
  Write-Host "  Desabilitando Hibernacao..." -ForegroundColor White
  powercfg -change -hibernate-timeout-ac 0

  # Desabilitar desligamento do monitor (quando conectado na tomada)
  # Write-Host "  Desabilitando desligamento do monitor..." -ForegroundColor White
  # powercfg -change -monitor-timeout-ac 0

  # Desabilitar desligamento do disco rígido (quando conectado na tomada)
  Write-Host "  Desabilitando desligamento do disco..." -ForegroundColor White
  powercfg -change -disk-timeout-ac 0

  # Desabilitar hibernação completamente (libera espaço em disco)
  Write-Host "  Desabilitando hibernacao do sistema..." -ForegroundColor White
  powercfg -h off

  Write-Host "  ✓ Opcoes de energia configuradas (PC sempre ligado)" -ForegroundColor Green
}
catch {
  Write-Host "  ! Erro ao configurar opcoes de energia: $_" -ForegroundColor Yellow
  Write-Host "  ! Configure manualmente em: Painel de Controle > Opcoes de Energia" -ForegroundColor Yellow
}
  
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "INICIANDO INSTALACAO" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Instalar Chocolatey (gerenciador de pacotes)
Write-Host "Verificando Chocolatey..." -ForegroundColor Yellow
$chocoInstalled = Test-Command "choco"

if (-not $chocoInstalled) {
    Write-Host "  Instalando Chocolatey..." -ForegroundColor White
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "  ✓ Chocolatey instalado" -ForegroundColor Green

        # Recarregar PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Host "  ✗ Erro ao instalar Chocolatey: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "  ✓ Chocolatey ja instalado" -ForegroundColor Green
}

# Instalar Notepad++
Write-Host "Verificando Notepad++..." -ForegroundColor Yellow
$notepadInstalled = Test-Path "C:\Program Files\Notepad++\notepad++.exe"

if (-not $notepadInstalled) {
  Write-Host "  Instalando Notepad++..." -ForegroundColor White
  try {
	  choco install notepadplusplus -y --no-progress
	  Write-Host "  ✓ Notepad++ instalado" -ForegroundColor Green
  }
  catch {
	  Write-Host "  ✗ Erro ao instalar Notepad++: $_" -ForegroundColor Red
  }
}
else {
  Write-Host "  ✓ Notepad++ ja instalado" -ForegroundColor Green
}

Write-Host ""

# Instalando o git
Write-Host "Verificando Git..." -ForegroundColor Yellow
$gitInstalled = Test-Command "git"

if (-not $gitInstalled) {
  Write-Host "  Instalando Git..." -ForegroundColor White
  try {
	  choco install git -y --no-progress
	  Write-Host "  ✓ Git instalado" -ForegroundColor Green

	  # Recarregar PATH
	  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
  }
  catch {
	  Write-Host "  ✗ Erro ao instalar Git: $_" -ForegroundColor Red
	  exit 1
  }
}
else {
  $gitVersion = git --version
  Write-Host "  ✓ Git ja instalado: $gitVersion" -ForegroundColor Green
}

Write-Host ""

 # Instalar Docker Desktop
Write-Host "Verificando Docker..." -ForegroundColor Yellow
$dockerInstalled = Test-Command "docker"

if (-not $dockerInstalled) {
  Write-Host "  Instalando Docker Desktop..." -ForegroundColor White
  Write-Host "  ! Isso pode demorar varios minutos..." -ForegroundColor Yellow
  try {
	  choco install docker-desktop -y --no-progress
	  Write-Host "  ✓ Docker Desktop instalado" -ForegroundColor Green
	  Write-Host ""
	  Write-Host "  ! IMPORTANTE: Reinicie o computador apos a instalacao!" -ForegroundColor Yellow

	  # Recarregar PATH
	  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
  }
  catch {
	  Write-Host "  ✗ Erro ao instalar Docker: $_" -ForegroundColor Red
	  exit 1
  }
}
else {
  $dockerVersion = docker --version
  Write-Host "  ✓ Docker ja instalado: $dockerVersion" -ForegroundColor Green
}

Write-Host ""