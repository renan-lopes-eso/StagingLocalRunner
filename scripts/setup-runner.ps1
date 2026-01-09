param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,

    [Parameter(Mandatory=$false)]
    [string]$RunnerName = "staging-local-runner",

    [Parameter(Mandatory=$false)]
    [string]$RunnerPath = "C:\github-runner"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GitHub Self-Hosted Runner Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$repoUrl = git config --get remote.origin.url
$repo = $repoUrl -replace '.*github\.com[:/](.*)\.git', '$1'

Write-Host "Repository: $repo" -ForegroundColor Green
Write-Host "Runner Name: $RunnerName" -ForegroundColor Green
Write-Host "Runner Path: $RunnerPath" -ForegroundColor Green

if (-not (Test-Path $RunnerPath)) {
    New-Item -Path $RunnerPath -ItemType Directory | Out-Null
}

Set-Location $RunnerPath

$runnerVersion = "2.319.1"
$runnerPackage = "actions-runner-win-x64-$runnerVersion.zip"
$runnerUrl = "https://github.com/actions/runner/releases/download/v$runnerVersion/$runnerPackage"

if (-not (Test-Path $runnerPackage)) {
    Write-Host "Downloading GitHub Actions Runner..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerPackage

    Write-Host "Extracting..." -ForegroundColor Yellow
    Expand-Archive -Path $runnerPackage -DestinationPath . -Force
}

Write-Host "Obtaining registration token..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
}
$tokenUrl = "https://api.github.com/repos/$repo/actions/runners/registration-token"
$response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers $headers
$registrationToken = $response.token

Write-Host "Configuring runner..." -ForegroundColor Yellow
& .\config.cmd --url "https://github.com/$repo" --token $registrationToken --name $RunnerName --work _work --labels "self-hosted,Windows,staging"

Write-Host "Installing as Windows service..." -ForegroundColor Yellow
& .\svc.sh install

Write-Host "Starting service..." -ForegroundColor Yellow
& .\svc.sh start

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Runner setup completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Runner is now active and listening for jobs" -ForegroundColor Green
