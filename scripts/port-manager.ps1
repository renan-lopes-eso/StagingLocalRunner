param(
    [Parameter(Mandatory=$true)]
    [string]$Branch,

    [Parameter(Mandatory=$true)]
    [ValidateSet("allocate", "release", "get")]
    [string]$Action
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$configPath = Join-Path (Split-Path -Parent $scriptDir) "config\ports.json"
$basePort = 5001
$maxPort = 5100

if (-not (Test-Path (Split-Path -Parent $configPath))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $configPath) -Force | Out-Null
}

if (-not (Test-Path $configPath)) {
    @{} | ConvertTo-Json | Set-Content $configPath
}

$portConfig = Get-Content $configPath | ConvertFrom-Json

switch ($Action) {
    "allocate" {
        if ($portConfig.PSObject.Properties.Name -contains $Branch) {
            $port = $portConfig.$Branch
            Write-Host "Port already allocated for branch $Branch : $port" -ForegroundColor Yellow
            return $port
        }

        $usedPorts = $portConfig.PSObject.Properties.Value
        $availablePort = $basePort

        while ($availablePort -le $maxPort) {
            if ($availablePort -notin $usedPorts) {
                $tcpTest = Test-NetConnection -ComputerName localhost -Port $availablePort -InformationLevel Quiet -WarningAction SilentlyContinue

                if (-not $tcpTest) {
                    $portConfig | Add-Member -MemberType NoteProperty -Name $Branch -Value $availablePort -Force
                    $portConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath

                    Write-Host "Allocated port $availablePort for branch $Branch" -ForegroundColor Green
                    return $availablePort
                }
            }
            $availablePort++
        }

        throw "No available ports in range $basePort-$maxPort"
    }

    "release" {
        if ($portConfig.PSObject.Properties.Name -contains $Branch) {
            $port = $portConfig.$Branch
            $portConfig.PSObject.Properties.Remove($Branch)
            $portConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath

            Write-Host "Released port $port for branch $Branch" -ForegroundColor Green
            return $port
        } else {
            Write-Host "No port allocated for branch $Branch" -ForegroundColor Yellow
            return $null
        }
    }

    "get" {
        if ($portConfig.PSObject.Properties.Name -contains $Branch) {
            return $portConfig.$Branch
        } else {
            Write-Host "No port allocated for branch $Branch" -ForegroundColor Yellow
            return $null
        }
    }
}
