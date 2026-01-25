# ====================================
# Script 04: Setup MySQL para Staging
# ====================================
# IMPORTANTE: Rodar como Administrador!
# Credenciais sao lidas de C:\configs\secrets.json

$mysqlVersion = "8.4.8"
$mysqlFolder = "C:\tools\mysql\mysql-$mysqlVersion-winx64"
$mysqlBin = "$mysqlFolder\bin"
$configPath = "C:\configs"
$secretsFile = Join-Path $configPath "secrets.json"

# ============================================
# Verificar se esta rodando como Administrador
# ============================================
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ERRO: NAO ESTA COMO ADMINISTRADOR!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Este script precisa rodar como Administrador." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Como executar:" -ForegroundColor Cyan
    Write-Host "1. Clique direito no PowerShell" -ForegroundColor White
    Write-Host "2. Selecione 'Executar como administrador'" -ForegroundColor White
    Write-Host "3. Navegue ate a pasta e execute novamente" -ForegroundColor White
    Write-Host ""
    Read-Host "Pressione Enter para sair"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SETUP MYSQL $mysqlVersion - STAGING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# Carregar credenciais do secrets.json
# ============================================
Write-Host "1. Carregando credenciais..." -ForegroundColor Yellow

# Criar pasta config se nao existir
if (-not (Test-Path $configPath)) {
    New-Item -Path $configPath -ItemType Directory | Out-Null
    Write-Host "  Pasta $configPath criada" -ForegroundColor Green
}

# Criar secrets.json se nao existir ou adicionar secao mysql
if (-not (Test-Path $secretsFile)) {
    $template = @{
        github = @{
            token = "github_pat_SEU_TOKEN_AQUI"
            org = "NOME_DA_ORGANIZACAO"
        }
        mysql = @{
            user = "root"
            password = "SENHA_DO_MYSQL"
        }
    } | ConvertTo-Json -Depth 10

    Set-Content -Path $secretsFile -Value $template
    Write-Host "  Arquivo secrets.json criado" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ! IMPORTANTE: Edite o arquivo secrets.json com suas credenciais!" -ForegroundColor Yellow
    Write-Host "  ! Caminho: $secretsFile" -ForegroundColor White
    Write-Host ""

    $openFile = Read-Host "  Deseja abrir o arquivo agora para editar? (s/N)"
    if ($openFile -eq "s" -or $openFile -eq "S") {
        Start-Process notepad $secretsFile
        Write-Host ""
        Write-Host "  Edite o arquivo e salve. Pressione Enter quando terminar..." -ForegroundColor Yellow
        Read-Host
    }
}

# Ler secrets.json
try {
    $secrets = Get-Content $secretsFile -Raw | ConvertFrom-Json
    Write-Host "  Arquivo secrets.json carregado" -ForegroundColor Green
}
catch {
    Write-Host "  ERRO ao ler secrets.json: $_" -ForegroundColor Red
    Read-Host "Pressione Enter"
    exit 1
}

# Verificar se secao mysql existe
if (-not $secrets.mysql) {
    Write-Host "  Secao 'mysql' nao encontrada no secrets.json" -ForegroundColor Yellow
    Write-Host "  Adicionando secao mysql..." -ForegroundColor Yellow

    $secrets | Add-Member -NotePropertyName "mysql" -NotePropertyValue @{
        user = "root"
        password = "SENHA_DO_MYSQL"
    }
    $secrets | ConvertTo-Json -Depth 10 | Set-Content -Path $secretsFile

    Write-Host "  ! Edite o arquivo secrets.json e configure mysql.password" -ForegroundColor Yellow
    Write-Host "  ! Caminho: $secretsFile" -ForegroundColor White
    Write-Host ""
    Read-Host "Pressione Enter apos editar"

    # Recarregar
    $secrets = Get-Content $secretsFile -Raw | ConvertFrom-Json
}

$mysqlUser = $secrets.mysql.user
$mysqlPassword = $secrets.mysql.password

if ($mysqlPassword -eq "SENHA_DO_MYSQL") {
    Write-Host "  ! ERRO: Senha do MySQL nao foi configurada no secrets.json!" -ForegroundColor Red
    Write-Host "  ! Edite: $secretsFile" -ForegroundColor Yellow
    Write-Host "  ! Configure: mysql.password" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Pressione Enter"
    exit 1
}

Write-Host "  Usuario MySQL: $mysqlUser" -ForegroundColor Green
Write-Host ""

# ============================================
# Verificar se servico ja existe e esta rodando
# ============================================
Write-Host "2. Verificando instalacao existente..." -ForegroundColor Yellow

$mysqlService = Get-Service -Name "MySQL" -ErrorAction SilentlyContinue
if ($mysqlService -and $mysqlService.Status -eq "Running") {
    Write-Host "  MySQL ja esta instalado e rodando!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Connection String para containers:" -ForegroundColor Yellow
    Write-Host "  Server=host.docker.internal;Port=3306;User=$mysqlUser;Password=$mysqlPassword;" -ForegroundColor Gray
    Write-Host ""
    Read-Host "Pressione Enter"
    exit 0
}

Write-Host ""

# ============================================
# Limpar lock files do Chocolatey (se houver)
# ============================================
Write-Host "3. Limpando possiveis lock files do Chocolatey..." -ForegroundColor Yellow

$chocoLibPath = "C:\ProgramData\chocolatey\lib"
if (Test-Path $chocoLibPath) {
    Get-ChildItem -Path $chocoLibPath -File | Where-Object {
        $_.Name -match '^[a-f0-9]{40}$'
    } | ForEach-Object {
        Write-Host "  Removendo lock file: $($_.Name)" -ForegroundColor Gray
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    }
}

$libBadPath = "C:\ProgramData\chocolatey\lib-bad"
if (Test-Path $libBadPath) {
    Write-Host "  Removendo pasta lib-bad..." -ForegroundColor Gray
    Remove-Item $libBadPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "  Limpeza concluida." -ForegroundColor Green
Write-Host ""

# ============================================
# Instalar Visual C++ Redistributable (dependencia)
# ============================================
Write-Host "4. Verificando Visual C++ Redistributable..." -ForegroundColor Yellow

$vc64 = Test-Path "C:\Windows\System32\vcruntime140.dll"
$vc86 = Test-Path "C:\Windows\SysWOW64\vcruntime140.dll"

if (-not $vc64 -or -not $vc86) {
    Write-Host "  Instalando Visual C++ Redistributable (x86 e x64)..." -ForegroundColor Yellow
    choco install vcredist140 -y --force
    choco install vcredist140 --x86 -y --force
    Write-Host "  Visual C++ Redistributable instalado." -ForegroundColor Green
}
else {
    Write-Host "  Visual C++ Redistributable ja instalado (x86 e x64)." -ForegroundColor Green
}

Write-Host ""

# ============================================
# Instalar MySQL via Chocolatey
# ============================================
Write-Host "5. Instalando MySQL..." -ForegroundColor Yellow

if (-not (Test-Path "$mysqlBin\mysqld.exe")) {
    Write-Host "  Instalando MySQL $mysqlVersion via Chocolatey..." -ForegroundColor Yellow
    choco install mysql --version=$mysqlVersion -y --force

    if (-not (Test-Path "$mysqlBin\mysqld.exe")) {
        Write-Host "  ERRO ao instalar MySQL" -ForegroundColor Red
        Read-Host "Pressione Enter"
        exit 1
    }
    Write-Host "  MySQL $mysqlVersion instalado." -ForegroundColor Green
}
else {
    Write-Host "  MySQL $mysqlVersion ja esta instalado em $mysqlFolder" -ForegroundColor Green
}

Write-Host ""

# ============================================
# Inicializar MySQL (criar pasta data)
# ============================================
Write-Host "6. Inicializando MySQL..." -ForegroundColor Yellow

$dataFolder = "$mysqlFolder\data"
if (-not (Test-Path $dataFolder)) {
    Write-Host "  Criando pasta data..." -ForegroundColor Yellow
    Push-Location $mysqlBin
    .\mysqld.exe --initialize-insecure --console
    Pop-Location
    Write-Host "  MySQL inicializado." -ForegroundColor Green
}
else {
    Write-Host "  MySQL ja foi inicializado (pasta data existe)." -ForegroundColor Green
}

Write-Host ""

# ============================================
# Instalar como servico do Windows
# ============================================
Write-Host "7. Instalando servico do Windows..." -ForegroundColor Yellow

$mysqlService = Get-Service -Name "MySQL" -ErrorAction SilentlyContinue
if (-not $mysqlService) {
    $mysqldPath = "$mysqlBin\mysqld.exe"
    & $mysqldPath --install MySQL 2>$null

    Start-Sleep -Seconds 1
    $mysqlService = Get-Service -Name "MySQL" -ErrorAction SilentlyContinue

    if ($mysqlService) {
        Write-Host "  Servico MySQL instalado." -ForegroundColor Green
    }
    else {
        Write-Host "  Tentando via sc.exe..." -ForegroundColor Yellow
        sc.exe create MySQL binPath= "`"$mysqldPath`"" start= auto
        Start-Sleep -Seconds 1
    }
}
else {
    Write-Host "  Servico MySQL ja existe." -ForegroundColor Green
}

Write-Host ""

# ============================================
# Configurar inicio automatico e iniciar
# ============================================
Write-Host "8. Iniciando servico..." -ForegroundColor Yellow

$mysqlService = Get-Service -Name "MySQL" -ErrorAction SilentlyContinue
if (-not $mysqlService) {
    Write-Host "  ERRO: Servico MySQL nao foi criado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Tente criar manualmente:" -ForegroundColor Yellow
    Write-Host "  sc.exe create MySQL binPath= `"$mysqlBin\mysqld.exe`" start= auto" -ForegroundColor Gray
    Write-Host ""
    Read-Host "Pressione Enter"
    exit 1
}

Set-Service -Name "MySQL" -StartupType Automatic
Start-Service -Name "MySQL"

Start-Sleep -Seconds 3

$mysqlService = Get-Service -Name "MySQL"
if ($mysqlService.Status -ne "Running") {
    Write-Host "  ERRO: Servico MySQL nao iniciou!" -ForegroundColor Red
    Write-Host "  Status: $($mysqlService.Status)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Pressione Enter"
    exit 1
}

Write-Host "  Servico MySQL iniciado." -ForegroundColor Green
Write-Host ""

# ============================================
# Configurar senha do usuario root
# ============================================
Write-Host "9. Configurando senha do usuario root..." -ForegroundColor Yellow

$mysqlExe = "$mysqlBin\mysql.exe"

# Tentar conectar sem senha primeiro (apos initialize-insecure)
try {
    $testConnection = & $mysqlExe -u root -e "SELECT 1;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Conectou sem senha, definir a senha
        Write-Host "  Definindo senha do root..." -ForegroundColor Yellow
        & $mysqlExe -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$mysqlPassword';"

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Senha do root configurada." -ForegroundColor Green
        }
        else {
            Write-Host "  ERRO ao configurar senha!" -ForegroundColor Red
        }
    }
    else {
        # Ja tem senha, testar com a senha do secrets
        $testWithPass = & $mysqlExe -u root -p"$mysqlPassword" -e "SELECT 1;" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Senha do root ja esta configurada." -ForegroundColor Green
        }
        else {
            Write-Host "  AVISO: Nao foi possivel conectar ao MySQL!" -ForegroundColor Yellow
            Write-Host "  Verifique a senha no secrets.json" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "  ERRO ao configurar senha: $_" -ForegroundColor Red
}

Write-Host ""

# ============================================
# Resumo Final
# ============================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MYSQL INSTALADO E RODANDO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Versao: $mysqlVersion" -ForegroundColor White
Write-Host "  Porta: 3306" -ForegroundColor White
Write-Host "  Usuario: $mysqlUser" -ForegroundColor White
Write-Host "  Servico: MySQL (inicio automatico)" -ForegroundColor White
Write-Host ""
Write-Host "  Connection String para containers:" -ForegroundColor Yellow
Write-Host "  Server=host.docker.internal;Port=3306;User=$mysqlUser;Password=$mysqlPassword;" -ForegroundColor Gray
Write-Host ""
Write-Host "  Testar conexao:" -ForegroundColor Yellow
Write-Host "  $mysqlExe -u $mysqlUser -p" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

Read-Host "Pressione Enter"
