# Próximo Passo: Setup do GitHub Runner

## Status Atual
- ✅ Acesso RDP configurado (script 01)
- ✅ Git, Docker e dependências instaladas (script 02)
- ✅ IP fixado no UniFi Controller
- ⏳ **GitHub Runner** - PRÓXIMO PASSO

## O que fazer agora

### 1. Na máquina STAGING (via RDP)

#### 1.1. Copiar o projeto (se ainda não estiver lá)
```powershell
# Clonar o repositório ou copiar os arquivos
git clone https://github.com/SEU-USUARIO/StagingLocalRunner.git
cd StagingLocalRunner
```

#### 1.2. Executar o script 03
```powershell
# Abrir PowerShell como Administrador
cd D:\git\StagingLocalRunner\_validado

# Executar o script
.\03-setup-github-runner.ps1
```

O script irá:
1. ✅ Verificar se Git e Docker estão instalados
2. ✅ Criar a Docker network `staging-network`
3. ✅ Criar o arquivo `config/secrets.json` (você deve editar com suas credenciais MySQL)
4. ✅ Solicitar informações do GitHub (token e repositório)
5. ✅ Baixar e configurar o GitHub Actions Runner
6. ✅ Instalar o runner como serviço Windows
7. ✅ Validar a instalação

### 2. Criar GitHub Personal Access Token

**Antes de rodar o script, crie o token:**

1. Acesse: https://github.com/settings/tokens
2. Clique em **"Generate new token (classic)"**
3. Dê um nome: `Staging Runner Token`
4. Selecione os scopes:
   - ✅ **repo** (todas as opções)
   - ✅ **workflow**
   - ✅ **admin:org** → **read:org**
5. Clique em **"Generate token"**
6. **Copie o token** (começa com `ghp_`)
7. **GUARDE BEM** - você não conseguirá ver novamente!

### 3. Configurar GitHub Secret (MYSQL_CONNECTION_STRING)

**Depois que o runner estiver instalado:**

1. Acesse: `https://github.com/SEU-USUARIO/StagingLocalRunner/settings/secrets/actions`
2. Clique em **"New repository secret"**
3. Preencha:
   - **Name:** `MYSQL_CONNECTION_STRING`
   - **Value:** Sua connection string MySQL
     ```
     Server=seu-mysql-server.com;Port=3306;Database=staging;Uid=staging_user;Pwd=sua_senha_aqui;
     ```
4. Clique em **"Add secret"**

### 4. Verificar se Runner está ativo

1. Acesse: `https://github.com/SEU-USUARIO/StagingLocalRunner/settings/actions/runners`
2. Você deve ver o runner **"staging-local-runner"** com status **"Idle"** (verde)

### 5. Testar o Sistema

```bash
# Criar uma branch de teste
git checkout -b staging/test

# Fazer um commit
git commit --allow-empty -m "Test staging deploy"

# Push para disparar o workflow
git push origin staging/test

# Acompanhar o deploy
# https://github.com/SEU-USUARIO/StagingLocalRunner/actions
```

Se tudo funcionar:
- O GitHub Actions vai detectar o push
- O runner local vai executar o job
- Um container Docker será criado
- A aplicação estará disponível em `http://localhost:5001`

## Estrutura após o setup

```
C:\
├── github-runner\              # Runner instalado aqui
│   ├── _work\                  # Workspace dos jobs
│   ├── _diag\                  # Logs de diagnóstico
│   ├── config.sh
│   ├── run.cmd
│   └── svc.sh                  # Gerenciar serviço

D:\git\StagingLocalRunner\
├── _validado\
│   ├── 01-setup-rdp.ps1       ✅
│   ├── 02-install-dependencies.ps1  ✅
│   └── 03-setup-github-runner.ps1   ⏳ EXECUTAR AGORA
├── config\
│   ├── secrets.template.json
│   ├── secrets.json           ⚠️  EDITAR COM SUAS CREDENCIAIS
│   ├── ports.json             (será criado automaticamente)
│   └── environments.json      (será criado automaticamente)
└── ...
```

## Comandos Úteis

### Verificar status do runner
```powershell
cd C:\github-runner
.\svc.sh status
```

### Ver logs do runner
```powershell
cd C:\github-runner
Get-Content .\_diag\*.log -Tail 50
```

### Reiniciar runner
```powershell
cd C:\github-runner
.\svc.sh stop
.\svc.sh start
```

### Verificar Docker network
```powershell
docker network ls | Select-String "staging-network"
```

### Ver containers rodando
```powershell
docker ps --filter "name=staging-*"
```

## Troubleshooting

### Runner não aparece no GitHub
- Verifique se o serviço está rodando: `Get-Service | Where-Object {$_.Name -like "*actions*"}`
- Verifique os logs em `C:\github-runner\_diag\`
- Reconfigure: `cd C:\github-runner; .\config.cmd remove --token SEU_TOKEN`

### Docker network não existe
```powershell
docker network create staging-network
```

### Erro "Docker não está rodando"
- Abra o Docker Desktop e aguarde ele iniciar completamente
- Verifique: `docker ps`

## Após Conclusão

Quando tudo estiver funcionando:
1. ✅ Runner aparece no GitHub (status: Idle)
2. ✅ Docker network existe
3. ✅ secrets.json configurado
4. ✅ GitHub Secret (MYSQL_CONNECTION_STRING) configurado

**Próximo passo:** Testar com uma branch `staging/test` e ver o deploy automático acontecer!

## Referências

- README.md - Documentação completa
- SETUP-SUMMARY.md - Resumo do sistema
- Scripts em `scripts/` - Scripts de automação
