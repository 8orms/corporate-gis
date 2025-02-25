<#
.SYNOPSIS
    Monitors and reports on the health of GeoServer instances and associated services.

.DESCRIPTION
    This script performs comprehensive health checks on GeoServer Vector and ECW instances,
    NGINX configuration, Docker container status, and service availability. It can be run
    as a scheduled task or manually to ensure all components are functioning correctly.

.PARAMETER CheckInterval
    Specifies the interval in seconds between health checks when run in continuous mode.
    Default is 300 seconds (5 minutes).

.PARAMETER OutputFile
    Path to save the health check results. If not specified, results are only displayed
    in the console.

.PARAMETER Continuous
    Runs the script in continuous monitoring mode, performing checks at the specified interval.

.PARAMETER FixIssues
    Attempts to automatically fix common issues detected during health checks.

.PARAMETER EmailOnFailure
    If specified, sends an email notification when critical issues are detected.

.PARAMETER EmailRecipient
    Email address to send notifications to when EmailOnFailure is enabled.

.EXAMPLE
    .\monitor-geoserver-health.ps1
    Performs a single health check and displays results in the console.

.EXAMPLE
    .\monitor-geoserver-health.ps1 -OutputFile "logs\health-check.log"
    Performs a health check and saves results to the specified log file.

.EXAMPLE
    .\monitor-geoserver-health.ps1 -Continuous -CheckInterval 600
    Runs continuous monitoring, checking health every 10 minutes.

.EXAMPLE
    .\monitor-geoserver-health.ps1 -FixIssues
    Performs a health check and attempts to fix any detected issues.

.NOTES
    Author: GIS Platform Team
    Last Modified: March 2025
    Requirements: PowerShell 5.1 or later, Docker, curl
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$CheckInterval = 300,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputFile,
    
    [Parameter(Mandatory = $false)]
    [switch]$Continuous,
    
    [Parameter(Mandatory = $false)]
    [switch]$FixIssues,
    
    [Parameter(Mandatory = $false)]
    [switch]$EmailOnFailure,
    
    [Parameter(Mandatory = $false)]
    [string]$EmailRecipient
)

# Initialize script
$ErrorActionPreference = "Stop"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = (Get-Item $scriptPath).Parent.FullName
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$healthCheckResults = @()
$criticalIssuesDetected = $false

# Define ANSI color codes for console output
$colorReset = "`e[0m"
$colorRed = "`e[31m"
$colorGreen = "`e[32m"
$colorYellow = "`e[33m"
$colorBlue = "`e[36m"

# Enum for service status
enum ServiceStatus {
    OK
    Warning
    Critical
    Unknown
}

# Minimum required docker-compose version
$minDockerComposeVersion = [Version]"1.29.0"

# Import modules or define functions
function Write-HealthLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ServiceStatus]$Status = [ServiceStatus]::Unknown,
        
        [Parameter(Mandatory = $false)]
        [switch]$NoOutput
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $statusText = switch ($Status) {
        ([ServiceStatus]::OK) { "${colorGreen}[OK]${colorReset}" }
        ([ServiceStatus]::Warning) { "${colorYellow}[WARNING]${colorReset}" }
        ([ServiceStatus]::Critical) { "${colorRed}[CRITICAL]${colorReset}" }
        default { "[INFO]" }
    }
    
    $logMessage = "[$timestamp] $statusText $Message"
    
    # Add to results array
    $script:healthCheckResults += $logMessage
    
    # Output to console if not suppressed
    if (-not $NoOutput) {
        Write-Host $logMessage
    }
    
    # Output to file if specified
    if ($OutputFile) {
        $logMessage -replace "\`e\[\d+m", "" | Out-File -Append -FilePath $OutputFile
    }
    
    # Set critical flag if this is a critical issue
    if ($Status -eq [ServiceStatus]::Critical) {
        $script:criticalIssuesDetected = $true
    }
}

function Test-Command {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    if (Get-Command $Name -ErrorAction SilentlyContinue) {
        return $true
    }
    return $false
}

function Test-DockerRunning {
    [CmdletBinding()]
    try {
        $dockerInfo = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Test-DockerComposeVersion {
    [CmdletBinding()]
    try {
        $versionOutput = docker-compose --version 2>&1
        if ($versionOutput -match '(\d+\.\d+\.\d+)') {
            $version = [Version]$Matches[1]
            if ($version -ge $minDockerComposeVersion) {
                return $true
            }
        }
        return $false
    }
    catch {
        return $false
    }
}

function Test-ContainerRunning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName
    )
    
    try {
        $containerStatus = docker ps --filter "name=$ContainerName" --format "{{.Status}}"
        if ($containerStatus -match "Up") {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Get-ContainerHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName
    )
    
    try {
        $health = docker inspect --format="{{.State.Health.Status}}" $ContainerName 2>&1
        if ($LASTEXITCODE -ne 0) {
            return "unknown"
        }
        return $health
    }
    catch {
        return "unknown"
    }
}

function Test-HttpEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $false)]
        [int]$ExpectedStatusCode = 200
    )
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -Method HEAD -TimeoutSec 10
        return @{
            Success = ($response.StatusCode -eq $ExpectedStatusCode)
            StatusCode = $response.StatusCode
            Message = "Received status code $($response.StatusCode), expected $ExpectedStatusCode"
        }
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            return @{
                Success = ($statusCode -eq $ExpectedStatusCode)
                StatusCode = $statusCode
                Message = "Received status code $statusCode, expected $ExpectedStatusCode"
            }
        }
        return @{
            Success = $false
            StatusCode = 0
            Message = "Connection error: $($_.Exception.Message)"
        }
    }
    catch {
        return @{
            Success = $false
            StatusCode = 0
            Message = "Error: $($_.Exception.Message)"
        }
    }
}

function Test-GeoServerCatalinaOpts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName,
        
        [Parameter(Mandatory = $true)]
        [string]$ExpectedBaseUrl
    )
    
    try {
        $envVars = docker exec $ContainerName env | Out-String
        
        $catalina = if ($envVars -match "CATALINA_OPTS=(.+)") {
            $Matches[1]
        } else {
            ""
        }
        
        $hasProxyBase = $catalina -match "-Dorg\.geoserver\.web\.proxy\.base=$ExpectedBaseUrl"
        $hasHeaderProxy = $catalina -match "-Dorg\.geoserver\.use\.header\.proxy=true"
        $hasCsrfDisabled = $catalina -match "-DGEOSERVER_CSRF_DISABLED=true"
        
        return @{
            HasProxyBase = $hasProxyBase
            HasHeaderProxy = $hasHeaderProxy
            HasCsrfDisabled = $hasCsrfDisabled
            CatalinaOpts = $catalina
        }
    }
    catch {
        return @{
            HasProxyBase = $false
            HasHeaderProxy = $false
            HasCsrfDisabled = $false
            CatalinaOpts = ""
            Error = $_.Exception.Message
        }
    }
}

function Test-NginxConfiguration {
    [CmdletBinding()]
    param()
    
    try {
        $result = docker exec nginx nginx -t 2>&1
        $isValid = $LASTEXITCODE -eq 0
        
        return @{
            IsValid = $isValid
            Output = $result
        }
    }
    catch {
        return @{
            IsValid = $false
            Output = $_.Exception.Message
        }
    }
}

function Check-NginxLocationBlocks {
    [CmdletBinding()]
    param()
    
    try {
        $configContent = docker exec nginx cat /etc/nginx/conf.d/default.conf 2>&1
        if ($LASTEXITCODE -ne 0) {
            return @{
                IsValid = $false
                MissingBlocks = @("Could not read NGINX configuration")
                Output = $configContent
            }
        }
        
        $requiredLocationBlocks = @(
            "/geoserver/vector/web/",
            "/geoserver/vector/",
            "/geoserver/ecw/web/",
            "/geoserver/ecw/",
            "= /geoserver/",
            "= /geoserver/web/"
        )
        
        $missingBlocks = @()
        foreach ($block in $requiredLocationBlocks) {
            if ($configContent -notmatch "location\s+$([regex]::Escape($block))") {
                $missingBlocks += $block
            }
        }
        
        return @{
            IsValid = ($missingBlocks.Count -eq 0)
            MissingBlocks = $missingBlocks
            Output = $configContent
        }
    }
    catch {
        return @{
            IsValid = $false
            MissingBlocks = @("Error analyzing NGINX configuration")
            Output = $_.Exception.Message
        }
    }
}

function Restart-Container {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName
    )
    
    try {
        $result = docker-compose restart $ContainerName 2>&1
        return @{
            Success = ($LASTEXITCODE -eq 0)
            Output = $result
        }
    }
    catch {
        return @{
            Success = $false
            Output = $_.Exception.Message
        }
    }
}

function Fix-GeoServerCatalinaOpts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceType, # "vector" or "ecw"
        
        [Parameter(Mandatory = $true)]
        [string]$ExpectedBaseUrl
    )
    
    try {
        # Read docker-compose.yml
        $composeFile = Join-Path $rootDir "config/docker/dev/docker-compose.yml"
        $content = Get-Content -Path $composeFile -Raw
        
        # Create backup
        $backupFile = $composeFile + ".bak"
        Copy-Item -Path $composeFile -Destination $backupFile -Force
        
        # Extract and replace CATALINA_OPTS
        $servicePattern = if ($InstanceType -eq "vector") {
            "(?s)geoserver-vector:.*?environment:.*?CATALINA_OPTS=(.*?)(?:\r?\n\s*-|\r?\n\s*\w)"
        } else {
            "(?s)geoserver-ecw:.*?environment:.*?CATALINA_OPTS=(.*?)(?:\r?\n\s*-|\r?\n\s*\w)"
        }
        
        if ($content -match $servicePattern) {
            $currentOpts = $Matches[1]
            
            # Fix the proxy base URL
            $newOpts = if ($currentOpts -match "-Dorg\.geoserver\.web\.proxy\.base=([^\s]*)") {
                $currentOpts -replace "-Dorg\.geoserver\.web\.proxy\.base=[^\s]*", "-Dorg.geoserver.web.proxy.base=$ExpectedBaseUrl"
            } else {
                $currentOpts + " -Dorg.geoserver.web.proxy.base=$ExpectedBaseUrl"
            }
            
            # Ensure header proxy is enabled
            $newOpts = if ($newOpts -notmatch "-Dorg\.geoserver\.use\.header\.proxy=true") {
                $newOpts + " -Dorg.geoserver.use.header.proxy=true"
            } else {
                $newOpts
            }
            
            # Ensure CSRF is disabled
            $newOpts = if ($newOpts -notmatch "-DGEOSERVER_CSRF_DISABLED=true") {
                $newOpts + " -DGEOSERVER_CSRF_DISABLED=true"
            } else {
                $newOpts
            }
            
            # Update the content
            $updatedContent = $content -replace [regex]::Escape($currentOpts), $newOpts
            Set-Content -Path $composeFile -Value $updatedContent
            
            return @{
                Success = $true
                PreviousOpts = $currentOpts
                NewOpts = $newOpts
                Message = "Updated CATALINA_OPTS for geoserver-$InstanceType"
            }
        } else {
            return @{
                Success = $false
                Message = "Could not find CATALINA_OPTS for geoserver-$InstanceType in docker-compose.yml"
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error updating CATALINA_OPTS: $($_.Exception.Message)"
        }
    }
}

function Check-DiskSpace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$WarningThreshold = 85,
        
        [Parameter(Mandatory = $false)]
        [int]$CriticalThreshold = 95
    )
    
    try {
        $volumes = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null -and $_.Free -ne $null }
        $results = @()
        
        foreach ($volume in $volumes) {
            $total = $volume.Used + $volume.Free
            $percentUsed = [Math]::Round(($volume.Used / $total) * 100, 2)
            
            $status = [ServiceStatus]::OK
            if ($percentUsed -ge $CriticalThreshold) {
                $status = [ServiceStatus]::Critical
            } elseif ($percentUsed -ge $WarningThreshold) {
                $status = [ServiceStatus]::Warning
            }
            
            $results += @{
                Drive = $volume.Name
                PercentUsed = $percentUsed
                FreeGB = [Math]::Round($volume.Free / 1GB, 2)
                TotalGB = [Math]::Round(($volume.Used + $volume.Free) / 1GB, 2)
                Status = $status
            }
        }
        
        return $results
    }
    catch {
        return @(
            @{
                Drive = "Error"
                PercentUsed = 0
                FreeGB = 0
                TotalGB = 0
                Status = [ServiceStatus]::Unknown
                Error = $_.Exception.Message
            }
        )
    }
}

function Check-DockerDiskUsage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$WarningThreshold = 10,  # GB
        
        [Parameter(Mandatory = $false)]
        [int]$CriticalThreshold = 20  # GB
    )
    
    try {
        $usageInfo = docker system df -v 2>&1
        
        # Extract total disk usage
        $totalSize = if ($usageInfo -match "Total:\s+(\d+(\.\d+)?)\s*(GB|MB|KB)") {
            $size = [double]$Matches[1]
            $unit = $Matches[3]
            
            # Convert to GB
            switch ($unit) {
                "KB" { $size = $size / (1024 * 1024) }
                "MB" { $size = $size / 1024 }
            }
            
            $size
        } else {
            0
        }
        
        $status = [ServiceStatus]::OK
        if ($totalSize -ge $CriticalThreshold) {
            $status = [ServiceStatus]::Critical
        } elseif ($totalSize -ge $WarningThreshold) {
            $status = [ServiceStatus]::Warning
        }
        
        return @{
            TotalGB = [Math]::Round($totalSize, 2)
            Status = $status
            Details = $usageInfo
        }
    }
    catch {
        return @{
            TotalGB = 0
            Status = [ServiceStatus]::Unknown
            Error = $_.Exception.Message
        }
    }
}

function Send-EmailAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Recipient,
        
        [Parameter(Mandatory = $true)]
        [string]$Subject,
        
        [Parameter(Mandatory = $true)]
        [string]$Body
    )
    
    try {
        # Configure your SMTP server settings here
        $smtpServer = "smtp.example.com"
        $smtpPort = 587
        $smtpUsername = "alerts@example.com"
        $smtpPassword = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential ($smtpUsername, $smtpPassword)
        
        Send-MailMessage -From "GIS Platform Alerts <alerts@example.com>" `
            -To $Recipient `
            -Subject $Subject `
            -Body $Body `
            -SmtpServer $smtpServer `
            -Port $smtpPort `
            -Credential $credential `
            -UseSsl
            
        return @{
            Success = $true
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Run-HealthCheck {
    [CmdletBinding()]
    param()
    
    $script:healthCheckResults = @()
    $script:criticalIssuesDetected = $false
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Write-HealthLog "${colorBlue}Starting GeoServer Health Check - $timestamp${colorReset}"
    Write-HealthLog "Environment: $(Get-Location)"
    
    # Check prerequisites
    Write-HealthLog "Checking prerequisites..."
    
    if (-not (Test-Command -Name "docker")) {
        Write-HealthLog "Docker is not installed or not in PATH" -Status ([ServiceStatus]::Critical)
        return
    }
    
    if (-not (Test-Command -Name "docker-compose")) {
        Write-HealthLog "Docker Compose is not installed or not in PATH" -Status ([ServiceStatus]::Critical)
        return
    }
    
    if (-not (Test-DockerRunning)) {
        Write-HealthLog "Docker service is not running" -Status ([ServiceStatus]::Critical)
        return
    }
    
    if (-not (Test-DockerComposeVersion)) {
        Write-HealthLog "Docker Compose version is below minimum required ($minDockerComposeVersion)" -Status ([ServiceStatus]::Warning)
    } else {
        Write-HealthLog "Docker Compose version is adequate" -Status ([ServiceStatus]::OK)
    }
    
    # Check container status
    Write-HealthLog "Checking container status..."
    
    $containers = @("postgis", "geoserver-vector", "geoserver-ecw", "nginx")
    foreach ($container in $containers) {
        if (Test-ContainerRunning -ContainerName $container) {
            $health = Get-ContainerHealth -ContainerName $container
            
            switch ($health) {
                "healthy" {
                    Write-HealthLog "Container $container is running and healthy" -Status ([ServiceStatus]::OK)
                }
                "unhealthy" {
                    Write-HealthLog "Container $container is unhealthy" -Status ([ServiceStatus]::Critical)
                }
                default {
                    Write-HealthLog "Container $container is running (health: $health)" -Status ([ServiceStatus]::OK)
                }
            }
        } else {
            Write-HealthLog "Container $container is not running" -Status ([ServiceStatus]::Critical)
        }
    }
    
    # Check NGINX configuration
    Write-HealthLog "Checking NGINX configuration..."
    
    $nginxConfigTest = Test-NginxConfiguration
    if ($nginxConfigTest.IsValid) {
        Write-HealthLog "NGINX configuration is valid" -Status ([ServiceStatus]::OK)
    } else {
        Write-HealthLog "NGINX configuration is invalid: $($nginxConfigTest.Output)" -Status ([ServiceStatus]::Critical)
    }
    
    $nginxLocationCheck = Check-NginxLocationBlocks
    if ($nginxLocationCheck.IsValid) {
        Write-HealthLog "NGINX location blocks for GeoServer are properly configured" -Status ([ServiceStatus]::OK)
    } else {
        Write-HealthLog "NGINX is missing required location blocks: $($nginxLocationCheck.MissingBlocks -join ', ')" -Status ([ServiceStatus]::Critical)
    }
    
    # Check GeoServer Vector configuration
    Write-HealthLog "Checking GeoServer Vector configuration..."
    
    if (Test-ContainerRunning -ContainerName "geoserver-vector") {
        $vectorCatalinaCheck = Test-GeoServerCatalinaOpts -ContainerName "geoserver-vector" -ExpectedBaseUrl "http://localhost/geoserver/vector/web"
        
        if ($vectorCatalinaCheck.HasProxyBase) {
            Write-HealthLog "GeoServer Vector has correct proxy base URL" -Status ([ServiceStatus]::OK)
        } else {
            Write-HealthLog "GeoServer Vector is missing or has incorrect proxy base URL" -Status ([ServiceStatus]::Critical)
        }
        
        if ($vectorCatalinaCheck.HasHeaderProxy) {
            Write-HealthLog "GeoServer Vector has header proxy enabled" -Status ([ServiceStatus]::OK)
        } else {
            Write-HealthLog "GeoServer Vector is missing header proxy setting" -Status ([ServiceStatus]::Warning)
        }
        
        if ($vectorCatalinaCheck.HasCsrfDisabled) {
            Write-HealthLog "GeoServer Vector has CSRF protection disabled" -Status ([ServiceStatus]::OK)
        } else {
            Write-HealthLog "GeoServer Vector has CSRF protection enabled, which may cause issues with POST requests" -Status ([ServiceStatus]::Warning)
        }
    }
    
    # Check GeoServer ECW configuration
    Write-HealthLog "Checking GeoServer ECW configuration..."
    
    if (Test-ContainerRunning -ContainerName "geoserver-ecw") {
        $ecwCatalinaCheck = Test-GeoServerCatalinaOpts -ContainerName "geoserver-ecw" -ExpectedBaseUrl "http://localhost/geoserver/ecw/web"
        
        if ($ecwCatalinaCheck.HasProxyBase) {
            Write-HealthLog "GeoServer ECW has correct proxy base URL" -Status ([ServiceStatus]::OK)
        } else {
            Write-HealthLog "GeoServer ECW is missing or has incorrect proxy base URL" -Status ([ServiceStatus]::Critical)
        }
        
        if ($ecwCatalinaCheck.HasHeaderProxy) {
            Write-HealthLog "GeoServer ECW has header proxy enabled" -Status ([ServiceStatus]::OK)
        } else {
            Write-HealthLog "GeoServer ECW is missing header proxy setting" -Status ([ServiceStatus]::Warning)
        }
        
        if ($ecwCatalinaCheck.HasCsrfDisabled) {
            Write-HealthLog "GeoServer ECW has CSRF protection disabled" -Status ([ServiceStatus]::OK)
        } else {
            Write-HealthLog "GeoServer ECW has CSRF protection enabled, which may cause issues with POST requests" -Status ([ServiceStatus]::Warning)
        }
    }
    
    # Check service endpoints
    Write-HealthLog "Checking service endpoints..."
    
    $endpoints = @(
        @{ Name = "NGINX Health"; Url = "http://localhost/health"; ExpectedStatus = 200 },
        @{ Name = "GeoServer Vector Web UI"; Url = "http://localhost/geoserver/vector/web/"; ExpectedStatus = 200 },
        @{ Name = "GeoServer ECW Web UI"; Url = "http://localhost/geoserver/ecw/web/"; ExpectedStatus = 200 },
        @{ Name = "GeoServer Vector WMS"; Url = "http://localhost/geoserver/vector/wms?service=WMS&version=1.1.0&request=GetCapabilities"; ExpectedStatus = 200 },
        @{ Name = "GeoServer ECW WMS"; Url = "http://localhost/geoserver/ecw/wms?service=WMS&version=1.1.0&request=GetCapabilities"; ExpectedStatus = 200 }
    )
    
    foreach ($endpoint in $endpoints) {
        $result = Test-HttpEndpoint -Url $endpoint.Url -ExpectedStatusCode $endpoint.ExpectedStatus
        
        if ($result.Success) {
            Write-HealthLog "$($endpoint.Name) is accessible (Status: $($result.StatusCode))" -Status ([ServiceStatus]::OK)
        } else {
            $status = if ($result.StatusCode -eq 0) { 
                [ServiceStatus]::Critical 
            } else { 
                [ServiceStatus]::Warning 
            }
            
            Write-HealthLog "$($endpoint.Name) check failed: $($result.Message)" -Status $status
        }
    }
    
    # Check disk space
    Write-HealthLog "Checking disk space..."
    
    $diskSpaceResults = Check-DiskSpace
    foreach ($drive in $diskSpaceResults) {
        if ($drive.Drive -ne "Error") {
            $message = "Drive $($drive.Drive): $($drive.PercentUsed)% used, $($drive.FreeGB) GB free of $($drive.TotalGB) GB"
            Write-HealthLog $message -Status $drive.Status
        } else {
            Write-HealthLog "Error checking disk space: $($drive.Error)" -Status ([ServiceStatus]::Warning)
        }
    }
    
    # Check Docker disk usage
    $dockerDiskUsage = Check-DockerDiskUsage
    if ($dockerDiskUsage.Status -ne [ServiceStatus]::Unknown) {
        Write-HealthLog "Docker disk usage: $($dockerDiskUsage.TotalGB) GB" -Status $dockerDiskUsage.Status
    } else {
        Write-HealthLog "Error checking Docker disk usage: $($dockerDiskUsage.Error)" -Status ([ServiceStatus]::Warning)
    }
    
    # Apply fixes if requested
    if ($FixIssues -and $script:criticalIssuesDetected) {
        Write-HealthLog "${colorYellow}Attempting to fix detected issues...${colorReset}"
        
        # Fix GeoServer Vector CATALINA_OPTS if needed
        if (Test-ContainerRunning -ContainerName "geoserver-vector") {
            $vectorCatalinaCheck = Test-GeoServerCatalinaOpts -ContainerName "geoserver-vector" -ExpectedBaseUrl "http://localhost/geoserver/vector/web"
            
            if (-not $vectorCatalinaCheck.HasProxyBase -or -not $vectorCatalinaCheck.HasHeaderProxy -or -not $vectorCatalinaCheck.HasCsrfDisabled) {
                Write-HealthLog "Fixing GeoServer Vector CATALINA_OPTS..."
                
                $fixResult = Fix-GeoServerCatalinaOpts -InstanceType "vector" -ExpectedBaseUrl "http://localhost/geoserver/vector/web"
                
                if ($fixResult.Success) {
                    Write-HealthLog "Successfully updated CATALINA_OPTS for GeoServer Vector. Restarting container..." -Status ([ServiceStatus]::OK)
                    $restartResult = Restart-Container -ContainerName "geoserver-vector"
                    
                    if ($restartResult.Success) {
                        Write-HealthLog "GeoServer Vector restarted successfully" -Status ([ServiceStatus]::OK)
                    } else {
                        Write-HealthLog "Failed to restart GeoServer Vector: $($restartResult.Output)" -Status ([ServiceStatus]::Critical)
                    }
                } else {
                    Write-HealthLog "Failed to update CATALINA_OPTS for GeoServer Vector: $($fixResult.Message)" -Status ([ServiceStatus]::Critical)
                }
            }
        }
        
        # Fix GeoServer ECW CATALINA_OPTS if needed
        if (Test-ContainerRunning -ContainerName "geoserver-ecw") {
            $ecwCatalinaCheck = Test-GeoServerCatalinaOpts -ContainerName "geoserver-ecw" -ExpectedBaseUrl "http://localhost/geoserver/ecw/web"
            
            if (-not $ecwCatalinaCheck.HasProxyBase -or -not $ecwCatalinaCheck.HasHeaderProxy -or -not $ecwCatalinaCheck.HasCsrfDisabled) {
                Write-HealthLog "Fixing GeoServer ECW CATALINA_OPTS..."
                
                $fixResult = Fix-GeoServerCatalinaOpts -InstanceType "ecw" -ExpectedBaseUrl "http://localhost/geoserver/ecw/web"
                
                if ($fixResult.Success) {
                    Write-HealthLog "Successfully updated CATALINA_OPTS for GeoServer ECW. Restarting container..." -Status ([ServiceStatus]::OK)
                    $restartResult = Restart-Container -ContainerName "geoserver-ecw"
                    
                    if ($restartResult.Success) {
                        Write-HealthLog "GeoServer ECW restarted successfully" -Status ([ServiceStatus]::OK)
                    } else {
                        Write-HealthLog "Failed to restart GeoServer ECW: $($restartResult.Output)" -Status ([ServiceStatus]::Critical)
                    }
                } else {
                    Write-HealthLog "Failed to update CATALINA_OPTS for GeoServer ECW: $($fixResult.Message)" -Status ([ServiceStatus]::Critical)
                }
            }
        }
    }
    
    # Send email if critical issues were detected and email notification is enabled
    if ($script:criticalIssuesDetected -and $EmailOnFailure -and $EmailRecipient) {
        $subject = "GIS Platform Alert: Critical Issues Detected"
        $body = "The following critical issues were detected during the health check at $timestamp:`n`n"
        $body += ($script:healthCheckResults -join "`n")
        
        $emailResult = Send-EmailAlert -Recipient $EmailRecipient -Subject $subject -Body $body
        
        if ($emailResult.Success) {
            Write-HealthLog "Email notification sent to $EmailRecipient" -Status ([ServiceStatus]::OK)
        } else {
            Write-HealthLog "Failed to send email notification: $($emailResult.Error)" -Status ([ServiceStatus]::Warning)
        }
    }
    
    Write-HealthLog "${colorBlue}Health check completed${colorReset}"
    
    # Return summary
    return @{
        Timestamp = $timestamp
        CriticalIssuesDetected = $script:criticalIssuesDetected
        Results = $script:healthCheckResults
    }
}

# Main execution
if ($OutputFile) {
    # Ensure the log directory exists
    $logDir = Split-Path -Parent $OutputFile
    if (-not (Test-Path -Path $logDir)) {
        try {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            Write-Host "Created log directory: $logDir"
        }
        catch {
            Write-Error "Failed to create log directory: $($_.Exception.Message)"
            exit 1
        }
    }
    
    # Clear the log file if it exists
    if (Test-Path -Path $OutputFile) {
        Clear-Content -Path $OutputFile
    }
}

if ($Continuous) {
    Write-Host "Starting continuous monitoring. Press Ctrl+C to stop."
    
    try {
        while ($true) {
            $result = Run-HealthCheck
            
            Write-Host "Sleeping for $CheckInterval seconds until next check..."
            Start-Sleep -Seconds $CheckInterval
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        Write-Host "Monitoring stopped."
    }
    catch {
        Write-Error "Error in continuous monitoring: $($_.Exception.Message)"
    }
} else {
    Run-HealthCheck
} 