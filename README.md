# Sistema Multi-Staging com CI/CD

Sistema automatizado de CI/CD para deploy de múltiplos ambientes de staging simultâneos usando GitHub Actions, Docker e self-hosted runner.

## Visão Geral

Este sistema permite que você tenha múltiplas branches rodando simultaneamente em ambientes isolados de staging, cada uma em seu próprio container Docker com porta dedicada.

### Características

- Deploy automático via GitHub Actions
- Suporte para 1-5+ ambientes simultâneos
- Containers Docker isolados por branch
- Alocação dinâmica de portas (5001-5100)
- Roteamento via Traefik com URLs amigáveis
- Health checks automáticos
- Cleanup automático de ambientes antigos
- Banco MySQL compartilhado

### Arquitetura

```
GitHub Push → Actions → Self-Hosted Runner → Docker Build → Deploy → Traefik
                                                    ↓
                                            MySQL RDS (compartilhado)
```

## Pré-requisitos

### Software Necessário

- Windows 10/11 ou Windows Server
- Docker Desktop for Windows
- .NET 10.0 SDK
- Git
- PowerShell 5.1+

### Recursos Mínimos

- CPU: 4 cores
- RAM: 8GB
- Disco: 50GB SSD

### Para 5 Ambientes Simultâneos

- CPU: ~1 core
- RAM: ~1.5GB
- Disco: ~3GB

## Instalação e Configuração

### 1. Instalação do Docker

```powershell
# Baixar e instalar Docker Desktop
# https://www.docker.com/products/docker-desktop

# Verificar instalação
docker --version
docker-compose --version
```

### 2. Clonar o Repositório

```bash
git clone <seu-repositorio>
cd StaggingLocalRunner
```

### 3. Configurar Secrets

```powershell
# Copiar template de secrets
cp config/secrets.template.json config/secrets.json

# Editar config/secrets.json com suas credenciais MySQL
notepad config/secrets.json
```

### 4. Criar Network Docker

```powershell
docker network create staging-network
```

### 5. Configurar GitHub Secrets

No repositório GitHub, vá em **Settings → Secrets and variables → Actions**

Adicione o secret:
- `MYSQL_CONNECTION_STRING`: Sua connection string completa do MySQL
  - Exemplo: `Server=your-rds.amazonaws.com;Port=3306;Database=staging;Uid=user;Pwd=password;`

### 6. Setup do GitHub Self-Hosted Runner

```powershell
# Gerar Personal Access Token no GitHub
# Settings → Developer settings → Personal access tokens → Tokens (classic)
# Scopes: repo, workflow, admin:org

# Executar script de setup
.\scripts\setup-runner.ps1 -GitHubToken "ghp_YOUR_TOKEN_HERE"

# Verificar status
Get-Service | Where-Object {$_.Name -like "*actions*"}
```

### 7. Iniciar Traefik

```powershell
cd traefik
docker-compose up -d

# Verificar dashboard
# Acesso: http://localhost:8080
```

### 8. Configurar Hosts File (Opcional)

Para usar URLs amigáveis via Traefik:

```powershell
# Executar como Administrador
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n127.0.0.1 staging.local"
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 traefik.staging.local"
```

## Uso

### Deploy Automático

O deploy automático é disparado **APENAS** quando você faz push para branches com prefixos específicos:

**Branches que disparam deploy:**
- `main` - Branch principal
- `staging/*` - Qualquer branch começando com staging/
- `deploy/*` - Qualquer branch começando com deploy/

**Fluxo de trabalho recomendado:**

```bash
# 1. Dev trabalha normalmente em feature branch
git checkout -b feature/nova-funcionalidade
git add .
git commit -m "Trabalhando no feature"
git push origin feature/nova-funcionalidade
# ❌ NÃO dispara deploy - dev pode fazer vários commits sem problema

# 2. Quando quiser testar no staging, cria branch staging/
git checkout -b staging/nova-funcionalidade
git push origin staging/nova-funcionalidade
# ✅ DISPARA DEPLOY AUTOMÁTICO!
```

**Ou usando o mesmo nome:**
```bash
# Dev criando branch direto com prefixo staging/
git checkout -b staging/feature-123
git add .
git commit -m "Feature pronto para staging"
git push origin staging/feature-123
# ✅ DISPARA DEPLOY
```

O GitHub Actions irá automaticamente:
1. Detectar o push na branch staging/* ou deploy/*
2. Alocar uma porta disponível
3. Compilar a aplicação
4. Criar imagem Docker
5. Deploy do container
6. Health check
7. Disponibilizar o ambiente

### Acessar Ambientes

Após o deploy, acesse seu ambiente:

**Via Porta Direta:**
```
http://localhost:5001
http://localhost:5002
...
```

**Via Traefik (se configurado):**
```
http://staging.local/feature-nova-funcionalidade
```

**Endpoints Disponíveis:**
- `/` - Redirect para Swagger
- `/swagger` - Documentação da API
- `/health` - Health check
- `/info` - Informações do ambiente (branch, commit, etc)
- `/api/data` - CRUD de exemplo

### Deploy Manual

Se você quiser fazer deploy de uma branch que NÃO começa com `staging/` ou `deploy/`, use o deploy manual:

1. Ir em **Actions** no GitHub
2. Selecionar workflow **Staging Deploy**
3. Clicar em **Run workflow**
4. Escolher a branch (pode ser qualquer branch)

Isso é útil para testar uma `feature/` branch específica sem precisar criar uma `staging/` branch.

### Verificar Status dos Ambientes

```powershell
# Ver containers ativos
docker ps --filter "name=staging-*"

# Ver logs de um ambiente específico
docker logs staging-feature-nova-funcionalidade -f

# Verificar configuração de ambientes
cat config/environments.json

# Verificar alocação de portas
cat config/ports.json
```

### Health Check Manual

```powershell
# Health check de um ambiente
.\scripts\health-check.ps1 -Port 5001

# Health check de todos os ambientes
$envs = Get-Content config/environments.json | ConvertFrom-Json
$envs.PSObject.Properties | ForEach-Object {
    $port = $_.Value.port
    Write-Host "`nChecking $($_.Name)..." -ForegroundColor Cyan
    .\scripts\health-check.ps1 -Port $port
}
```

## Limpeza de Ambientes

### Cleanup Automático

O workflow `staging-cleanup.yml` executa automaticamente diariamente às 2 AM e remove:
- Ambientes de branches deletadas
- Ambientes com mais de 7 dias

### Cleanup Manual

```powershell
# Dry run (apenas mostra o que seria removido)
.\scripts\cleanup.ps1 -DryRun

# Remover ambientes antigos (>7 dias)
.\scripts\cleanup.ps1 -MaxAgeDays 7

# Remover ambiente específico
docker stop staging-feature-xyz
docker rm staging-feature-xyz
docker rmi staging-app:feature-xyz-*

# Liberar porta
.\scripts\port-manager.ps1 -Branch "feature/xyz" -Action "release"
```

## Scripts Disponíveis

### port-manager.ps1

Gerencia alocação de portas:

```powershell
# Alocar porta para uma branch
.\scripts\port-manager.ps1 -Branch "feature/auth" -Action "allocate"

# Obter porta de uma branch
.\scripts\port-manager.ps1 -Branch "feature/auth" -Action "get"

# Liberar porta de uma branch
.\scripts\port-manager.ps1 -Branch "feature/auth" -Action "release"
```

### deploy.ps1

Deploy manual de um ambiente:

```powershell
.\scripts\deploy.ps1 `
  -Branch "feature/auth" `
  -BranchSafe "feature-auth" `
  -CommitSha "abc123..." `
  -CommitShaShort "abc123" `
  -Port 5002 `
  -ConnectionString "Server=...;Database=staging;..."
```

### health-check.ps1

Verificação de saúde:

```powershell
# Health check com configuração padrão
.\scripts\health-check.ps1 -Port 5001

# Health check com mais tentativas
.\scripts\health-check.ps1 -Port 5001 -MaxRetries 20 -RetryDelaySeconds 10
```

### cleanup.ps1

Limpeza de ambientes:

```powershell
# Dry run
.\scripts\cleanup.ps1 -DryRun

# Remover ambientes com mais de 3 dias
.\scripts\cleanup.ps1 -MaxAgeDays 3

# Com lista de branches ativas
$branches = @("main", "develop") | ConvertTo-Json
.\scripts\cleanup.ps1 -ActiveBranches $branches
```

## Estrutura de Arquivos

```
StaggingLocalRunner/
├── .github/workflows/        # GitHub Actions workflows
│   ├── staging-deploy.yml    # Deploy automático
│   └── staging-cleanup.yml   # Limpeza automática
├── src/StagingApp/           # Aplicação ASP.NET Core
│   ├── Controllers/          # API Controllers
│   ├── Models/              # Models
│   ├── Data/                # DbContext
│   └── Program.cs           # Entry point
├── docker/                   # Docker configuration
│   ├── Dockerfile           # Dockerfile multi-stage
│   └── docker-compose.template.yml
├── traefik/                  # Traefik proxy
│   ├── traefik.yml          # Configuração estática
│   └── docker-compose.yml   # Compose do Traefik
├── scripts/                  # Scripts PowerShell
│   ├── deploy.ps1
│   ├── port-manager.ps1
│   ├── health-check.ps1
│   ├── cleanup.ps1
│   └── setup-runner.ps1
├── config/                   # Configurações
│   ├── secrets.template.json
│   ├── ports.json           # Gerado automaticamente
│   └── environments.json    # Gerado automaticamente
└── logs/                     # Logs
```

## Troubleshooting

### Container não inicia

```powershell
# Ver logs
docker logs staging-branch-name

# Verificar se porta está livre
Test-NetConnection -ComputerName localhost -Port 5001

# Verificar network
docker network inspect staging-network
```

### Problemas de conexão MySQL

```powershell
# Testar conexão do container
docker exec -it staging-main sh
# Dentro do container:
curl http://localhost:8080/health
```

### Runner não executando jobs

```powershell
# Verificar status
Get-Service | Where-Object {$_.Name -like "*actions*"}

# Ver logs do runner
cd C:\github-runner
Get-Content _diag\*.log -Tail 50

# Reiniciar
cd C:\github-runner
.\svc.sh stop
.\svc.sh start
```

### Cleanup de todos os ambientes

```powershell
# Parar todos os containers staging
docker ps --filter "name=staging-*" -q | ForEach-Object { docker stop $_ }

# Remover todos os containers staging
docker ps -a --filter "name=staging-*" -q | ForEach-Object { docker rm $_ }

# Remover todas as imagens staging
docker images "staging-app" -q | ForEach-Object { docker rmi $_ }

# Limpar configurações
echo "{}" | Set-Content config/ports.json
echo "{}" | Set-Content config/environments.json
```

## Monitoramento

### Traefik Dashboard

Acesse http://localhost:8080 para ver:
- Todos os serviços ativos
- Rotas configuradas
- Health status
- Estatísticas de tráfego

### Logs de Container

```powershell
# Logs em tempo real
docker logs staging-branch-name -f

# Últimas 100 linhas
docker logs staging-branch-name --tail 100

# Logs desde um horário específico
docker logs staging-branch-name --since "2024-01-07T10:00:00"
```

### Métricas de Sistema

```powershell
# Uso de recursos dos containers
docker stats

# Informações detalhadas de um container
docker inspect staging-branch-name
```

## Desenvolvimento Local

### Rodar aplicação localmente (sem Docker)

```powershell
cd src/StagingApp

# Configurar connection string
$env:DATABASE_CONNECTION_STRING = "Server=localhost;Database=staging;Uid=root;Pwd=password;"

# Executar
dotnet run
```

Acesse: http://localhost:5000/swagger

### Build local

```powershell
cd src/StagingApp
dotnet build
dotnet test
dotnet publish -c Release
```

### Criar migrations

```powershell
cd src/StagingApp

# Criar nova migration
dotnet ef migrations add NomeDaMigration

# Aplicar migrations
dotnet ef database update
```

## Segurança

### Secrets

- NUNCA commitar `config/secrets.json`
- NUNCA commitar connection strings no código
- Usar GitHub Secrets para dados sensíveis
- Rotacionar tokens periodicamente

### MySQL

- Usuário dedicado com privilégios mínimos
- SSL/TLS habilitado
- Security group restrito ao IP do runner

### Acesso

- Ambientes acessíveis apenas via localhost/rede interna
- Self-hosted runner em máquina dedicada
- Logs sanitizados sem credenciais

## Melhorias Futuras

### Fase 2
- SSL/TLS com Let's Encrypt
- Autenticação OAuth2
- Monitoramento com Prometheus + Grafana
- Testes E2E automatizados

### Fase 3
- Kubernetes para orquestração
- Cache distribuído com Redis
- CDN para assets estáticos
- Backup automático de banco

## Suporte

Para problemas ou dúvidas:
1. Verificar logs: `docker logs staging-branch-name`
2. Verificar GitHub Actions logs
3. Consultar seção Troubleshooting
4. Abrir issue no repositório

## Licença

[Sua licença aqui]
