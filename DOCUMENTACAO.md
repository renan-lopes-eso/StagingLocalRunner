# Documentação do Ambiente de Staging

Este documento descreve todo o processo de configuração do ambiente de staging, desde a preparação da máquina até a adição de novos projetos.

---

## Índice

1. [Visão Geral](#visão-geral)
2. [Parte 1: Scripts da Máquina](#parte-1-scripts-da-máquina)
3. [Parte 2: Dashboard](#parte-2-dashboard)
4. [Parte 3: Adicionando Novos Projetos](#parte-3-adicionando-novos-projetos)
5. [Parte 4: Configuração do GitHub](#parte-4-configuração-do-github)
6. [Parte 5: HTTPS com Caddy](#parte-5-https-com-caddy)
7. [Parte 6: Testes de Carga](#parte-6-testes-de-carga)
8. [Referência Rápida](#referência-rápida)

---

## Visão Geral

### Arquitetura

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                           GitHub (Org: SistemaESO)                            │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌─────────────┐  ┌───────────┐ │
│  │ Dashboard │  │ESO.Portal │  │ ESO.Core  │  │ESO.Teampanel│  │Outros repos│ │
│  │  master   │  │ staging/* │  │ staging/* │  │  staging/*  │  │ staging/* │ │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └──────┬──────┘  └─────┬─────┘ │
└────────┼──────────────┼──────────────┼───────────────┼───────────────┼───────┘
         │              │              │               │               │
         ▼              ▼              ▼               ▼               ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                      GitHub Actions (Self-hosted Runner)                       │
└───────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                        Máquina de Staging (Windows 11)                         │
│  ┌───────────────────────────────────────────────────────────────────────┐   │
│  │                      Docker (Linux Containers)                          │   │
│  │  ┌─────────┐ ┌─────────────┐ ┌───────────┐ ┌───────────────┐          │   │
│  │  │Dashboard│ │eso-portal-* │ │eso-core-* │ │eso-teampanel-*│   ...    │   │
│  │  │  :5000  │ │   :5xxx     │ │  :5xxx    │ │    :5xxx      │          │   │
│  │  └─────────┘ └─────────────┘ └───────────┘ └───────────────┘          │   │
│  │                         staging-network                                 │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                                                                │
│  ┌──────────┐  ┌───────────┐                                                  │
│  │  MySQL   │  │   Caddy   │  (HTTPS reverse proxy, porta 443)                │
│  │  :3306   │  │  :80/443  │                                                  │
│  └──────────┘  └───────────┘                                                  │
└───────────────────────────────────────────────────────────────────────────────┘
```

### Fluxo de Acesso via Subdomínios

```
Usuário acessa: http://eso-portal-staging-test.10.0.1.34.nip.io:5000
                       └────────────────────┘ └─────────┘
                          nome do container       IP

1. DNS (nip.io) resolve para 10.0.1.34
2. Request chega no Dashboard (porta 5000)
3. Dashboard extrai "eso-portal-staging-test" do Host header
4. Dashboard faz proxy para o container via Docker network
5. Aplicação responde na raiz "/" (sem modificações necessárias)
```

---

## Parte 1: Scripts da Máquina

Os scripts estão na pasta `_validado/` e devem ser executados na ordem.

### 01. Configuração RDP (Opcional)

**Arquivo:** `01-setup-rdp.ps1`

Configura acesso remoto à máquina.

### 02. Instalação de Dependências

**Arquivo:** `02-install-dependencies.ps1`

Instala e configura:
- **Chocolatey** - Gerenciador de pacotes do Windows
- **Git** - Controle de versão
- **Docker Desktop** - Containerização
- **Notepad++** - Editor de texto
- **Configurações de energia** - Máquina sempre ligada

```powershell
# Executar como Administrador
Set-ExecutionPolicy RemoteSigned -Force
.\02-install-dependencies.ps1
```

**Pós-instalação:**
1. Reiniciar a máquina
2. Abrir Docker Desktop
3. Verificar se está em modo **Linux Containers**
   - Clique direito no ícone do Docker > "Switch to Linux containers..."

### 03. Configuração do GitHub Runner

**Arquivo:** `03-setup-github-runner.ps1`

**Pré-requisitos:**
1. Criar arquivo `C:\configs\secrets.json`:
```json
{
  "github": {
    "token": "github_pat_SEU_TOKEN_AQUI",
    "org": "SistemaESO"
  }
}
```

2. O token deve ser um **Fine-grained token** com:
   - Resource owner: `SistemaESO`
   - Organization permissions > Self-hosted runners: **Read and Write**

**Execução:**
```powershell
.\03-setup-github-runner.ps1
```

**O que o script faz:**
- Baixa e configura o GitHub Actions Runner
- Registra o runner na organização
- Cria a Docker network `staging-network`
- Configura o runner para iniciar automaticamente no boot

**Após configurar, pode deletar o secrets.json:**
```powershell
Remove-Item C:\configs\secrets.json -Force
```

### 04. Instalação do MySQL

**Arquivo:** `04-setup-mysql.ps1`

Instala MySQL diretamente no Windows (não em container).

```powershell
.\04-setup-mysql.ps1
```

**Pós-instalação:**
1. Definir senha do root:
```powershell
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'SuaSenhaAqui';"
```

2. Criar databases necessários:
```powershell
mysql -u root -p -e "CREATE DATABASE portal_staging;"
mysql -u root -p -e "CREATE DATABASE core_staging;"
```

**Conexão dos containers:**
Os containers se conectam ao MySQL via `host.docker.internal:3306`

### 05. Configuração do Caddy (HTTPS)

**Arquivo:** `05-setup-caddy.ps1`

Instala o Caddy como reverse proxy para HTTPS com certificados auto-assinados.

```powershell
.\05-setup-caddy.ps1
```

**O que o script faz:**
- Instala Caddy via Chocolatey
- Cria Caddyfile com configuração para `*.{IP}.nip.io`
- Configura Scheduled Task para iniciar no boot
- Abre portas 80 e 443 no firewall

**Após instalação:**
- Editar `C:\configs\Caddyfile` e substituir `10.0.1.34` pelo IP correto
- Reiniciar Caddy: `Stop-ScheduledTask "Caddy"; Start-ScheduledTask "Caddy"`

---

## Parte 2: Dashboard

### O que é

O Dashboard é uma aplicação web que:
- Lista todos os containers de staging
- Mostra status (rodando/parado)
- Fornece links para acessar cada ambiente
- Permite remover containers
- Funciona como **proxy reverso** para os containers

### Como Funciona o Proxy Reverso

O Dashboard usa **YARP** (Yet Another Reverse Proxy) para rotear requests baseado no subdomínio.

**Arquivo:** `copiaDash/StagingDashboard/Program.cs`

```csharp
// Middleware extrai o nome do container do Host header
var containerName = ExtractContainerFromHost(host);
// Ex: "eso-portal-staging-test.10.0.1.34.nip.io" → "eso-portal-staging-test"

// Faz proxy para o container
await forwarder.SendAsync(context, $"http://{containerName}:80", httpClient);
```

### Por que Subdomínios (nip.io)?

Usar paths como `/eso-portal/staging/test` quebrava os caminhos de arquivos estáticos (CSS, JS, imagens). Subdomínios permitem que cada aplicação rode na raiz `/` sem modificações.

**nip.io** é um serviço de DNS que resolve automaticamente:
- `qualquer-coisa.10.0.1.34.nip.io` → `10.0.1.34`

### Prefixos Suportados

O Dashboard roteia containers com os prefixos:
- `eso-portal-*`
- `eso-core-*`
- `eso-teampanel-*`
- `staging-*`

Para adicionar novos prefixos, edite o array em `Program.cs`:
```csharp
string[] containerPrefixes = ["eso-portal", "eso-core", "eso-teampanel", "staging", "novo-projeto"];
```

### Arquivos do Dashboard

```
copiaDash/StagingDashboard/
├── Program.cs              # Lógica do proxy reverso e API
├── wwwroot/
│   └── index.html          # Interface do dashboard
├── Dockerfile              # Build da imagem
└── .github/workflows/
    └── deploy.yml          # Deploy automático (push em master)
```

---

## Parte 3: Adicionando Novos Projetos

### Passo 1: Criar o Dockerfile

Crie o arquivo `Dockerfile` na pasta do projeto (junto ao `.csproj`):

```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY *.csproj ./
RUN dotnet restore

COPY . ./
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:80
EXPOSE 80

ENTRYPOINT ["dotnet", "NomeDoSeuProjeto.dll"]
```

**Importante:** Substitua `NomeDoSeuProjeto.dll` pelo nome correto da DLL.

### Passo 2: Criar o .dockerignore

Crie o arquivo `.dockerignore` na mesma pasta:

```
**/.git
**/.gitignore
**/.vs
**/bin
**/obj
**/node_modules
**/.idea
*.md
*.log
```

### Passo 3: Criar o Workflow de Deploy

Crie a pasta `.github/workflows/` na raiz do repositório e o arquivo `staging-deploy.yml`:

```yaml
name: Staging Deploy

on:
  push:
    branches:
      - staging/**

jobs:
  deploy:
    runs-on: [self-hosted, Windows, staging]
    environment: staging

    steps:
      - uses: actions/checkout@v4

      - name: Setup
        id: setup
        shell: powershell
        run: |
          $repo = "${{ github.repository }}"
          $branch = "${{ github.ref_name }}"
          $branchSafe = $branch -replace '[^a-zA-Z0-9]', '-'
          # Hash inclui repo para evitar colisao entre repos com mesma branch
          $hashInput = "$repo-$branchSafe"
          $hash = [Math]::Abs($hashInput.GetHashCode())
          $port = 5000 + ($hash % 5000)
          echo "branch_safe=$branchSafe" >> $env:GITHUB_OUTPUT
          echo "port=$port" >> $env:GITHUB_OUTPUT

      - name: Build
        shell: powershell
        run: docker build -t "PREFIXO:${{ steps.setup.outputs.branch_safe }}" -f CAMINHO/Dockerfile CAMINHO/

      - name: Stop old
        shell: powershell
        continue-on-error: true
        run: |
          docker stop "PREFIXO-${{ steps.setup.outputs.branch_safe }}" 2>$null
          docker rm "PREFIXO-${{ steps.setup.outputs.branch_safe }}" 2>$null

      - name: Run
        shell: powershell
        run: |
          docker run -d `
            --name "PREFIXO-${{ steps.setup.outputs.branch_safe }}" `
            --restart on-failure:3 `
            --network staging-network `
            -p "${{ steps.setup.outputs.port }}:80" `
            -e ASPNETCORE_ENVIRONMENT="${{ secrets.NOME_ENV }}" `
            -e CONNECTION_STRING="${{ secrets.NOME_CONNECTION }}" `
            "PREFIXO:${{ steps.setup.outputs.branch_safe }}"
```

**Importante sobre o cálculo de portas:**
- A fórmula `$hashInput = "$repo-$branchSafe"` inclui o nome do repositório para evitar colisões quando dois repos têm branches com o mesmo nome
- O range é de 5000 portas (5000-9999), permitindo até 5000 ambientes simultâneos
- Colisões são raras mas possíveis; em caso de conflito, renomeie a branch

**Substitua:**
- `PREFIXO` → Nome do projeto (ex: `eso-portal`, `eso-core`, `meu-projeto`)
- `CAMINHO` → Caminho até o Dockerfile (ex: `ESO.Portal`, `src/MeuProjeto`)
- `NOME_ENV`, `NOME_CONNECTION` → Nomes dos seus secrets

### Passo 4: Criar o Workflow de Cleanup

Crie o arquivo `.github/workflows/staging-cleanup.yml`:

```yaml
name: Staging Cleanup

on:
  delete:
    branches:
      - staging/**

jobs:
  cleanup:
    runs-on: [self-hosted, Windows, staging]

    steps:
      - name: Remove container
        shell: powershell
        continue-on-error: true
        run: |
          $branch = "${{ github.event.ref }}"
          $branchSafe = $branch -replace '[^a-zA-Z0-9]', '-'
          $containerName = "PREFIXO-$branchSafe"

          Write-Host "Removing container: $containerName"
          docker stop $containerName 2>$null
          docker rm $containerName 2>$null

          Write-Host "Removing image: PREFIXO:$branchSafe"
          docker rmi "PREFIXO:$branchSafe" 2>$null
```

### Passo 5: Configurar ForwardedHeaders para HTTPS

Para que a aplicação funcione corretamente via Caddy (HTTPS), adicione o middleware de ForwardedHeaders no `Program.cs`:

```csharp
using Microsoft.AspNetCore.HttpOverrides;

// ... resto do código ...

var app = builder.Build();

// Adicionar ANTES de qualquer outro middleware
if (app.Environment.IsStaging())
{
    app.UseForwardedHeaders(new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedProto
    });
}

// ... resto do código ...
```

**Por que isso é necessário:**
- O Caddy faz HTTPS termination e repassa a request como HTTP
- Sem ForwardedHeaders, a aplicação acha que está em HTTP
- Cookies com `SecurePolicy.Always` não funcionam sem isso
- Redirects podem ir para HTTP ao invés de HTTPS

### Passo 6: Atualizar o Dashboard (se necessário)

Se o prefixo do seu projeto não for `eso-portal`, `eso-core`, `eso-teampanel` ou `staging`, adicione-o no Dashboard:

**Arquivo:** `copiaDash/StagingDashboard/Program.cs`

```csharp
// Linha ~23 - Prefixos para o proxy reverso
string[] containerPrefixes = ["eso-portal", "eso-core", "eso-teampanel", "staging", "seu-prefixo"];
```

**Arquivo:** `copiaDash/StagingDashboard/Program.cs` (endpoint /api/containers)

```csharp
// Linha ~105 - Filtro para listar containers no dashboard
["name"] = new Dictionary<string, bool>
{
    ["staging-"] = true,
    ["eso-portal-"] = true,
    ["eso-core-"] = true,
    ["eso-teampanel-"] = true,
    ["seu-prefixo-"] = true  // Adicionar aqui
}
```

**Arquivo:** `copiaDash/StagingDashboard/Program.cs` (função ExtractBranchFromName)

```csharp
// Linha ~197 - Prefixos para extrair nome da branch
string[] prefixes = ["staging-", "eso-portal-", "eso-core-", "eso-teampanel-", "seu-prefixo-"];
```

---

## Parte 4: Configuração do GitHub

### Criar Environment

1. Acesse o repositório no GitHub
2. Vá em **Settings** > **Environments**
3. Clique em **New environment**
4. Nome: `staging`
5. Clique em **Configure environment**

### Adicionar Secrets ao Environment

Na página do environment `staging`:

1. Em **Environment secrets**, clique em **Add secret**
2. Adicione cada secret necessário:

| Secret | Descrição | Exemplo |
|--------|-----------|---------|
| `ESO_CORE_ENV` | Ambiente ASP.NET | `Staging` |
| `ESO_CORE_CONNECTION` | Connection string MySQL | `Server=host.docker.internal;Port=3306;Database=core_staging;User=root;Password=xxx;` |
| `ESO_CORE_BUCKET_ARQUIVOS` | Bucket S3 (se aplicável) | `meu-bucket-staging` |
| `ESO_CORE_MANDRIL_KEY` | Chave Mandrill (se aplicável) | `xxx` |

### Secrets por Projeto

#### ESO.Core
| Secret | Descrição |
|--------|-----------|
| `ESO_CORE_ENV` | `Staging` |
| `ESO_CORE_CONNECTION` | Connection string do banco Core |
| `ESO_CORE_BUCKET_ARQUIVOS` | Bucket S3 para arquivos |
| `ESO_CORE_MANDRIL_KEY` | Chave da API Mandrill |
| `ESO_CORE_TEAMPANEL_CORSTOKEN` | Token CORS para Teampanel |

#### ESO.Portal
| Secret | Descrição |
|--------|-----------|
| `PORTAL_ENV` | `Staging` |
| `PORTAL_CONNECTION_STRING` | Connection string do banco Portal |

#### ESO.Teampanel
| Secret | Descrição |
|--------|-----------|
| `ESO_TEAMPANEL_ENV` | `Staging` |
| `ESO_TEAMPANEL_CONNECTION` | Connection string do banco Teampanel |
| `ESO_TEAMPANEL_ESOCORE_CONNECTION` | Connection string do banco Core |
| `ESO_TEAMPANEL_SOMACORE_CONNECTION` | Connection string do banco SomaCore |
| `ESO_TEAMPANEL_SOMACORE_SENSIBLE_CONNECTION` | Connection string do SomaCore Sensible |
| `ESO_TEAMPANEL_MANDRIL_KEY` | Chave da API Mandrill |
| `ESO_CORE_TEAMPANEL_CORSTOKEN` | Token CORS para comunicação com Core |

**Nota:** O URL do Core (`ESO_TEAMPANEL_ESOCORE_CORSURL`) é gerado automaticamente pelo workflow baseado no nome da branch.

### Estrutura de Secrets Recomendada

Para novos projetos, use o padrão:
- `{PROJETO}_ENV` - Ambiente (Staging, Production)
- `{PROJETO}_CONNECTION` - Connection string do banco
- `{PROJETO}_*` - Outras configurações específicas

### Verificar Runner

1. Vá em **Settings** > **Actions** > **Runners** (nível organização)
2. Verifique se o runner está **Online** com as labels:
   - `self-hosted`
   - `Windows`
   - `staging`

---

## Parte 5: HTTPS com Caddy

### O que é

O Caddy é um servidor web que fornece HTTPS automático com certificados auto-assinados para o ambiente de staging.

### Script de Instalação

**Arquivo:** `_validado/05-setup-caddy.ps1`

```powershell
.\05-setup-caddy.ps1
```

**O que o script faz:**
- Instala Caddy via Chocolatey
- Cria o arquivo de configuração em `C:\configs\Caddyfile`
- Configura Scheduled Task para iniciar no boot
- Abre portas 80 e 443 no firewall

### Configuração (Caddyfile)

```
{
    auto_https disable_redirects
}

*.10.0.1.34.nip.io {
    tls internal

    reverse_proxy localhost:5000 {
        header_up X-Forwarded-Proto {scheme}
    }
}
```

### Fluxo de Acesso HTTPS

```
1. Usuário acessa: https://eso-portal-staging-test.10.0.1.34.nip.io
2. Caddy recebe na porta 443
3. Caddy faz TLS termination (certificado auto-assinado)
4. Caddy adiciona header X-Forwarded-Proto: https
5. Caddy repassa para Dashboard (localhost:5000)
6. Dashboard faz proxy para o container
7. Aplicação usa ForwardedHeaders para entender que está em HTTPS
```

### Importante

- Certificados são auto-assinados (navegador mostrará aviso)
- Cada aplicação precisa ter `UseForwardedHeaders` configurado (ver Parte 3, Passo 5)
- Cookies com `SecurePolicy.Always` funcionam apenas com ForwardedHeaders

---

## Parte 6: Testes de Carga

### Script de Teste de Carga

**Arquivo:** `_validado/load-test.ps1`

Cria múltiplas cópias de um container para testes de carga, copiando todas as variáveis de ambiente do container original.

### Uso

```powershell
# Criar 5 cópias do container eso-core-staging-test
.\load-test.ps1 -ContainerName "eso-core-staging-test" -Copies 5

# Criar 10 cópias
.\load-test.ps1 -ContainerName "eso-portal-staging-test" -Copies 10
```

### O que o script faz

1. Busca o container original pelo nome
2. Extrai a imagem e variáveis de ambiente
3. Cria N cópias com nomes `{original}-copy-1`, `{original}-copy-2`, etc.
4. Cada cópia recebe uma porta diferente (calculada automaticamente)
5. Todas as cópias ficam na mesma `staging-network`

### Remover Cópias

```powershell
# Parar e remover todas as cópias
docker ps -a --filter "name=eso-core-staging-test-copy" -q | ForEach-Object { docker stop $_; docker rm $_ }
```

---

## Referência Rápida

### Comandos Úteis

```powershell
# Ver containers rodando
docker ps

# Ver todos os containers (incluindo parados)
docker ps -a

# Ver logs de um container
docker logs nome-do-container

# Parar e remover um container
docker stop nome-do-container
docker rm nome-do-container

# Limpar imagens não utilizadas
docker image prune -f

# Ver status do runner
Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue

# Reiniciar o runner
cd C:\configs\runner
.\run.cmd
```

### URLs de Acesso

| Recurso | URL (HTTP) | URL (HTTPS via Caddy) |
|---------|------------|----------------------|
| Dashboard | `http://10.0.1.34:5000/dashboard` | `https://staging-dashboard.10.0.1.34.nip.io/dashboard` |
| ESO.Portal | `http://eso-portal-staging-test.10.0.1.34.nip.io:5000` | `https://eso-portal-staging-test.10.0.1.34.nip.io` |
| ESO.Core | `http://eso-core-staging-test.10.0.1.34.nip.io:5000` | `https://eso-core-staging-test.10.0.1.34.nip.io` |
| ESO.Teampanel | `http://eso-teampanel-staging-test.10.0.1.34.nip.io:5000` | `https://eso-teampanel-staging-test.10.0.1.34.nip.io` |
| API containers | `http://10.0.1.34:5000/api/containers` | - |

**Nota:** HTTPS usa certificados auto-assinados (navegador mostrará aviso de segurança).

### Fluxo de Trabalho Git

```bash
# Criar branch de staging
git checkout -b staging/minha-feature
git push origin staging/minha-feature

# O workflow executa automaticamente e cria o container

# Após testar, deletar a branch remove o container
git push origin --delete staging/minha-feature
```

### Checklist para Novo Projeto

**Arquivos no Projeto:**
- [ ] Criar `Dockerfile` na pasta do projeto (.NET 10 multi-stage build)
- [ ] Criar `.dockerignore` na pasta do projeto
- [ ] Criar `.github/workflows/staging-deploy.yml` (com fórmula de porta atualizada)
- [ ] Criar `.github/workflows/staging-cleanup.yml`
- [ ] Adicionar `UseForwardedHeaders` no `Program.cs` para Staging (HTTPS)

**GitHub:**
- [ ] Criar environment `staging` no repositório
- [ ] Adicionar secrets necessários ao environment
- [ ] Verificar se runner está online com labels corretas

**Dashboard (se novo prefixo):**
- [ ] Adicionar prefixo em `containerPrefixes` array (proxy reverso)
- [ ] Adicionar prefixo no filtro de `/api/containers` (listagem)
- [ ] Adicionar prefixo no array `prefixes` em `ExtractBranchFromName` (extração de branch)
- [ ] Rebuild e deploy do Dashboard

**Teste:**
- [ ] Push para branch `staging/test`
- [ ] Verificar se container aparece no Dashboard
- [ ] Verificar se link do Dashboard abre a aplicação
- [ ] Verificar se HTTPS funciona (via Caddy)
- [ ] Verificar se cookies funcionam (login, sessão)
- [ ] Deletar branch e verificar se container é removido

---

## Troubleshooting

### Container não aparece no Dashboard

1. Verificar se o prefixo está na lista `containerPrefixes`
2. Verificar logs do workflow no GitHub Actions
3. Verificar se o container está rodando: `docker ps`

### Erro de conexão com MySQL

1. Verificar se MySQL está rodando: `Get-Service MySQL*`
2. Testar conexão: `mysql -u root -p`
3. Verificar se connection string usa `host.docker.internal`

### Runner offline

1. Verificar processo: `Get-Process Runner.Listener`
2. Iniciar manualmente: `cd C:\configs\runner; .\run.cmd`
3. Ver logs: `Get-Content C:\configs\runner\_diag\*.log -Tail 50`

### Imagem não builda

1. Verificar se Docker está em modo Linux containers
2. Verificar Dockerfile (nome da DLL, caminhos)
3. Testar build local: `docker build -t teste -f Dockerfile .`

### Cookies não salvam / Login não funciona

1. Verificar se `UseForwardedHeaders` está configurado para Staging
2. Verificar se a ordem dos middlewares está correta (ForwardedHeaders primeiro)
3. Verificar se `CookieSecurePolicy` está configurado corretamente
4. Usar HTTPS via Caddy (cookies com `SecurePolicy.Always` precisam de HTTPS)

### Arquivos estáticos 404 (CSS, JS, imagens)

1. **Case-sensitivity**: Linux é case-sensitive, Windows não
2. Verificar se nomes dos arquivos estão todos em minúsculas
3. Usar `git mv ArquiVo.js arquivo.js` para renomear (preserva histórico)
4. Verificar referências nos arquivos HTML/Razor

### HTTPS não funciona

1. Verificar se Caddy está rodando: `Get-ScheduledTask -TaskName "Caddy*"`
2. Verificar Caddyfile em `C:\configs\Caddyfile`
3. Verificar se firewall permite portas 80 e 443
4. Verificar se aplicação tem `UseForwardedHeaders`

### Colisão de portas

1. Duas branches diferentes podem ter o mesmo hash de porta (raro)
2. Solução: renomear uma das branches
3. Verificar portas em uso: `docker ps --format "table {{.Names}}\t{{.Ports}}"`
