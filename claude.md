# Notas do Claude

## Configuracao do Ambiente

- A maquina local (de onde os prompts sao executados) **nao e** a maquina de staging
- Conexao a maquina de staging e feita via **RDP (Remote Desktop Protocol)**
- O Claude Code esta rodando na maquina local, mas operando sobre arquivos da maquina de staging remota

---

## Repositorios Envolvidos

### 1. StagingLocalRunner (Este Repositorio)
- **URL**: `https://github.com/renan-lopes-eso/StagingLocalRunner`
- **Proposito**: APENAS INFRAESTRUTURA - scripts para configurar a maquina de staging
- **Conteudo**: Scripts PowerShell para instalar dependencias e configurar o runner
- **NAO CONTEM**: Codigo da aplicacao real

### 2. ESO.TestRunner (Repositorio Real da Aplicacao)
- **URL**: `https://github.com/renan-lopes-eso/ESO.TestRunner`
- **Proposito**: Aplicacao .NET 10 que sera deployada
- **Runner configurado para**: Este repositorio (nao o StagingLocalRunner)
- **Workflow**: `.github/workflows/staging-deploy.yml`

---

## Sobre o Projeto: StagingLocalRunner

### Objetivo
Configurar uma maquina local Windows para permitir multiplos deploys de branches simultaneos rodando em containers Docker.

### Configuracao da Maquina de Staging
- **OS**: Windows 11 Pro
- **Interface**: Tem interface grafica instalada
- **Acesso**: Sem monitor nem teclado fisicos - acesso exclusivamente via RDP
- **Docker**: Docker Desktop instalado
- **Runner**: GitHub Actions self-hosted runner configurado

---

## Arquitetura do Sistema

```
[GitHub: ESO.TestRunner]
        |
        | push para staging/*
        v
[GitHub Actions Workflow]
        |
        | runs-on: [self-hosted, Windows, staging]
        v
[Maquina de Staging via RDP]
        |
        | docker build + docker run
        v
[Container Docker]
    - Nome: staging-{branch-safe}
    - Porta: 5000-5999 (baseada em hash da branch)
    - Imagem: eso-testrunner:{branch-safe}
```

---

## Scripts da Pasta _validado

### 01 - (nao documentado ainda)

### 02 - install-dependencies.ps1
Instala:
- Chocolatey (gerenciador de pacotes)
- Git
- Docker Desktop
- Notepad++
- Configura opcoes de energia (PC sempre ligado)
- Configura politica de execucao do PowerShell (RemoteSigned)

### 03 - setup-github-runner.ps1
- Configura GitHub Actions self-hosted runner
- Usa Fine-grained token (nao Classic PAT)
- Cria Scheduled Task para iniciar runner no boot
- Tolerante a re-execucao (idempotente)

---

## Workflow de Deploy (staging-deploy.yml)

### Triggers
- Push para `main`
- Push para `staging/**`
- Manual via `workflow_dispatch`

### Steps
1. Checkout do codigo
2. Extrai info da branch (nome seguro, commit, porta)
3. Build da imagem Docker
4. Para container antigo (se existir)
5. Inicia novo container
6. Health check
7. Mostra containers rodando
8. Gera summary no GitHub

### Alocacao de Portas
- Range: 5000-5999
- Calculo: hash dos caracteres do nome da branch % 1000 + 5000
- Exemplo: `staging/test` -> porta 5242

### Variaveis de Ambiente do Container
- `ASPNETCORE_ENVIRONMENT=Staging`
- `BRANCH_NAME={branch}`
- `COMMIT_SHA={sha}`
- `ESO_CORE_CONNECTION={secret}` - String de conexao MySQL

---

## Workflow de Cleanup (staging-cleanup.yml)

### Trigger
- Quando uma branch `staging/**` e deletada

### Acoes
- Para e remove o container associado
- Remove a imagem Docker

### Cleanup Manual
```powershell
docker stop staging-staging-test
docker rm staging-staging-test
docker rmi eso-testrunner:staging-test
```

---

## Fluxo de Trabalho Git Recomendado

```
dev (branch principal de desenvolvimento)
 |
 | git checkout -b staging/feature-x
 | git merge dev
 | git push origin staging/feature-x
 v
staging/feature-x (trigger do workflow)
 |
 | Container criado automaticamente
 | Testes realizados
 |
 | Aprovado? -> Merge para dev/main
 |           -> Delete branch staging/feature-x
 |           -> Container removido automaticamente
 v
dev/main (producao)
```

---

## Comandos Uteis

### Ver containers de staging rodando
```powershell
docker ps --filter "name=staging-"
```

### Ver logs de um container
```powershell
docker logs staging-staging-test
```

### Acessar shell do container
```powershell
docker exec -it staging-staging-test /bin/bash
```

### Deletar branch remota (trigger cleanup)
```bash
git push origin --delete staging/test
```

### Ver status do runner
```powershell
Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue
```

---

## Secrets Necessarios no GitHub

### ESO_CORE_CONNECTION
- String de conexao MySQL para o banco de dados
- Formato: `SERVER=...;PORT=3306;DATABASE=...;USER=...;PASSWORD=...;`
- Configurar em: Repository Settings > Secrets and variables > Actions

### GITHUB_TOKEN (para runner)
- Fine-grained token com permissao `Administration: Read and Write`
- Escopo: Apenas o repositorio ESO.TestRunner
- Usado pelo script 03 para registrar o runner

---

## Arquivos Importantes no ESO.TestRunner

### Dockerfile
- Multi-stage build
- Base: `mcr.microsoft.com/dotnet/sdk:10.0-preview` (build)
- Runtime: `mcr.microsoft.com/dotnet/aspnet:10.0-preview`
- Porta interna: 80

### .dockerignore
```
bin/
obj/
.vs/
*.user
*.log
```

### appsettings.json
- NAO COMMITAR com senhas reais
- Usar secrets do GitHub para valores sensiveis

---

## Problemas Conhecidos e Solucoes

### pwsh: command not found
- **Causa**: PowerShell Core nao instalado
- **Solucao**: Usar `shell: powershell` em vez de `shell: pwsh` no workflow

### Script execution disabled
- **Causa**: Politica de execucao do Windows
- **Solucao**: Script 02 agora configura `Set-ExecutionPolicy RemoteSigned`

### Runner ja configurado
- **Causa**: Tentativa de reconfigurar runner existente
- **Solucao**: Script 03 detecta e pula se ja estiver rodando

### Container nao acessivel
- **Causa**: Porta errada ou container nao iniciou
- **Solucao**: Verificar `docker ps` e logs do container

---

## Proximos Passos Possiveis

1. [ ] Criar pagina de status dinamica (porta 5000) mostrando todos os ambientes
2. [ ] Implementar cleanup agendado para containers orfaos
3. [ ] Adicionar notificacoes (Slack/Teams) quando deploy finalizar
4. [ ] Configurar SSL/HTTPS para os ambientes de staging
5. [ ] Implementar limite maximo de containers simultaneos
