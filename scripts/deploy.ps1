param(
    [Parameter(Mandatory=$true)]
    [string]$Branch,

    [Parameter(Mandatory=$true)]
    [string]$BranchSafe,

    [Parameter(Mandatory=$true)]
    [string]$CommitSha,

    [Parameter(Mandatory=$true)]
    [string]$CommitShaShort,

    [Parameter(Mandatory=$true)]
    [int]$Port,

    [Parameter(Mandatory=$true)]
    [string]$ConnectionString
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$rootPath = Split-Path -Parent $scriptDir
$templatePath = Join-Path $rootPath "docker\docker-compose.template.yml"
$outputPath = Join-Path $rootPath "docker-compose.$BranchSafe.yml"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploying staging environment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Branch: $Branch" -ForegroundColor Green
Write-Host "Branch Safe: $BranchSafe" -ForegroundColor Green
Write-Host "Commit: $CommitShaShort" -ForegroundColor Green
Write-Host "Port: $Port" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

$template = Get-Content $templatePath -Raw

$deployedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
$appVersion = "1.0.0"

$compose = $template `
    -replace '\{BRANCH_NAME\}', $Branch `
    -replace '\{BRANCH_SAFE_NAME\}', $BranchSafe `
    -replace '\{COMMIT_SHA\}', $CommitSha `
    -replace '\{COMMIT_SHA_SHORT\}', $CommitShaShort `
    -replace '\{DEPLOYED_AT\}', $deployedAt `
    -replace '\{APP_VERSION\}', $appVersion `
    -replace '\{HOST_PORT\}', $Port `
    -replace '\{DATABASE_CONNECTION_STRING\}', $ConnectionString

$compose | Set-Content $outputPath -Encoding UTF8

Write-Host "Docker Compose file generated: $outputPath" -ForegroundColor Green

$networkExists = docker network ls --format "{{.Name}}" | Where-Object { $_ -eq "staging-network" }
if (-not $networkExists) {
    Write-Host "Creating staging-network..." -ForegroundColor Yellow
    docker network create staging-network
}

Write-Host "Starting container..." -ForegroundColor Yellow
docker compose -f $outputPath up -d

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Container: staging-$BranchSafe" -ForegroundColor Green
Write-Host "Port: $Port" -ForegroundColor Green
Write-Host "URL: http://localhost:$Port" -ForegroundColor Green
Write-Host "Traefik URL: http://staging.local/$BranchSafe" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
