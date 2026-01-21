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
| **ESO.TestRunner** | Aplicacao principal | 5001-5999 |

---

## Arquitetura do Sistema

```
                    [GitHub - Org SistemaESO]
                              |
        ┌─────────────────────┼─────────────────────┐
        |                     |                     |
   StagingDashboard     ESO.TestRunner        Outros repos
        |                     |                     |
        | push master    push staging/*        push staging/*
        v                     v                     v
                    [GitHub Actions Workflow]
                              |
                    runs-on: [self-hosted, Windows, staging]
                              |
                              v
                    [Maquina de Staging]
                    Windows 11 + Docker Desktop
                    (Windows Containers)
                              |
        ┌─────────────────────┼─────────────────────┐
        |                     |                     |
   Dashboard:5000      staging-branch:5xxx    staging-outro:5xxx
```

---

## Configuracao da Maquina de Staging

- **OS**: Windows 11 Pro
- **Acesso**: RDP (sem monitor/teclado fisico)
- **Docker**: Docker Desktop em modo **Windows Containers**
- **Runner**: GitHub Actions self-hosted (nivel organizacao)
- **Energia**: Alto desempenho, sem sleep/hibernacao

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
- **Docker em modo Windows Containers**

### 03 - setup-github-runner.ps1
- Configura runner a nivel de **organizacao**
- Usa Fine-grained token com permissao `Self-hosted runners`
- Cria Docker network com driver `nat` (Windows)
- Cria Scheduled Task para iniciar no boot
- Tolerante a re-execucao (idempotente)

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

## Dashboard (StagingDashboard)

### Funcionalidades
- Lista todos os containers de staging
- Mostra status (rodando/parado)
- Link direto para acessar cada ambiente
- Botao para remover container
- Auto-refresh a cada 30 segundos

### Configuracao
- **URL**: http://localhost:5000
- **Trigger**: Push para `master`
- **Container**: `staging-dashboard`

### Tecnologia
- .NET 8 Minimal API
- Docker.DotNet para comunicacao com Docker
- Frontend HTML/CSS/JS

---

## ESO.TestRunner (Aplicacao Principal)

### Workflow de Deploy (staging-deploy.yml)

**Triggers:**
- Push para `main`
- Push para `staging/**`
- Manual via `workflow_dispatch`

**Steps:**
1. Checkout do codigo
2. Extrai info da branch (nome seguro, commit, porta)
3. Build da imagem Docker (Windows Server Core)
4. Para container antigo (se existir)
5. Inicia novo container
6. Health check
7. Mostra containers rodando
8. Gera summary no GitHub

### Alocacao de Portas
- **Range**: 5001-5999 (5000 reservada para Dashboard)
- **Calculo**: hash dos caracteres do nome da branch % 1000 + 5000
- **Exemplo**: `staging/test` -> porta 5242

### Variaveis de Ambiente
- `ASPNETCORE_ENVIRONMENT=Staging`
- `BRANCH_NAME={branch}`
- `COMMIT_SHA={sha}`
- `ESO_CORE_CONNECTION={secret}`

---

## Docker - Windows Containers

### Imagens Utilizadas
- **Build**: `mcr.microsoft.com/dotnet/sdk:8.0-windowsservercore-ltsc2022`
- **Runtime**: `mcr.microsoft.com/dotnet/aspnet:8.0-windowsservercore-ltsc2022`

### Network
- **Nome**: `staging-network`
- **Driver**: `nat` (Windows containers)

### Primeiro Build
- Download da imagem base: ~5GB (uma vez, fica em cache)
- Builds subsequentes: 1-2 minutos

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
 |   -> Container removido (manual ou via Dashboard)
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

# Remover container manualmente
docker stop staging-staging-test
docker rm staging-staging-test

# Verificar modo do Docker (windows/linux)
docker version --format '{{.Server.Os}}'

# Alternar para Windows containers
& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchDaemon
```

### Git
```powershell
# Deletar branch remota
git push origin --delete staging/feature-x
```

---

## Secrets do GitHub (Org Level)

Configurar em: `https://github.com/organizations/SistemaESO/settings/secrets/actions`

| Secret | Descricao |
|--------|-----------|
| `ESO_CORE_CONNECTION` | String de conexao MySQL |

---

## Problemas Conhecidos e Solucoes

### pwsh: command not found
- **Causa**: PowerShell Core nao instalado
- **Solucao**: Usar `shell: powershell` no workflow

### Docker network bridge error
- **Causa**: Windows containers usam driver `nat`, nao `bridge`
- **Solucao**: Script 03 detecta e usa driver correto

### Runner ja configurado
- **Causa**: Tentativa de reconfigurar runner existente
- **Solucao**: Script 03 detecta e pula se ja estiver configurado

### Token deletado sem remover runner
- **Solucao**: `C:\configs\runner\config.cmd remove --local`

---

## Proximos Passos Possiveis

- [x] ~~Criar pagina de status dinamica (porta 5000)~~ **FEITO**
- [ ] Implementar cleanup agendado para containers orfaos
- [ ] Adicionar notificacoes (Slack/Teams) quando deploy finalizar
- [ ] Configurar SSL/HTTPS para os ambientes de staging
- [ ] Implementar limite maximo de containers simultaneos
