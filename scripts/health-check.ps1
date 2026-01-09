param(
    [Parameter(Mandatory=$true)]
    [int]$Port,

    [Parameter(Mandatory=$false)]
    [int]$MaxRetries = 10,

    [Parameter(Mandatory=$false)]
    [int]$RetryDelaySeconds = 5
)

$ErrorActionPreference = "Stop"

$url = "http://localhost:$Port/health"

Write-Host "Performing health check on $url" -ForegroundColor Cyan
Write-Host "Max retries: $MaxRetries, Delay: $RetryDelaySeconds seconds" -ForegroundColor Cyan

for ($i = 1; $i -le $MaxRetries; $i++) {
    Write-Host "Attempt $i/$MaxRetries..." -ForegroundColor Yellow

    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing

        if ($response.StatusCode -eq 200) {
            Write-Host "Health check passed!" -ForegroundColor Green
            Write-Host "Response: $($response.Content)" -ForegroundColor Green
            return 0
        }
    }
    catch {
        Write-Host "Health check failed: $($_.Exception.Message)" -ForegroundColor Red

        if ($i -lt $MaxRetries) {
            Write-Host "Waiting $RetryDelaySeconds seconds before retry..." -ForegroundColor Yellow
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}

Write-Host "Health check failed after $MaxRetries attempts" -ForegroundColor Red
exit 1
