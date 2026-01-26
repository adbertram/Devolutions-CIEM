#Requires -Version 7.0

<#
.SYNOPSIS
    Deploy Devolutions CIEM App to Azure-hosted PowerShell Universal
.DESCRIPTION
    This script deploys the CIEM dashboard app to the PSU server running in Azure.
    It uses the PSU Management API to upload the app files.
.PARAMETER PSUServerUrl
    The URL of the PowerShell Universal server
.PARAMETER AppToken
    The PSU App Token for authentication
.PARAMETER Force
    Overwrite existing app if it exists
.EXAMPLE
    ./Deploy-PSUApp.ps1 -PSUServerUrl "https://devolutions-ciem-psu.azurewebsites.net" -AppToken $token
.NOTES
    Author: Adam Bertram
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$PSUServerUrl = 'https://devolutions-ciem-psu.azurewebsites.net',

    [Parameter(Mandatory = $false)]
    [string]$AppToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcy9uYW1lIjoiYWRtaW4iLCJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcy9oYXNoIjoiZTc3MDEwNmEtOGQ0Mi00YTQwLThmNjktZDVlNTg0NTU3YmM5Iiwic3ViIjoiUG93ZXJTaGVsbFVuaXZlcnNhbCIsImh0dHA6Ly9zY2hlbWFzLm1pY3Jvc29mdC5jb20vd3MvMjAwOC8wNi9pZGVudGl0eS9jbGFpbXMvcm9sZSI6IkFkbWluaXN0cmF0b3IiLCJuYmYiOjE3Njk0NDEzNzIsImV4cCI6MTc3MjAzMzM3MiwiaXNzIjoiSXJvbm1hblNvZnR3YXJlIiwiYXVkIjoiUG93ZXJTaGVsbFVuaXZlcnNhbCJ9.R5C7qAUqjncUCgdBzCzZH9zZnYFFqS8JoGc1WO5GkL4',

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Set up authentication headers
$Headers = @{
    'Authorization' = "Bearer $AppToken"
    'Content-Type'  = 'application/json'
}

Write-Host "Deploying Devolutions CIEM App to $PSUServerUrl" -ForegroundColor Cyan

# Get the script root
$ScriptRoot = $PSScriptRoot

# Read the app content
$AppFilePath = Join-Path $ScriptRoot 'apps\DevolutionsCIEM\app.ps1'
$DashboardsFilePath = Join-Path $ScriptRoot '.universal\dashboards.ps1'

if (-not (Test-Path $AppFilePath)) {
    throw "App file not found: $AppFilePath"
}

$AppContent = Get-Content $AppFilePath -Raw

Write-Host "App content loaded from: $AppFilePath" -ForegroundColor Green

# Check if app already exists
try {
    $ExistingApps = Invoke-RestMethod -Uri "$PSUServerUrl/api/v1/dashboard" -Headers $Headers -Method Get
    $ExistingApp = $ExistingApps | Where-Object { $_.Name -eq 'DevolutionsCIEM' }

    if ($ExistingApp) {
        if ($Force) {
            Write-Host "Removing existing app..." -ForegroundColor Yellow
            Invoke-RestMethod -Uri "$PSUServerUrl/api/v1/dashboard/$($ExistingApp.Id)" -Headers $Headers -Method Delete
            Write-Host "Existing app removed." -ForegroundColor Green
        } else {
            throw "App 'DevolutionsCIEM' already exists. Use -Force to overwrite."
        }
    }
} catch {
    if ($_.Exception.Response.StatusCode -ne 404) {
        Write-Warning "Could not check for existing apps: $_"
    }
}

# Create the app via API
$AppPayload = @{
    Name        = 'DevolutionsCIEM'
    BaseUrl     = '/ciem'
    Description = 'Cloud Infrastructure Entitlement Management - Security Findings Dashboard'
    Content     = $AppContent
    AutoDeploy  = $true
} | ConvertTo-Json -Depth 10

Write-Host "Creating app via Management API..." -ForegroundColor Cyan

try {
    $Response = Invoke-RestMethod -Uri "$PSUServerUrl/api/v1/dashboard" -Headers $Headers -Method Post -Body $AppPayload
    Write-Host "App created successfully!" -ForegroundColor Green
    Write-Host "App ID: $($Response.Id)" -ForegroundColor Green
    Write-Host "Access the app at: $PSUServerUrl/ciem" -ForegroundColor Cyan
} catch {
    Write-Error "Failed to create app: $_"
    Write-Host "Response: $($_.Exception.Response)" -ForegroundColor Red
    throw
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nApp URL: $PSUServerUrl/ciem" -ForegroundColor Yellow
Write-Host "Admin Console: $PSUServerUrl/admin" -ForegroundColor Yellow
