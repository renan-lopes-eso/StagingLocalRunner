# Funcao para verificar se um comando existe
function Test-Command {
    param($Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) { return $true }
    }
    catch {
        return $false
    }
}

# Configurar Opcoes de Energia
Write-Host "Configurando opcoes de energia..." -ForegroundColor Yellow
try {
    powercfg -setactive SCHEME_MIN
    powercfg -change -standby-timeout-ac 0
    powercfg -change -hibernate-timeout-ac 0
    powercfg -change -disk-timeout-ac 0
    powercfg -h off
    Write-Host "  Opcoes de energia configuradas" -ForegroundColor Green
}
catch {
    Write-Host "  Erro ao configurar opcoes de energia" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "INICIANDO INSTALACAO" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Instalar Chocolatey
Write-Host "Verificando Chocolatey..." -ForegroundColor Yellow
$chocoInstalled = Test-Command "choco"

if (-not $chocoInstalled) {
    Write-Host "  Instalando Chocolatey..." -ForegroundColor White
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "  Chocolatey instalado" -ForegroundColor Green
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Host "  Erro ao instalar Chocolatey: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "  Chocolatey ja instalado" -ForegroundColor Green
}

# Instalar Notepad++
Write-Host "Verificando Notepad++..." -ForegroundColor Yellow
$notepadInstalled = Test-Path "C:\Program Files\Notepad++\notepad++.exe"

if (-not $notepadInstalled) {
    Write-Host "  Instalando Notepad++..." -ForegroundColor White
    try {
        choco install notepadplusplus -y --no-progress
        Write-Host "  Notepad++ instalado" -ForegroundColor Green
    }
    catch {
        Write-Host "  Erro ao instalar Notepad++" -ForegroundColor Red
    }
}
else {
    Write-Host "  Notepad++ ja instalado" -ForegroundColor Green
}

Write-Host ""

# Instalar Git
Write-Host "Verificando Git..." -ForegroundColor Yellow
$gitInstalled = Test-Command "git"

if (-not $gitInstalled) {
    Write-Host "  Instalando Git..." -ForegroundColor White
    try {
        choco install git -y --no-progress
        Write-Host "  Git instalado" -ForegroundColor Green
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Host "  Erro ao instalar Git" -ForegroundColor Red
        exit 1
    }
}
else {
    $gitVersion = git --version
    Write-Host "  Git ja instalado: $gitVersion" -ForegroundColor Green
}

Write-Host ""

# Instalar Docker Desktop
Write-Host "Verificando Docker..." -ForegroundColor Yellow
$dockerInstalled = $false
try {
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $dockerVersion) {
        $dockerInstalled = $true
    }
}
catch {
    $dockerInstalled = $false
}

if (-not $dockerInstalled) {
    Write-Host "  Instalando Docker Desktop..." -ForegroundColor White
    Write-Host "  Isso pode demorar varios minutos..." -ForegroundColor Yellow
    try {
        choco install docker-desktop -y --no-progress --force
        Write-Host "  Docker Desktop instalado" -ForegroundColor Green
        Write-Host "  IMPORTANTE: Reinicie o computador apos a instalacao!" -ForegroundColor Yellow
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Host "  Erro ao instalar Docker" -ForegroundColor Red
        exit 1
    }
}
else {
    $dockerVersion = docker --version
    Write-Host "  Docker ja instalado: $dockerVersion" -ForegroundColor Green
}

Write-Host ""

# Configurar Docker para Linux Containers
Write-Host "Configurando Docker para Linux Containers..." -ForegroundColor Yellow
try {
    $dockerOs = docker version --format '{{.Server.Os}}' 2>$null

    if ($dockerOs -eq "linux") {
        Write-Host "  Docker ja esta em modo Linux Containers" -ForegroundColor Green
    }
    elseif ($dockerOs -eq "windows") {
        Write-Host "  Alternando para Linux Containers..." -ForegroundColor White
        & "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchDaemon
        Start-Sleep -Seconds 10
        $dockerOs = docker version --format '{{.Server.Os}}' 2>$null
        if ($dockerOs -eq "linux") {
            Write-Host "  Docker configurado para Linux Containers" -ForegroundColor Green
        }
        else {
            Write-Host "  Nao foi possivel alternar automaticamente" -ForegroundColor Yellow
            Write-Host "  Clique direito no icone do Docker e selecione Switch to Linux containers" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  Docker nao esta rodando" -ForegroundColor Yellow
        Write-Host "  Inicie o Docker Desktop e configure para Linux containers" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  Erro ao configurar Docker" -ForegroundColor Yellow
    Write-Host "  Configure manualmente: Docker Desktop, Switch to Linux containers" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "INSTALACAO CONCLUIDA" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
