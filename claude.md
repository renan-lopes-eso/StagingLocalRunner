# Notas do Claude

## Configuracao do Ambiente

- A maquina local (de onde os prompts sao executados) **nao e** a maquina de staging
- Conexao a maquina de staging e feita via **RDP (Remote Desktop Protocol)**
- O Claude Code esta rodando na maquina local, mas operando sobre arquivos da maquina de staging remota

---

## Organizacao e Repositorios

### Organizacao GitHub
- **Nome**: `SistemaESO`
- **Runner**: Configurado a nivel de organizacao (atende todos os repos)

### Repositorios

| Repositorio | Proposito | Porta |
|-------------|-----------|-------|
| **StagingLocalRunner** | Infraestrutura - scripts de setup | - |
| **StagingDashboard** | Dashboard de gerenciamento | 5000 |
| **ESO.Core** | Aplicacao principal | 5000-9999 |
| **ESO.Teampanel** | Painel administrativo | 5000-9999 |
| **ESO.TestRunner** | Aplicacao de testes | 5000-9999 |
| **ESO.Portal** | Portal web | 5000-9999 |

---

## Arquitetura do Sistema

```
                    [GitHub - Org SistemaESO]
                              |
        +---------+-----------+-----------+
        |         |           |           |
   Dashboard  TestRunner   Portal      Core
        |         |           |           |
   push master  push staging/*  push staging/*
        v         v           v           v
                    [GitHub Actions Workflow]
                              |
                    runs-on: [self-hosted, Windows, staging]
                              |
                              v
                    [Maquina de Staging]
                    Windows 11 + Docker Desktop
                    (Linux Containers via WSL2)
                              |
                              v
                    [Caddy - Reverse Proxy]
                    HTTPS :443 (certificado auto-assinado)
                              |
                              v
                    [Dashboard :5000]
                    Proxy via YARP para containers
                              |
        +---------+-----------+-----------+
        |         |           |           |
   eso-core-*  eso-portal-*  staging-*   MySQL
     :80         :80          :80     :3306 (Windows)
```

### URLs de Acesso (via HTTPS)
- **Dashboard**: `https://10.0.1.34.nip.io/dashboard`
- **Containers**: `https://{container-name}.10.0.1.34.nip.io`
- Exemplo: `https://eso-core-staging-test.10.0.1.34.nip.io`

---

## Configuracao da Maquina de Staging

- **OS**: Windows 11 Pro
- **Acesso**: RDP (sem monitor/teclado fisico)
- **Docker**: Docker Desktop em modo **Linux Containers**
- **Runner**: GitHub Actions self-hosted (nivel organizacao)
- **Energia**: Alto desempenho, sem sleep/hibernacao
- **MySQL**: Via container Linux (criado pelo Dashboard) ou direto no Windows

---

## Scripts da Pasta _validado

### 02 - install-dependencies.ps1
Instala e configura:
- Chocolatey (gerenciador de pacotes)
- Git
- Docker Desktop
- Notepad++
- Opcoes de energia (PC sempre ligado)
- Politica de execucao PowerShell (RemoteSigned)
- Docker em modo Windows Containers

### 03 - setup-github-runner.ps1
- Configura runner a nivel de **organizacao**
- Usa Fine-grained token com permissao `Self-hosted runners`
- Cria Docker network com driver `nat` (Windows)
- Cria Scheduled Task para iniciar no boot
- Tolerante a re-execucao (idempotente)

### 04 - setup-mysql.ps1
- Instala MySQL direto no Windows via Chocolatey
- Roda como servico Windows (inicia no boot)
- Porta 3306
- Containers conectam via `host.docker.internal:3306`

### 05 - setup-caddy.ps1
- Instala Caddy via Chocolatey
- Configura como reverse proxy com HTTPS (certificado auto-assinado)
- Cria Caddyfile em `C:\configs\Caddyfile`
- Cria Scheduled Task para iniciar no boot
- Escuta na porta 443 (HTTPS) e faz proxy para Dashboard:5000

### load-test.ps1
- Cria multiplas copias de um container para teste de carga
- Copia variaveis de ambiente do container original
- Uso: `.\load-test.ps1 -ContainerName "eso-core-staging-test" -Copies 10 -StartPort 7000`
- Remover: `.\load-test.ps1 -ContainerName "eso-core-staging-test" -Remove`

---

## Secrets.json

Localizado em `C:\configs\secrets.json`:

```json
{
  "github": {
    "token": "github_pat_...",
    "org": "SistemaESO"
  }
}
```

**Token necessario:**
- Fine-grained token
- Resource owner: `SistemaESO`
- Organization permissions > Self-hosted runners: **Read and Write**

---

## Caddy - HTTPS Reverse Proxy

### Configuracao
- **Porta**: 443 (HTTPS)
- **Certificado**: Auto-assinado (`tls internal`)
- **Caddyfile**: `C:\configs\Caddyfile`
- **Scheduled Task**: "Caddy Reverse Proxy"

### Fluxo HTTPS
```
Browser --HTTPS:443--> Caddy --HTTP:5000--> Dashboard --HTTP:80--> Container
```

### Caddyfile
```
{
    local_certs
}

*.10.0.1.34.nip.io {
    reverse_proxy localhost:5000
    tls internal
}

10.0.1.34.nip.io {
    reverse_proxy localhost:5000
    tls internal
}
```

### Comandos Uteis
```powershell
# Ver processo
Get-Process caddy

# Ver task
Get-ScheduledTask 'Caddy Reverse Proxy'

# Parar
Stop-Process -Name caddy

# Iniciar
Start-ScheduledTask 'Caddy Reverse Proxy'

# Recarregar config
caddy reload --config C:\configs\Caddyfile

# Validar config
caddy validate --config C:\configs\Caddyfile
```

### Certificado Auto-assinado
- Navegador vai exibir aviso de seguranca (normal para staging)
- Clicar em "Avancado" > "Continuar mesmo assim"
- Para eliminar aviso: executar `caddy trust` em cada maquina cliente

---

## Dashboard (StagingDashboard)

### Funcionalidades
- Lista containers organizados por secoes: **Teampanel**, **Core**, **Portal**, **MySQL**, **Outros**
- Mostra status (rodando/parado) com indicador visual
- Link direto para acessar cada ambiente (via subdominio nip.io)
- Proxy reverso para containers via YARP com `ForwardedHeadersTransformer` customizado
- Botoes de acao: **Abrir**, **Logs**, **Parar/Iniciar**, **Remover**
- Criacao de containers **MySQL** via interface (versao, porta, senha)
- Botao **Copiar** connection string do MySQL para clipboard
- Exibicao de informacoes de deploy: **commit**, **autor**, **mensagem**
- Auto-refresh a cada 30 segundos

### APIs do Dashboard
| Endpoint | Metodo | Descricao |
|----------|--------|-----------|
| `/api/containers` | GET | Lista todos os containers |
| `/api/containers/{name}` | DELETE | Remove um container |
| `/api/containers/{name}/stop` | POST | Para um container |
| `/api/containers/{name}/start` | POST | Inicia um container |
| `/api/containers/{name}/logs` | GET | Retorna logs (query: `?tail=200`) |
| `/api/containers/create-mysql` | POST | Cria container MySQL |
| `/api/health` | GET | Health check |

### Criar MySQL via API
```json
POST /api/containers/create-mysql
{
  "name": "staging",           // Prefixo mysql- adicionado automaticamente
  "version": "8.4.7",          // Versao do MySQL
  "rootPassword": "senha",     // Senha do root
  "port": 3306                 // Porta externa
}
```

### Configuracao
- **URL**: https://10.0.1.34.nip.io/dashboard
- **Trigger**: Push para `master`
- **Container**: `staging-dashboard`

---

## Proxy Reverso com Subdominios (nip.io)

### Por que Subdominios?
- Usar paths (`/eso-portal/staging/test`) quebrava os caminhos de arquivos estaticos (CSS, JS, imagens)
- Seria necessario modificar todas as views do Portal para usar `PathBase`
- Subdominios permitem que o Portal rode na raiz `/` sem modificacoes

### Como Funciona
O servico **nip.io** resolve automaticamente subdominios para o IP embutido:
- `qualquer-coisa.10.0.1.34.nip.io` → resolve para `10.0.1.34`

### Fluxo de Acesso
```
1. Usuario clica "Abrir" no Dashboard
2. Navega para: http://eso-portal-staging-test.10.0.1.34.nip.io:5000
                       └──────────────────┘ └─────────┘
                         nome do container      IP

3. DNS (nip.io) resolve para 10.0.1.34
4. Request chega no Dashboard:5000
5. Dashboard extrai "eso-portal-staging-test" do header Host
6. Dashboard faz proxy para http://eso-portal-staging-test:80 (via Docker network)
7. Portal responde na raiz "/" - sem PathBase, sem modificacoes
```

### Arquivos Modificados (copiaDash/StagingDashboard/)
- **Program.cs**: Middleware extrai container do subdominio e faz proxy via YARP
- **wwwroot/index.html**: Gera links com formato `http://{container}.{ip}.nip.io:{port}`

### Funcoes Principais no Dashboard
- `ExtractContainerFromHost(host)`: Extrai nome do container do subdominio
- `ExtractBranchFromName(containerName)`: Extrai nome da branch do container
- `BuildRouteFromName(containerName)`: Retorna nome do container para montar URL

### Prefixos de Containers Suportados
- `eso-portal-*`
- `eso-core-*`
- `eso-teampanel-*`
- `mysql-*`
- `staging-*`

---

## ESO.Core

### Configuracao
- **Trigger**: Push para `staging/**`
- **Environment**: `staging`
- **Secret**: `ESO_CORE_ENV=Staging` (importante para ForwardedHeaders)
- **Container**: `eso-core-{branch-safe}`
- **Porta**: 5000-9999 (calculada por hash do repo+branch, range de 5000 portas)
- **Dockerfile**: Linux containers (nao Windows)

### Build Linux - Geracao de published.txt
O csproj tem dois targets para gerar info do commit:
- **Windows**: usa `certutil`, `cmd.exe`, `powershell`
- **Linux**: usa `sha256sum`, `date`, com fallback `docker-build` quando `.git` nao existe

### ForwardedHeaders (Staging only)
```csharp
if (app.Environment.IsStaging())
{
    app.UseForwardedHeaders(new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedProto
    });
}
```
- Necessario para o cookie funcionar com HTTPS via Caddy
- Apenas em Staging para nao abrir brecha em producao

---

## ESO.Teampanel

### Configuracao
- **Trigger**: Push para `staging/**`
- **Environment**: `staging`
- **Container**: `eso-teampanel-{branch-safe}`
- **Porta**: 5000-9999 (calculada por hash do repo+branch)
- **Dockerfile**: Linux containers

### Secrets Necessarios (environment staging)
| Secret | Descricao |
|--------|-----------|
| `ESO_TEAMPANEL_ENV` | Ambiente (deve ser `Staging`) |
| `ESO_TEAMPANEL_CONNECTION` | Connection string do Teampanel |
| `ESO_TEAMPANEL_ESOCORE_CONNECTION` | Connection string do ESO Core |
| `ESO_TEAMPANEL_SOMACORE_CONNECTION` | Connection string do Soma Core |
| `ESO_TEAMPANEL_SOMACORE_SENSIBLE_CONNECTION` | Connection string sensivel do Soma Core |
| `ESO_CORE_TEAMPANEL_CORSTOKEN` | Token CORS para comunicacao com Core |
| `ESO_TEAMPANEL_MANDRIL_KEY` | Chave do Mandrill para emails |

### Variaveis Automaticas
- `ESO_TEAMPANEL_ESOCORE_CORSURL`: URL do Core com mesma branch (`http://eso-core-{branch}:80`)

### ForwardedHeaders (Staging only)
Igual ao Core - necessario para HTTPS via Caddy funcionar.

---

## ESO.Portal (Novo Projeto)

### Arquivos criados em copiaPortal/ESO.Portal/
- `.github/workflows/staging-deploy.yml` - Workflow de deploy
- `ESO.Portal/Dockerfile` - Build com .NET 10 Windows Server Core
- `ESO.Portal/.dockerignore`

### Configuracao
- **Trigger**: Push para `staging/**`
- **Environment**: `staging` (configurar no GitHub)
- **Secret**: `PORTAL_CONNECTION_STRING` (no environment staging)
- **Container**: `portal-{branch-safe}`
- **Porta**: 5000-9999 (calculada por hash do repo+branch, range de 5000 portas)
- **Network**: `staging-network`

### Connection String para MySQL local
```
Server=host.docker.internal;Port=3306;Database=portal_staging;User=root;Password=SENHA;
```

---

## MySQL - Configuracao

### Opcao 1: MySQL via Dashboard (Linux Container)
O Dashboard permite criar containers MySQL diretamente pela interface:
- **Versao**: Configuravel (padrao 8.4.7)
- **Porta**: Configuravel (cada container pode usar porta diferente)
- **Senha**: Definida na criacao
- **lower_case_table_names**: Configurado automaticamente como 1
- **Network**: `staging-network`
- **Restart Policy**: `on-failure:3` (maximo 3 tentativas)

Connection string para containers:
```
Server={nome-container};Port=3306;Database=;User=root;Password=;
```

Connection string para acesso externo:
```
Server=10.0.1.34;Port={porta-configurada};Database=;User=root;Password=;
```

### Opcao 2: MySQL direto no Windows
- Instalado via Chocolatey: `choco install mysql -y`
- Roda como servico Windows
- Inicia automaticamente no boot
- Porta 3306
- Containers Docker conectam via `host.docker.internal:3306`

---

## Docker - Linux Containers

### Imagens Utilizadas
- **Build**: `mcr.microsoft.com/dotnet/sdk:9.0` (ou versao necessaria)
- **Runtime**: `mcr.microsoft.com/dotnet/aspnet:9.0` (ou versao necessaria)
- **MySQL**: `mysql:8.4.7` (criado via Dashboard)

### Network
- **Nome**: `staging-network`
- **Driver**: `bridge` (Linux containers)

### Criar Network (se nao existir)
```bash
docker network create staging-network
```

### Importante
- Docker Desktop roda **apenas um modo por vez** (Windows OU Linux, nao ambos)
- Atualmente usando **Linux containers**
- Alternar: clique direito no icone Docker > Switch to Windows/Linux containers

---

## Labels de Deploy

Os workflows adicionam labels aos containers com informacoes do commit:

| Label | Descricao | Exemplo |
|-------|-----------|---------|
| `commit` | SHA completo | `abc123def456...` |
| `commit_short` | SHA curto (7 chars) | `abc123d` |
| `commit_message` | Mensagem (max 80 chars) | `Fix bug no login` |
| `author` | Nome do autor | `Joao Silva` |
| `branch` | Nome da branch | `staging/feature-x` |
| `deployed_at` | Data/hora do deploy | `2024-01-25 14:30:00` |

Essas informacoes sao exibidas no Dashboard para cada container.

### Adicionar Labels em Novos Workflows
```yaml
- name: Run
  shell: powershell
  run: |
    $commitMsg = "${{ github.event.head_commit.message }}" -replace '["`]', '' -replace '\r?\n', ' '
    $commitMsg = $commitMsg.Substring(0, [Math]::Min(80, $commitMsg.Length))
    docker run -d `
      --name "container-name" `
      --label "commit=${{ github.sha }}" `
      --label "commit_short=${{ github.sha }}".Substring(0,7) `
      --label "commit_message=$commitMsg" `
      --label "author=${{ github.event.head_commit.author.name }}" `
      --label "branch=${{ github.ref_name }}" `
      --label "deployed_at=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" `
      ...
```

---

## Fluxo de Trabalho Git

```
dev (branch de desenvolvimento)
 |
 | git checkout -b staging/feature-x
 | git merge dev
 | git push origin staging/feature-x
 v
staging/feature-x
 |
 | Workflow executa automaticamente
 | Container sobe na porta calculada
 | Dashboard mostra o novo ambiente
 |
 | Testes realizados...
 |
 | Aprovado?
 |   -> Merge para dev
 |   -> git push origin --delete staging/feature-x
 |   -> Container removido via Dashboard
 v
dev (codigo aprovado)
```

---

## Comandos Uteis

### Runner
```powershell
# Ver se runner esta rodando
Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue

# Ver logs do runner
Get-Content C:\configs\runner\_diag\*.log -Tail 50

# Iniciar runner manualmente
cd C:\configs\runner; .\run.cmd
```

### Docker
```powershell
# Ver containers de staging
docker ps --filter "name=staging-"

# Ver logs de um container
docker logs staging-dashboard

# Remover container
docker stop nome-container
docker rm nome-container

# Limpar imagens orfas
docker image prune -f

# Verificar modo do Docker (windows/linux)
docker version --format "{{.Server.Os}}"
```

### MySQL
```powershell
# Verificar servico
Get-Service -Name "MySQL*"

# Conectar ao MySQL
mysql -u root -p

# Criar database
mysql -u root -e "CREATE DATABASE portal_staging;"
```

---

## Secrets do GitHub

### Organization Level
Configurar em: `https://github.com/organizations/SistemaESO/settings/secrets/actions`

| Secret | Descricao |
|--------|-----------|
| `ESO_CORE_CONNECTION` | String de conexao para TestRunner |

### Environment Level (staging)
Configurar em cada repo: Settings > Environments > staging > Add secret

| Secret | Descricao |
|--------|-----------|
| `PORTAL_CONNECTION_STRING` | String de conexao MySQL para Portal |

---

## Problemas Conhecidos e Solucoes

### pwsh: command not found
- **Causa**: PowerShell Core nao instalado
- **Solucao**: Usar `shell: powershell` no workflow

### Docker network
- **Linux containers**: usar driver `bridge` (padrao)
- **Windows containers**: usar driver `nat`
- **Criar network**: `docker network create staging-network`

### MySQL Windows container nao existe
- **Causa**: Oracle nao publica imagens MySQL para Windows
- **Solucao**: Instalar MySQL direto no Windows via Chocolatey

### Token deletado sem remover runner
- **Solucao**: `C:\configs\runner\config.cmd remove --local`

### Imagens <none> no Docker
- **Causa**: Camadas intermediarias de builds
- **Solucao**: `docker image prune -f`

### Paths quebrados com proxy reverso usando paths
- **Causa**: Usar paths como `/eso-portal/staging/test` quebra caminhos de CSS/JS/imagens
- **Tentativas que nao funcionaram**:
  - `X-Forwarded-PathBase` + middleware no Portal
  - `<base href>` no HTML (conflitos com tag helpers)
  - `_ViewImports.cshtml` com tag helpers (conflitos com Razor inline)
- **Solucao**: Usar subdominios com nip.io (ver secao "Proxy Reverso com Subdominios")

### Case-sensitivity em Linux containers
- **Causa**: Windows ignora maiusculas/minusculas, Linux nao
- **Sintoma**: Arquivos estaticos retornam 404 ou redirecionam para login
- **Arquivos problematicos encontrados**:
  - `Sistema-ESO-Logo-05.png` / `Sistema-ESO-Logo-10.png`
  - `jquery.matchHeight-min.js` (referenciado como `matchheight`)
- **Solucao**: Renomear arquivos para minusculas usando `git mv`:
  ```powershell
  git mv "arquivo-Maiusculo.js" "temp.js"
  git mv "temp.js" "arquivo-minusculo.js"
  ```

### Cookie nao salva em HTTP
- **Causa**: `CookieSecurePolicy.Always` requer HTTPS
- **Sintoma**: Login funciona mas redireciona para login novamente
- **Solucao**: Usar Caddy com HTTPS + `UseForwardedHeaders` no Core

### Redirect com URL incompleta (faltando nip.io)
- **Causa**: YARP nao passa headers X-Forwarded corretamente por padrao
- **Sintoma**: Redirect vai para `http://eso-core-staging-test/login` em vez de `https://eso-core-staging-test.10.0.1.34.nip.io/login`
- **Solucao**: Usar `ForwardedHeadersTransformer` customizado no Dashboard que força os headers `X-Forwarded-Host`, `X-Forwarded-Proto` e `X-Forwarded-For`

---

## Pendencias / Proximos Passos

- [ ] Corrigir case-sensitivity: `jquery.matchHeight-min.js` no ESO.Core
- [ ] Garantir secret `ESO_CORE_ENV=Staging` configurado no GitHub
- [ ] Copiar workflows atualizados (com labels) para os repos reais
- [x] Atualizar Dashboard para mostrar containers do Portal tambem
- [x] Configurar proxy reverso com subdominios (nip.io)
- [x] Configurar Caddy com HTTPS (script 05-setup-caddy.ps1)
- [x] Configurar UseForwardedHeaders no Core para staging
- [x] Dashboard: secoes separadas por tipo de container
- [x] Dashboard: botoes Parar/Iniciar
- [x] Dashboard: visualizacao de logs
- [x] Dashboard: criacao de MySQL via interface
- [x] Dashboard: copiar connection string MySQL
- [x] Dashboard: exibir commit/autor/mensagem
- [x] Workflows: adicionar labels de deploy (commit, autor, etc)
- [x] Fix: ForwardedHeadersTransformer para redirect correto via YARP

---

## Arquivos Modificados

### copiaDash/StagingDashboard/
- **Program.cs** - Proxy reverso via subdominios com YARP
  - Middleware extrai container do Host header
  - `ForwardedHeadersTransformer`: classe customizada para passar headers X-Forwarded via YARP
  - APIs: listagem, start, stop, delete, logs, create-mysql
  - Funcoes: `ExtractContainerFromHost`, `ExtractBranchFromName`, `BuildRouteFromName`
- **wwwroot/index.html** - Interface do Dashboard
  - Secoes: Teampanel, Core, Portal, MySQL, Outros
  - Botoes: Abrir, Logs, Parar/Iniciar, Remover, Copiar (MySQL)
  - Modal para criar MySQL
  - Modal para visualizar logs
  - Exibicao de commit/autor/mensagem
- **wwwroot/index.css** - Estilos do Dashboard
- `.github/workflows/deploy.yml` - Trigger em master
- Dockerfile atualizado para Linux containers

### copiaPortal/ESO.Portal/
- **Program.cs** - Corrigidos caracteres com acentuacao
- `.github/workflows/staging-deploy.yml` - Workflow de deploy
- `ESO.Portal/Dockerfile` - .NET 10 Windows Server Core
- `ESO.Portal/.dockerignore`

### copiaCore/ESO.Core/
- **ESO.Core.csproj** - Targets separados para Windows e Linux no publish
  - Windows: usa `certutil`, `cmd.exe`, `powershell`
  - Linux: usa `sha256sum`, `date`, com fallback quando `.git` nao existe
- **Program.cs**:
  - `UseForwardedHeaders` apenas em ambiente Staging (para HTTPS via Caddy)
  - `CookieSecurePolicy.Always` (requer HTTPS)

### copiaTeampanel/ESO.Teampanel/
- `.github/workflows/staging-deploy.yml` - Workflow de deploy com labels de commit/autor
- `.github/workflows/staging-cleanup.yml` - Limpeza ao deletar branch
- `ESO.Teampanel/Dockerfile` - Linux container
- `ESO.Teampanel/.dockerignore`
- **Program.cs** - `UseForwardedHeaders` para staging

### copiaCore/ESO.Core/
- `.github/workflows/staging-deploy.yml` - Workflow de deploy com labels de commit/autor

### copiaPortal/ESO.Portal/
- `.github/workflows/staging-deploy.yml` - Workflow de deploy com labels de commit/autor

### _validado/
- `02-install-dependencies.ps1` - Atualizado com Windows containers
- `03-setup-github-runner.ps1` - Atualizado para org level
- `04-setup-mysql.ps1` - Novo, instala MySQL no Windows
- `05-setup-caddy.ps1` - Novo, instala Caddy como reverse proxy HTTPS
- `load-test.ps1` - Novo, teste de carga com multiplos containers
