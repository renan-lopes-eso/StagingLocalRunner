# Documentacao do Ambiente de Staging

## Arquitetura

```
[GitHub - Org SistemaESO]
         |
[GitHub Actions - Self-hosted Runner]
         |
[Maquina Windows 11 + Docker Desktop (Linux Containers)]
         |
[Caddy :443] --> [Dashboard :5000] --> [Containers :80]
```

**URLs de Acesso:**
- Dashboard: `https://10.0.1.34.nip.io/dashboard`
- Containers: `https://{container-name}.10.0.1.34.nip.io`

---

## Setup da Maquina (ordem de execucao)

| Script | Descricao |
|--------|-----------|
| `02-install-dependencies.ps1` | Chocolatey, Git, Docker Desktop |
| `03-setup-github-runner.ps1` | Runner da organizacao |
| `04-setup-mysql.ps1` | MySQL no Windows (opcional) |
| `05-setup-caddy.ps1` | HTTPS reverse proxy |

**Pre-requisito para o runner:** Criar `C:\configs\secrets.json`:
```json
{ "github": { "token": "github_pat_...", "org": "SistemaESO" } }
```

---

## Dashboard

**Funcionalidades:**
- Secoes: Teampanel, Core, Portal, MySQL, Outros
- Botoes: Abrir, Logs, Parar/Iniciar, Remover
- Criar MySQL via interface
- Copiar connection string
- Exibir commit/autor do deploy

**APIs:**
- `GET /api/containers` - Lista
- `DELETE /api/containers/{name}` - Remove
- `POST /api/containers/{name}/stop` - Para
- `POST /api/containers/{name}/start` - Inicia
- `GET /api/containers/{name}/logs?tail=200` - Logs
- `POST /api/containers/create-mysql` - Criar MySQL

---

## Adicionando Novo Projeto

### 1. Dockerfile
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . ./
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:80
ENTRYPOINT ["dotnet", "MeuProjeto.dll"]
```

### 2. Workflow `.github/workflows/staging-deploy.yml`
```yaml
name: Staging Deploy
on:
  push:
    branches: [staging/**]

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
          $branch = "${{ github.ref_name }}" -replace '[^a-zA-Z0-9]', '-'
          $hash = [Math]::Abs("${{ github.repository }}-$branch".GetHashCode())
          echo "branch_safe=$branch" >> $env:GITHUB_OUTPUT
          echo "port=$(5000 + ($hash % 5000))" >> $env:GITHUB_OUTPUT

      - name: Build
        shell: powershell
        run: docker build -t "PREFIXO:${{ steps.setup.outputs.branch_safe }}" -f Caminho/Dockerfile Caminho/

      - name: Stop old
        shell: powershell
        continue-on-error: true
        run: |
          docker stop "PREFIXO-${{ steps.setup.outputs.branch_safe }}" 2>$null
          docker rm "PREFIXO-${{ steps.setup.outputs.branch_safe }}" 2>$null

      - name: Run
        shell: powershell
        run: |
          $msg = "${{ github.event.head_commit.message }}" -replace '["`]', '' -replace '\r?\n', ' '
          docker run -d `
            --name "PREFIXO-${{ steps.setup.outputs.branch_safe }}" `
            --restart on-failure:3 `
            --network staging-network `
            -p "${{ steps.setup.outputs.port }}:80" `
            --label "commit_short=${{ github.sha }}".Substring(0,7) `
            --label "commit_message=$($msg.Substring(0,[Math]::Min(80,$msg.Length)))" `
            --label "author=${{ github.event.head_commit.author.name }}" `
            --label "branch=${{ github.ref_name }}" `
            -e ASPNETCORE_ENVIRONMENT="${{ secrets.ENV }}" `
            -e CONNECTION="${{ secrets.CONNECTION }}" `
            "PREFIXO:${{ steps.setup.outputs.branch_safe }}"
```

### 3. ForwardedHeaders no Program.cs (obrigatorio)
```csharp
if (app.Environment.IsStaging())
{
    app.UseForwardedHeaders(new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost
    });
}
```

### 4. GitHub
- Criar environment `staging` no repo
- Adicionar secrets necessarios

### 5. Dashboard (se novo prefixo)
Adicionar prefixo em `Program.cs`:
- Array `containerPrefixes`
- Filtro em `/api/containers`

---

## MySQL

**Via Dashboard (recomendado):**
- Criar pelo botao "Novo MySQL"
- Versao, porta e senha configuraveis
- `lower_case_table_names=1` automatico

**Connection string:**
```
Server=mysql-staging;Port=3306;Database=;User=root;Password=;
```

---

## Troubleshooting

| Problema | Solucao |
|----------|---------|
| Container nao aparece | Verificar prefixo no Dashboard |
| Cookie nao salva | Adicionar `UseForwardedHeaders` |
| Redirect sem nip.io | `ForwardedHeadersTransformer` no Dashboard |
| Runner offline | `cd C:\configs\runner; .\run.cmd` |
| Imagens `<none>` | `docker image prune -f` |

---

## Fluxo Git

```bash
git checkout -b staging/feature
git push origin staging/feature   # Deploy automatico
git push origin --delete staging/feature  # Remove container
```
