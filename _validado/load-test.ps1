# ============================================
# Load Test - Criar multiplas copias de container
# ============================================
# Cria X copias de um container para teste de carga
# Copia as variaveis de ambiente do container original

param(
    [Parameter(Mandatory=$true)]
    [string]$ContainerName,

    [Parameter(Mandatory=$true)]
    [int]$Copies,

    [int]$StartPort = 6000,

    [switch]$Remove
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Load Test - Containers" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Se -Remove foi passado, remover containers de load test
if ($Remove) {
    Write-Host "Removendo containers de load test..." -ForegroundColor Yellow
    $containers = docker ps -a --filter "name=$ContainerName-loadtest-" --format "{{.Names}}"
    if ($containers) {
        foreach ($c in $containers) {
            Write-Host "  Removendo $c..."
            docker stop $c 2>$null
            docker rm $c 2>$null
        }
        Write-Host "Containers removidos!" -ForegroundColor Green
    } else {
        Write-Host "Nenhum container de load test encontrado" -ForegroundColor Yellow
    }
    exit 0
}

# Verificar se container original existe
Write-Host "[1/4] Verificando container original..." -ForegroundColor Yellow
$containerExists = docker ps --filter "name=^${ContainerName}$" --format "{{.Names}}"
if (-not $containerExists) {
    Write-Host "  ERRO: Container '$ContainerName' nao encontrado ou nao esta rodando" -ForegroundColor Red
    Write-Host "  Containers disponiveis:" -ForegroundColor Yellow
    docker ps --format "  - {{.Names}}"
    exit 1
}
Write-Host "  Container encontrado: $ContainerName" -ForegroundColor Green

# Obter informacoes do container original
Write-Host ""
Write-Host "[2/4] Obtendo informacoes do container..." -ForegroundColor Yellow

# Obter imagem
$image = docker inspect $ContainerName --format "{{.Config.Image}}"
Write-Host "  Imagem: $image" -ForegroundColor Green

# Obter variaveis de ambiente
$envVars = docker inspect $ContainerName --format "{{range .Config.Env}}{{println .}}{{end}}" | Where-Object { $_ -ne "" }
Write-Host "  Variaveis de ambiente: $($envVars.Count)" -ForegroundColor Green

# Obter network
$network = docker inspect $ContainerName --format "{{range `$k, `$v := .NetworkSettings.Networks}}{{`$k}}{{end}}"
if (-not $network) { $network = "staging-network" }
Write-Host "  Network: $network" -ForegroundColor Green

# Construir parametros de env vars
$envParams = @()
foreach ($env in $envVars) {
    # Ignorar variaveis do sistema
    if ($env -notmatch "^(PATH|HOME|HOSTNAME|DOTNET_|ASPNETCORE_URLS)=") {
        $envParams += "-e"
        $envParams += "`"$env`""
    }
}

# Criar containers
Write-Host ""
Write-Host "[3/4] Criando $Copies containers..." -ForegroundColor Yellow

$created = @()
for ($i = 1; $i -le $Copies; $i++) {
    $port = $StartPort + $i - 1
    $name = "$ContainerName-loadtest-$i"

    Write-Host "  [$i/$Copies] Criando $name na porta $port..." -NoNewline

    # Verificar se porta esta em uso
    $portInUse = docker ps --format "{{.Ports}}" | Select-String ":$port->"
    if ($portInUse) {
        Write-Host " PULANDO (porta em uso)" -ForegroundColor Yellow
        continue
    }

    # Remover container antigo se existir
    $ErrorActionPreference = "SilentlyContinue"
    docker rm -f $name *>$null
    $ErrorActionPreference = "Stop"

    # Criar novo container
    $cmd = "docker run -d --name `"$name`" --restart on-failure:3 --network $network -p `"${port}:80`" $($envParams -join ' ') `"$image`""

    try {
        Invoke-Expression $cmd | Out-Null
        Write-Host " OK" -ForegroundColor Green
        $created += @{ Name = $name; Port = $port }
    } catch {
        Write-Host " ERRO: $_" -ForegroundColor Red
    }
}

# Resumo
Write-Host ""
Write-Host "[4/4] Resumo" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

if ($created.Count -eq 0) {
    Write-Host "Nenhum container criado" -ForegroundColor Red
    exit 1
}

Write-Host "Containers criados: $($created.Count)" -ForegroundColor Green
Write-Host ""
Write-Host "Nome                              Porta    URL" -ForegroundColor White
Write-Host "----                              -----    ---" -ForegroundColor White
foreach ($c in $created) {
    $url = "http://localhost:$($c.Port)"
    Write-Host ("{0,-35} {1,-8} {2}" -f $c.Name, $c.Port, $url)
}

Write-Host ""
Write-Host "Comandos uteis:" -ForegroundColor Yellow
Write-Host "  Ver containers:  docker ps --filter `"name=$ContainerName-loadtest-`"" -ForegroundColor White
Write-Host "  Ver logs:        docker logs $ContainerName-loadtest-1" -ForegroundColor White
Write-Host "  Remover todos:   .\load-test.ps1 -ContainerName $ContainerName -Copies 0 -Remove" -ForegroundColor White
Write-Host ""
