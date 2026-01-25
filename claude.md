# Notas do Claude

## Configuracao do Ambiente

- A maquina local (de onde os prompts sao executados) **nao e** a maquina de staging
- Conexao a maquina de staging e feita via **RDP (Remote Desktop Protocol)**
- O Claude Code esta rodando na maquina local, mas operando sobre arquivos da maquina de staging remota

---

## Organizacao e Repositorios

- **Organizacao GitHub**: `SistemaESO`
- **Runner**: Configurado a nivel de organizacao

| Repositorio | Proposito | Porta |
|-------------|-----------|-------|
| **StagingLocalRunner** | Infraestrutura - scripts de setup | - |
| **StagingDashboard** | Dashboard de gerenciamento | 5000 |
| **ESO.Core** | Aplicacao principal | 5000-9999 |
| **ESO.Teampanel** | Painel administrativo | 5000-9999 |
| **ESO.Portal** | Portal web | 5000-9999 |

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
- Botoes: **Abrir**, **Logs**, **Parar/Iniciar**, **Remover**
- Criacao de containers **MySQL** via interface
- Botao **Copiar** connection string do MySQL
- Exibicao de **commit**, **autor**, **mensagem** do deploy
- Auto-refresh a cada 30 segundos

### APIs
| Endpoint | Metodo | Descricao |
|----------|--------|-----------|
| `/api/containers` | GET | Lista containers |
| `/api/containers/{name}` | DELETE | Remove container |
| `/api/containers/{name}/stop` | POST | Para container |
| `/api/containers/{name}/start` | POST | Inicia container |
| `/api/containers/{name}/logs?tail=200` | GET | Retorna logs |
| `/api/containers/create-mysql` | POST | Cria MySQL |

### Criar MySQL
```json
POST /api/containers/create-mysql
{ "name": "staging", "version": "8.4.7", "rootPassword": "senha", "port": 3306 }
```
Nome recebe prefixo `mysql-` automaticamente.

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
- **Porta**: 5000-9999 (hash do repo+branch)
- **Network**: `staging-network`

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
- Porta configuravel
- `lower_case_table_names=1` automatico
- Connection string copiavel pelo Dashboard

### Connection Strings
```
# Para containers (via Docker network)
Server=mysql-staging;Port=3306;Database=;User=root;Password=;

# Para acesso externo
Server=10.0.1.34;Port=3306;Database=;User=root;Password=;
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

## Problemas Conhecidos

| Problema | Solucao |
|----------|---------|
| `pwsh: command not found` | Usar `shell: powershell` no workflow |
| Cookie nao salva | Usar HTTPS via Caddy + `UseForwardedHeaders` |
| Redirect sem nip.io | `ForwardedHeadersTransformer` no Dashboard |
| Case-sensitivity Linux | Renomear arquivos para minusculas com `git mv` |
| Imagens `<none>` | `docker image prune -f` |

---

## Pendencias

- [ ] Corrigir case-sensitivity: `jquery.matchHeight-min.js` no ESO.Core
- [ ] Copiar workflows atualizados para os repos reais
