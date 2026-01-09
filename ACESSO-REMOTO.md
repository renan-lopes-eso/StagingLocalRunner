# Guia de Acesso Remoto - Máquina de Staging

## Passo a Passo

### 1. Na Máquina de Staging (executar lá)

**Transferir o projeto:**
- Copie a pasta `StaggingLocalRunner` para a máquina de staging

**Executar o script de configuração:**
```powershell
# Abrir PowerShell como Administrador
# Clique com botão direito no PowerShell → "Executar como Administrador"

# Navegar até a pasta do projeto
cd D:\git\StaggingLocalRunner

# Executar o script de setup RDP
.\scripts\setup-rdp.ps1
```

**O script irá:**
- ✅ Habilitar Remote Desktop
- ✅ Configurar firewall
- ✅ Mostrar o IP da máquina
- ✅ Testar se está funcionando
- ✅ Salvar informações em `rdp-connection-info.txt`

**ANOTE O IP MOSTRADO!** Exemplo: `192.168.1.100`

---

### 2. Na Máquina Local (sua máquina atual)

**Testar conectividade:**
```powershell
cd D:\git\StaggingLocalRunner

# Substituir pelo IP da máquina de staging
.\scripts\test-rdp-connection.ps1 -Target 192.168.1.100
```

**Se o teste passar:**
```powershell
# Conectar via RDP
mstsc /v:192.168.1.100
```

Ou pressione `Win + R`, digite `mstsc`, e coloque o IP.

---

## Resolução de Problemas

### ❌ "Porta 3389 não está acessível"

**Causa:** RDP não está habilitado ou firewall bloqueando

**Solução:**
1. Vá até a máquina de staging fisicamente
2. Execute: `.\scripts\setup-rdp.ps1`
3. Teste novamente

---

### ❌ "Não foi possível fazer ping"

**Causa:** ICMP pode estar bloqueado (normal)

**Solução:** Ignore, o importante é a porta 3389 estar acessível

---

### ❌ "Conexão recusada ao tentar logar"

**Causa:** Credenciais incorretas ou NLA bloqueando

**Solução:**
```powershell
# Na máquina de staging, execute com flag:
.\scripts\setup-rdp.ps1 -DisableNLA
```

---

## Configurar IP Fixo (Recomendado)

Para evitar que o IP mude:

### No UniFi Controller

1. Acesse o UniFi Controller (web)
2. **Settings** → **Networks** → **LAN**
3. **DHCP** → **DHCP Server**
4. Clique **Add DHCP Reservation**
5. Selecione a máquina de staging pelo MAC
6. Defina IP fixo: `192.168.1.100` (ou outro)
7. Salve

Agora o IP sempre será o mesmo!

---

## Criar Atalho de Conexão

**Windows:**
1. Botão direito na área de trabalho
2. Novo → Atalho
3. Local: `mstsc /v:192.168.1.100`
4. Nome: "Staging Server"
5. Criar

**Ou criar arquivo `.rdp`:**
```powershell
# Criar arquivo de conexão RDP
$rdpContent = @"
full address:s:192.168.1.100
username:s:USUARIO_DA_STAGING
"@

$rdpContent | Out-File -FilePath "staging-server.rdp" -Encoding ascii
```

Clique duas vezes no arquivo `staging-server.rdp` para conectar rapidamente.

---

## Informações Importantes

### Segurança
- ✅ Funciona apenas na mesma rede WiFi
- ✅ Use senha forte no Windows
- ⚠️ NÃO expor RDP para internet (porta 3389)
- ⚠️ Apenas para uso em rede local confiável

### IPs Comuns em UniFi
- **Padrão UniFi:** `192.168.1.x`
- **Personalizado:** `10.0.x.x` ou `172.16.x.x`

### Portas
- **RDP:** 3389

---

## Scripts Disponíveis

| Script | Local | Descrição |
|--------|-------|-----------|
| `setup-rdp.ps1` | Máquina de staging | Configura RDP |
| `test-rdp-connection.ps1` | Máquina local | Testa conexão |

---

## Checklist Rápido

**Na máquina de staging:**
- [ ] Executar `.\scripts\setup-rdp.ps1` como Admin
- [ ] Anotar o IP mostrado
- [ ] Verificar que "✓ CONFIGURACAO CONCLUIDA" apareceu

**Na máquina local:**
- [ ] Executar `.\scripts\test-rdp-connection.ps1 -Target IP`
- [ ] Verificar que porta 3389 está acessível
- [ ] Conectar via `mstsc /v:IP`
- [ ] Fazer login com credenciais da staging

---

## Próximos Passos

Após conseguir acesso RDP:
1. Instalar pré-requisitos na staging (Docker, .NET, Git)
2. Configurar GitHub Runner
3. Configurar secrets do MySQL
4. Testar primeiro deploy

Consulte o **README.md** para os próximos passos do setup completo do sistema de staging.
