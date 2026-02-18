# Notas do Claude

## Configuracao do Ambiente

- A maquina local (de onde os prompts sao executados) **nao e** a maquina de staging
- Conexao a maquina de staging e feita via **RDP (Remote Desktop Protocol)**
- O Claude Code esta rodando na maquina local, mas operando sobre arquivos da maquina de staging remota
- **IMPORTANTE**: Trabalhar apenas dentro da pasta `StagingLocalRunner` - nao acessar pastas externas
- **Projetos de exemplo**: Ficam em pastas que comecam com `copia` (ex: `copiaDash`, `copiaCore`, etc.)

---

## Organizacao e Repositorios

- **Organizacao GitHub**: `SistemaESO`
- **Runner**: Configurado a nivel de organizacao

| Repositorio | Proposito | Porta |
|-------------|-----------|-------|
| **StagingLocalRunner** | Infraestrutura - scripts de setup | - |
| **StagingDashboard** | Dashboard de gerenciamento | 5000 |
| **ESO.Core** | Aplicacao principal | 5001-30000 |
| **ESO.Teampanel** | Painel administrativo | 5001-30000 |
| **ESO.Portal** | Portal web | 5001-30000 |

---

## Arquitetura do Sistema

```
                    [GitHub - Org SistemaESO]
                              |
                    [GitHub Actions Workflow]
                    runs-on: [self-hosted, Windows, staging]
                              |
                    [Maquina de Staging]
                    Windows 11 + Docker Desktop (Linux Containers via WSL2)
                              |
                    [Caddy - HTTPS :443]
                              |
                    [Dashboard :5000] -- YARP Proxy --> [Containers :80]
```

### URLs de Acesso
- **Dashboard**: `https://10.0.1.34.nip.io/dashboard`
- **Containers**: `https://{container-name}.10.0.1.34.nip.io`

---

## Maquina de Staging

- **OS**: Windows 11 Pro
- **Docker**: Docker Desktop em modo **Linux Containers**
- **Runner**: GitHub Actions self-hosted (nivel organizacao)
- **Acesso**: RDP

---

## Dashboard (StagingDashboard)

### Funcionalidades
- Containers organizados por secoes: **Teampanel**, **Core**, **Portal**, **MySQL**, **Outros**
- Botoes: **Abrir**, **Logs**, **Parar/Iniciar**, **Remover**, **Notion**
- Criacao de containers **MySQL** e **Valkey (Redis)** via interface
- Botao **Copiar** connection string do MySQL/Valkey
- Exibicao de **commit**, **autor**, **mensagem** do deploy
- Auto-refresh a cada 30 segundos
- **Link Notion**: Abre o card correspondente no Notion baseado na branch

### APIs
| Endpoint | Metodo | Descricao |
|----------|--------|-----------|
| `/api/containers` | GET | Lista containers |
| `/api/containers/{name}` | DELETE | Remove container |
| `/api/containers/{name}/stop` | POST | Para container |
| `/api/containers/{name}/start` | POST | Inicia container |
| `/api/containers/{name}/logs?tail=200` | GET | Retorna logs |
| `/api/containers/create-mysql` | POST | Cria MySQL |
| `/api/containers/create-valkey` | POST | Cria Valkey (Redis) |
| `/api/notion/card?branch={branch}` | GET | Busca card no Notion |

### Criar MySQL
```json
POST /api/containers/create-mysql
{ "name": "staging", "version": "8.4.7", "rootPassword": "senha", "port": 36000 }
```
Nome recebe prefixo `mysql-` automaticamente. Porta sugerida: **36000+**

### Criar Valkey (Redis)
```json
POST /api/containers/create-valkey
{ "name": "staging", "password": "opcional", "port": 37000 }
```
Nome recebe prefixo `valkey-` automaticamente. Porta sugerida: **37000+**

---

## Proxy Reverso (nip.io)

O servico **nip.io** resolve subdominios para o IP embutido:
- `eso-core-staging-test.10.0.1.34.nip.io` → `10.0.1.34`

Fluxo: Browser → Caddy (HTTPS) → Dashboard → YARP → Container

O Dashboard usa `ForwardedHeadersTransformer` customizado para passar headers X-Forwarded corretamente via YARP.

---

## Labels de Deploy

Os workflows adicionam labels aos containers:

| Label | Descricao |
|-------|-----------|
| `commit_short` | SHA curto (7 chars) |
| `commit_message` | Mensagem (max 80 chars) |
| `author` | Nome do autor |
| `branch` | Nome da branch |
| `deployed_at` | Data/hora do deploy |

---

## Configuracao dos Repos

### Todos os repos de staging
- **Trigger**: Push para `staging/**`
- **Environment**: `staging`
- **Container**: `{prefixo}-{branch-safe}`
- **Porta**: 5001-30000 (hash SHA256 do repo+branch)
- **Network**: `staging-network`

### Deploy Automatico Core → Teampanel

Quando o Core e deployado, ele automaticamente dispara o deploy do Teampanel:

1. Push no Core em `staging/feature-x`
2. Core verifica se existe branch `staging/feature-x` no Teampanel
3. **Se existir** → dispara workflow na branch `staging/feature-x`
4. **Se nao existir** → dispara workflow na branch `sprint`
5. Container Teampanel e nomeado como `eso-teampanel-staging-feature-x` (compativel com Core)

**Requisito**: Secret `GH_PAT` no repo do Core com Personal Access Token que tenha permissao `Actions: write` no Teampanel.

### ForwardedHeaders (obrigatorio em Staging)
```csharp
if (app.Environment.IsStaging())
{
    app.UseForwardedHeaders(new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost
    });
}
```

---

## MySQL

### Via Dashboard (recomendado)
- Versao configuravel (padrao 8.4.7)
- Porta sugerida: **36000** (configuravel)
- `lower_case_table_names=1` automatico
- Connection string copiavel pelo Dashboard
- Vinculacao automatica a containers Core/Teampanel/Portal

### Connection Strings
```
# Para containers (via Docker network)
Server=mysql-staging;Port=3306;Database=;User=root;Password=;

# Para acesso externo
Server=10.0.1.34;Port=36000;Database=;User=root;Password=;
```

---

## Valkey (Redis)

### Via Dashboard (recomendado)
- Imagem: `valkey/valkey:latest` (compativel com Redis)
- Porta sugerida: **37000** (configuravel)
- Senha opcional
- Connection string copiavel pelo Dashboard
- Vinculacao automatica a containers Core/Teampanel/Portal

### Connection Strings
```
# Para containers (via Docker network, sem senha)
valkey-staging:6379

# Para containers (via Docker network, com senha)
valkey-staging:6379,password=senha

# Para acesso externo
10.0.1.34:37000
```

---

## Docker

- **Modo**: Linux Containers
- **Network**: `staging-network` (driver `bridge`)
- **Criar network**: `docker network create staging-network`

---

## Caddy (HTTPS)

```
# Caddyfile em C:\configs\Caddyfile
*.10.0.1.34.nip.io {
    reverse_proxy localhost:5000
    tls internal
}
```

Comandos:
```powershell
Get-Process caddy                              # Ver processo
Start-ScheduledTask 'Caddy Reverse Proxy'      # Iniciar
Stop-Process -Name caddy                       # Parar
caddy reload --config C:\configs\Caddyfile     # Recarregar
```

---

## Scripts (_validado/)

| Script | Descricao |
|--------|-----------|
| `02-install-dependencies.ps1` | Instala Chocolatey, Git, Docker, etc |
| `03-setup-github-runner.ps1` | Configura runner da organizacao |
| `04-setup-mysql.ps1` | Instala MySQL no Windows |
| `05-setup-caddy.ps1` | Instala Caddy como reverse proxy HTTPS |
| `load-test.ps1` | Cria multiplas copias de um container |

---

## LoginAsUser (Teampanel → Core)

Permite administradores do Teampanel logarem como qualquer usuario no Core sem precisar da senha.

### Fluxo

```
Teampanel                           Core
    |                                 |
    | POST /account/loginasuserexternal
    | + Bearer Token                  |
    |-------------------------------->|
    |                                 | Autentica usuario
    |      Set-Cookie (sessao)        |
    |<--------------------------------|
    |                                 |
    | Redirect browser para:          |
    | /account/manageloginfromteampanel
    |-------------------------------->|
    |                                 | Converte cookies tp_* em definitivos
    |      Redirect para lobby        |
    |<--------------------------------|
```

### Variaveis de Ambiente do Teampanel

| Variavel | Descricao | Exemplo Staging |
|----------|-----------|-----------------|
| `ESO_TEAMPANEL_ESOCORE_CORSURL` | URL interna para comunicacao container-container | `http://eso-core-staging-test:80` |
| `ESO_TEAMPANEL_ESOCORE_CORSREDIRECTURL` | URL publica para redirect do browser (apenas staging) | `https://eso-core-staging-test.10.0.1.34.nip.io` |
| `ESO_CORE_TEAMPANEL_CORSTOKEN` | Token Bearer compartilhado entre Teampanel e Core | (secret) |

**Nota**: `CORSREDIRECTURL` so precisa ser preenchida em staging. Em producao e localhost, deixar vazia e o sistema usa o comportamento padrao.

### Dominio dos Cookies

O dominio e determinado automaticamente:
- Se `CORSREDIRECTURL` preenchida → extrai dominio da URL (ex: `.10.0.1.34.nip.io`)
- Se nao preenchida e `baseUrl` contem "localhost" → `.localhost`
- Caso contrario → `.sistemaeso.com.br`

---

## Integracao Notion

O Dashboard permite abrir diretamente o card do Notion correspondente a branch do container.

### Configuracao
1. Criar integracao no Notion: https://www.notion.so/my-integrations
2. Compartilhar a database de tarefas com a integracao
3. Adicionar secrets no repositorio StagingDashboard:
   - `NOTION_TOKEN`: Token da integracao
   - `NOTION_CARD_DATABASE_ID`: ID da database de tarefas

### Como funciona
- A database deve ter uma propriedade de formula chamada `Branch` que monta o nome da branch
- O endpoint `/api/notion/card?branch={branch}` faz query na API do Notion
- Se encontrar um card, retorna a URL para abrir em nova aba

### Exemplo de Query
```json
POST https://api.notion.com/v1/databases/{database_id}/query
{
  "filter": {
    "property": "Branch",
    "formula": {
      "string": {
        "equals": "772-rel-maintenance"
      }
    }
  }
}
```

---

## Problemas Conhecidos

| Problema | Solucao |
|----------|---------|
| `pwsh: command not found` | Usar `shell: powershell` no workflow |
| Cookie nao salva | Usar HTTPS via Caddy + `UseForwardedHeaders` |
| Redirect sem nip.io | `ForwardedHeadersTransformer` no Dashboard |
| Case-sensitivity Linux | Renomear arquivos para minusculas com `git mv` |
| Imagens `<none>` | `docker image prune -f` |
| LoginAsUser redirect errado | Configurar `ESO_TEAMPANEL_ESOCORE_CORSREDIRECTURL` em staging |
| Teampanel nao sobe junto com Core | Deploy automatico via `workflow_dispatch` + `GH_PAT` |

---

## Pendencias

- [ ] Corrigir case-sensitivity: `jquery.matchHeight-min.js` no ESO.Core
- [ ] Copiar arquivos atualizados para os repos reais:
  - [ ] **ESO.Teampanel**: `Codes/Helpers/Secret.cs`
  - [ ] **ESO.Teampanel**: `Controllers/Api/License/LoginAsUserApiController.cs`
  - [ ] **ESO.Teampanel**: `.github/workflows/staging-deploy.yml`
  - [ ] **ESO.Core**: `.github/workflows/staging-deploy.yml`
- [ ] Criar secret `GH_PAT` no repositorio ESO.Core com token que tenha acesso ao ESO.Teampanel
- [ ] **Notion**: Criar secrets no repositorio StagingDashboard:
  - `NOTION_TOKEN`: Token de integracao do Notion
  - `NOTION_CARD_DATABASE_ID`: ID da database de tarefas
