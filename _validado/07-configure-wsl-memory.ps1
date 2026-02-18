# Configura memoria do WSL2/Docker Desktop
# Executar como Administrador

$ErrorActionPreference = "Stop"

# Detectar memoria total do sistema
$totalMemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
Write-Host "Memoria total do Windows: ${totalMemoryGB}GB" -ForegroundColor Cyan

# Sugerir 80% da memoria para o WSL2
$suggestedMemoryGB = [math]::Floor($totalMemoryGB * 0.8)
Write-Host "Memoria sugerida para WSL2 (80%): ${suggestedMemoryGB}GB" -ForegroundColor Cyan

# Perguntar ao usuario
$memoryInput = Read-Host "Quanto de memoria alocar para o WSL2/Docker? (Enter para $suggestedMemoryGB GB)"
if ([string]::IsNullOrWhiteSpace($memoryInput)) {
    $memoryGB = $suggestedMemoryGB
} else {
    $memoryGB = [int]$memoryInput
}

# Caminho do .wslconfig
$wslConfigPath = "$env:USERPROFILE\.wslconfig"

# Conteudo do arquivo
$wslConfig = @"
[wsl2]
memory=${memoryGB}GB
"@

# Criar ou sobrescrever o arquivo
Write-Host "`nCriando $wslConfigPath com memory=${memoryGB}GB..." -ForegroundColor Yellow
$wslConfig | Out-File -FilePath $wslConfigPath -Encoding UTF8 -Force

Write-Host "Arquivo criado com sucesso!" -ForegroundColor Green

# Perguntar se quer reiniciar
$restart = Read-Host "`nReiniciar WSL2 agora? (S/n)"
if ($restart -ne "n" -and $restart -ne "N") {
    Write-Host "`nParando WSL2..." -ForegroundColor Yellow
    wsl --shutdown
    Write-Host "WSL2 parado. Reinicie o Docker Desktop manualmente." -ForegroundColor Green
    Write-Host "`nApos reiniciar o Docker, a memoria disponivel sera ${memoryGB}GB." -ForegroundColor Cyan
} else {
    Write-Host "`nPara aplicar, execute 'wsl --shutdown' e reinicie o Docker Desktop." -ForegroundColor Yellow
}
