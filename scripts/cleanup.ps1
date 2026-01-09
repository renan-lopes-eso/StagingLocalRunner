param(
    [Parameter(Mandatory=$false)]
    [int]$MaxAgeDays = 7,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [string]$ActiveBranches = "[]"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$rootPath = Split-Path -Parent $scriptDir
$envConfigPath = Join-Path $rootPath "config\environments.json"
$portConfigPath = Join-Path $rootPath "config\ports.json"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Staging Environment Cleanup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Max Age: $MaxAgeDays days" -ForegroundColor Yellow
Write-Host "Dry Run: $DryRun" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

$activeBranchesList = $ActiveBranches | ConvertFrom-Json

if (-not (Test-Path $envConfigPath)) {
    Write-Host "No environments configuration found" -ForegroundColor Yellow
    exit 0
}

$environments = Get-Content $envConfigPath | ConvertFrom-Json
$portConfig = if (Test-Path $portConfigPath) { Get-Content $portConfigPath | ConvertFrom-Json } else { @{} }

$cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)
$removedCount = 0

foreach ($prop in $environments.PSObject.Properties) {
    $branch = $prop.Name
    $env = $prop.Value

    $deployedAt = [DateTime]::Parse($env.deployedAt)
    $isOld = $deployedAt -lt $cutoffDate
    $isActive = $branch -in $activeBranchesList

    Write-Host "`nBranch: $branch" -ForegroundColor Cyan
    Write-Host "  Deployed: $deployedAt" -ForegroundColor Gray
    Write-Host "  Age: $([Math]::Round((New-TimeSpan -Start $deployedAt -End (Get-Date)).TotalDays, 1)) days" -ForegroundColor Gray
    Write-Host "  Active: $isActive" -ForegroundColor Gray

    if ($isOld -or -not $isActive) {
        Write-Host "  Action: REMOVE" -ForegroundColor Red

        if (-not $DryRun) {
            $containerName = "staging-$($env.branchSafe)"
            Write-Host "  Stopping container: $containerName" -ForegroundColor Yellow

            docker stop $containerName 2>$null
            docker rm $containerName 2>$null

            $imagePattern = "staging-app:$($env.branchSafe)-*"
            docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -like $imagePattern } | ForEach-Object {
                Write-Host "  Removing image: $_" -ForegroundColor Yellow
                docker rmi $_ 2>$null
            }

            if ($portConfig.PSObject.Properties.Name -contains $branch) {
                $portConfig.PSObject.Properties.Remove($branch)
                Write-Host "  Released port: $($env.port)" -ForegroundColor Yellow
            }

            $environments.PSObject.Properties.Remove($branch)

            $composeFile = Join-Path $rootPath "docker-compose.$($env.branchSafe).yml"
            if (Test-Path $composeFile) {
                Remove-Item $composeFile -Force
                Write-Host "  Removed compose file: $composeFile" -ForegroundColor Yellow
            }

            $removedCount++
        }
    } else {
        Write-Host "  Action: KEEP" -ForegroundColor Green
    }
}

if (-not $DryRun) {
    $environments | ConvertTo-Json -Depth 10 | Set-Content $envConfigPath
    $portConfig | ConvertTo-Json -Depth 10 | Set-Content $portConfigPath
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Cleanup Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Environments removed: $removedCount" -ForegroundColor $(if ($removedCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "Active environments: $(($environments.PSObject.Properties | Measure-Object).Count)" -ForegroundColor Green

if ($DryRun) {
    Write-Host "`nThis was a DRY RUN - no changes were made" -ForegroundColor Yellow
}
