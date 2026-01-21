# Checkpoint - Setup GitHub Runner
**Data:** 2026-01-10
**Status:** Script 03 em andamento - Runner baixado, falta configurar

---

## ✅ O QUE JÁ FOI FEITO

### Script 01 - Setup RDP
- ✅ Configurado acesso RDP na máquina staging

### Script 02 - Dependências
- ✅ Chocolatey instalado
- ✅ Git instalado
- ✅ Docker Desktop instalado
- ✅ Notepad++ instalado
- ✅ Opções de energia configuradas (PC sempre ligado)

### Script 03 - GitHub Runner (EM ANDAMENTO)
- ✅ Git e Docker verificados
- ✅ Docker network `staging-network` criada
- ✅ Arquivo `C:\configs\secrets.json` criado e configurado
  ```json
  {
    "mysql": {
      "connectionString": "Server=...;Port=3306;Database=staging;Uid=...;Pwd=...;"
    },
    "github": {
      "token": "ghp_...",
      "repo": "owner/repository"
    }
  }
  ```
- ✅ Credenciais carregadas do secrets.json
- ✅ **GitHub Actions Runner v2.331.0 baixado** em `C:\github-runner`

---

## ⏳ PRÓXIMOS PASSOS (quando retomar)

### 1. Continuar o Script 03
O runner foi baixado mas ainda falta:

#### a) Configurar o runner
```powershell
cd C:\github-runner
.\config.cmd --url "https://github.com/owner/repo" --token "..." --name "staging-local-runner" --work "_work" --labels "self-hosted,Windows,staging" --unattended
```

#### b) Instalar como serviço Windows
```powershell
.\svc.sh install
```

#### c) Iniciar o serviço
```powershell
.\svc.sh start
```

#### d) Validar instalação
```powershell
# Verificar serviço
Get-Service | Where-Object {$_.Name -like "*actions.runner*"}

# Verificar network Docker
docker network ls | Select-String "staging-network"
```

### 2. Depois do Script 03 completar

#### a) Configurar GitHub Secret (MYSQL_CONNECTION_STRING)
1. Ir em: `https://github.com/owner/repo/settings/secrets/actions`
2. New repository secret
3. Name: `MYSQL_CONNECTION_STRING`
4. Value: mesma connection string de `C:\configs\secrets.json`

#### b) Verificar Runner no GitHub
1. Ir em: `https://github.com/owner/repo/settings/actions/runners`
2. Ver se `staging-local-runner` está com status **"Idle"** (verde)

#### c) Testar Deploy
```bash
git checkout -b staging/test
git commit --allow-empty -m "Test staging deploy"
git push origin staging/test
```

Acompanhar em: `https://github.com/owner/repo/actions`

---

## 🔧 ALTERAÇÕES FEITAS NO SCRIPT 03

### 1. Versão do Runner atualizada
```powershell
$runnerVersion = "2.331.0"  # Era 2.319.1
```

### 2. Leitura de credenciais do secrets.json
- Removida detecção automática do repo via git
- Removida solicitação interativa de repo e token
- **Agora lê direto de `C:\configs\secrets.json`**:
  - `github.token`
  - `github.repo`

### 3. Validação se já está configurado
```powershell
# Verifica se .runner existe antes de configurar
if (Test-Path ".\.runner") {
    Write-Host "  ✓ Runner ja esta configurado"
    # Continua o script sem erro
}
```

### 4. Formato correto do secrets.json
```json
{
  "mysql": {
    "connectionString": "Server=host;Port=3306;Database=staging;Uid=user;Pwd=pass;"
  },
  "github": {
    "token": "ghp_seu_token_aqui",
    "repo": "owner/repository"
  }
}
```

**IMPORTANTE:** Use `:` e não `=` no JSON!
- ❌ Errado: `repo = "test"`
- ✅ Certo: `"repo": "test"`

---

## 📁 ARQUIVOS E PASTAS NA MÁQUINA STAGING

```
C:\
├── configs\
│   └── secrets.json           # Credenciais configuradas ✅
│
├── github-runner\
│   ├── actions-runner-win-x64-2.331.0.zip  # Baixado ✅
│   ├── bin\                   # Extraído ✅
│   ├── config.cmd             # Pronto para usar ⏳
│   ├── run.cmd
│   ├── svc.sh
│   └── ... (outros arquivos)
│
D:\git\StagingLocalRunner\
├── _validado\
│   ├── 01-setup-rdp.ps1          ✅
│   ├── 02-install-dependencies.ps1  ✅
│   ├── 03-setup-github-runner.ps1   ⏳ EM ANDAMENTO
│   ├── CHECKPOINT.md             📄 ESTE ARQUIVO
│   └── PROXIMO-PASSO.md
└── ... (resto do projeto)
```

---

## 🚀 COMO RETOMAR

### Opção 1: Continuar rodando o script 03
```powershell
cd D:\git\StagingLocalRunner\_validado
.\03-setup-github-runner.ps1
```

O script vai:
1. Detectar que network já existe ✅
2. Detectar que secrets.json já existe ✅
3. Carregar credenciais ✅
4. Detectar que runner já está baixado ✅
5. **Configurar o runner** ⏳
6. Instalar como serviço ⏳
7. Iniciar serviço ⏳
8. Validar ⏳

### Opção 2: Configurar manualmente (se script der problema)
```powershell
# 1. Ir para pasta do runner
cd C:\github-runner

# 2. Carregar secrets
$secrets = Get-Content C:\configs\secrets.json | ConvertFrom-Json
$repo = $secrets.github.repo
$token = $secrets.github.token

# 3. Obter registration token
$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3+json"
}
$response = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/actions/runners/registration-token" -Method Post -Headers $headers
$regToken = $response.token

# 4. Configurar
.\config.cmd --url "https://github.com/$repo" --token $regToken --name "staging-local-runner" --work "_work" --labels "self-hosted,Windows,staging" --unattended

# 5. Instalar e iniciar serviço
.\svc.sh install
.\svc.sh start

# 6. Verificar
Get-Service | Where-Object {$_.Name -like "*actions.runner*"}
```

---

## 📝 NOTAS IMPORTANTES

1. **Secrets.json está em `C:\configs\`** (não em `D:\git\...`)
2. **Runner está em `C:\github-runner\`**
3. **Versão do runner: 2.331.0** (lançada em 09/01/2025)
4. **Docker network: staging-network** (já criada)
5. **Script pode ser rodado múltiplas vezes** - ele detecta o que já foi feito

---

## ❓ DÚVIDAS/PROBLEMAS ENCONTRADOS

### Erro no JSON
- ❌ Estava usando `=` ao invés de `:`
- ✅ Corrigido para formato JSON válido

### Runner já configurado
- ❌ Script dava erro ao rodar 2x
- ✅ Adicionada verificação do arquivo `.runner`

### Versão desatualizada
- ❌ Script tinha versão 2.319.1
- ✅ Atualizado para 2.331.0

---

## 🎯 RESUMO DO STATUS

```
┌─────────────────────────────────────┐
│ Setup Máquina Staging               │
├─────────────────────────────────────┤
│ ✅ Windows 11 Pro formatado         │
│ ✅ RDP configurado                  │
│ ✅ IP fixo no UniFi                 │
│ ✅ Git instalado                    │
│ ✅ Docker instalado e rodando       │
│ ✅ Docker network criada            │
│ ✅ Secrets configurados             │
│ ✅ Runner baixado                   │
│ ⏳ Runner - falta configurar        │
│ ⏳ Runner - falta instalar serviço  │
│ ⏳ GitHub Secret - falta criar      │
│ ⏳ Teste de deploy - não feito      │
└─────────────────────────────────────┘
```

**Progresso geral: ~75% completo**

Falta apenas:
1. Configurar e instalar o runner como serviço (15%)
2. Configurar GitHub Secret (5%)
3. Testar deploy (5%)

---

**Quando retomar, comece executando:**
```powershell
cd D:\git\StagingLocalRunner\_validado
.\03-setup-github-runner.ps1
```

O script vai continuar de onde parou automaticamente! ✅
