<#
.SYNOPSIS
    Initializes Git repository and makes initial commit for the Corporate GIS Platform.

.DESCRIPTION
    This script handles the complete initialization of a Git repository for the
    Corporate GIS Platform project. It performs the following tasks:
    1. Checks if Git is installed
    2. Initializes a Git repository if one doesn't exist
    3. Creates a comprehensive .gitignore file for GIS projects
    4. Adds all relevant files to the repository
    5. Makes an initial commit
    6. Optionally configures a remote repository
    7. Optionally pushes to the remote repository

.PARAMETER ConfigureRemote
    If specified, configures a remote repository using the provided RemoteUrl.

.PARAMETER RemoteUrl
    URL of the remote Git repository (e.g., https://github.com/username/corporate-gis.git).
    Required if ConfigureRemote is specified.

.PARAMETER RemoteName
    Name of the remote repository. Default is 'origin'.

.PARAMETER BranchName
    Name of the main branch. Default is 'main'.

.PARAMETER Push
    If specified, pushes the initial commit to the remote repository.

.EXAMPLE
    .\initialize-git-repo.ps1
    
    Initializes the Git repository and makes an initial commit.

.EXAMPLE
    .\initialize-git-repo.ps1 -ConfigureRemote -RemoteUrl "https://github.com/username/corporate-gis.git" -Push
    
    Initializes the Git repository, makes an initial commit, configures the remote repository,
    and pushes the initial commit.

.NOTES
    Author: GIS Platform Team
    Last Modified: March 2025
    Requirements: Git, PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ConfigureRemote,
    
    [Parameter(Mandatory = $false)]
    [string]$RemoteUrl,
    
    [Parameter(Mandatory = $false)]
    [string]$RemoteName = "origin",
    
    [Parameter(Mandatory = $false)]
    [string]$BranchName = "main",
    
    [Parameter(Mandatory = $false)]
    [switch]$Push
)

# Function to check if Git is installed
function Test-GitInstalled {
    try {
        $gitVersion = git --version
        return $true
    }
    catch {
        return $false
    }
}

# Function to check if the current directory is inside a Git repository
function Test-GitRepository {
    try {
        $gitStatus = git rev-parse --is-inside-work-tree 2>$null
        return ($gitStatus -eq "true")
    }
    catch {
        return $false
    }
}

# Function to create a .gitignore file for GIS project
function New-GitIgnore {
    $gitIgnoreContent = @"
# Data directories
/data/postgis/**
/data/raster-storage/**
/data/vector-storage/**
!/data/postgis/.gitkeep
!/data/raster-storage/.gitkeep
!/data/vector-storage/.gitkeep

# GeoServer data directories
/data/geoserver/**
!/data/geoserver/vector/data_dir/.gitkeep
!/data/geoserver/ecw/data_dir/.gitkeep

# User projections
/data/user-projections/**
!/data/user-projections/.gitkeep

# Logs
/logs/**
!logs/.gitkeep

# Backups
/backups/**
!/backups/.gitkeep

# Docker related
.env
docker-compose.override.yml

# IDE and editor files
.vscode/
.idea/
*.code-workspace
.DS_Store
Thumbs.db

# Cursor-specific files
.cursor/logs.json

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg

# Node.js
node_modules/
npm-debug.log
yarn-debug.log
yarn-error.log
.npm/

# Temporary files
*.tmp
*.bak
*.swp
*~
"@

    Write-Host "Creating .gitignore file..." -ForegroundColor Yellow
    $gitIgnoreContent | Out-File -FilePath ".gitignore" -Encoding utf8 -Force
    Write-Host "✅ .gitignore file created successfully." -ForegroundColor Green
}

# Function to ensure directory structure exists
function Ensure-DirectoryStructure {
    $directories = @(
        "data/postgis",
        "data/raster-storage",
        "data/vector-storage",
        "data/geoserver/vector/data_dir",
        "data/geoserver/ecw/data_dir",
        "data/user-projections",
        "logs",
        "backups",
        "config/nginx/conf.d",
        "config/docker/dev",
        "config/docker/prod",
        "scripts",
        "src/web-interface",
        "docs"
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            Write-Host "Creating directory: $dir" -ForegroundColor Yellow
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            
            # Create .gitkeep file to ensure empty directories are tracked by Git
            New-Item -Path "$dir/.gitkeep" -ItemType File -Force | Out-Null
        }
    }
    
    Write-Host "✅ Directory structure created successfully." -ForegroundColor Green
}

# Function to verify if repository has any commits
function Test-HasCommits {
    try {
        $commitCount = (git rev-list --all --count 2>$null)
        return ($commitCount -gt 0)
    }
    catch {
        return $false
    }
}

# Function to configure Git user if not already configured
function Ensure-GitConfig {
    $userName = git config --get user.name
    $userEmail = git config --get user.email
    
    if (-not $userName) {
        $defaultName = $env:USERNAME
        $inputName = Read-Host "Git user.name not configured. Enter your name [$defaultName]"
        $userName = if ([string]::IsNullOrWhiteSpace($inputName)) { $defaultName } else { $inputName }
        git config --local user.name $userName
    }
    
    if (-not $userEmail) {
        $defaultEmail = "$env:USERNAME@example.com"
        $inputEmail = Read-Host "Git user.email not configured. Enter your email [$defaultEmail]"
        $userEmail = if ([string]::IsNullOrWhiteSpace($inputEmail)) { $defaultEmail } else { $inputEmail }
        git config --local user.email $userEmail
    }
    
    Write-Host "✅ Git user configured as: $userName <$userEmail>" -ForegroundColor Green
}

# Main script execution
$ErrorActionPreference = "Stop"

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   Corporate GIS Platform - Git Repository Setup" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Git is installed
if (-not (Test-GitInstalled)) {
    Write-Host "❌ Git is not installed or not in PATH. Please install Git and try again." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Git is installed." -ForegroundColor Green

# Ensure directory structure exists
Ensure-DirectoryStructure

# Check if current directory is a Git repository
$isGitRepo = Test-GitRepository
if ($isGitRepo) {
    Write-Host "✅ Current directory is already a Git repository." -ForegroundColor Green
    
    # Check if repository has any commits
    $hasCommits = Test-HasCommits
    if ($hasCommits) {
        Write-Host "✅ Repository already has commits. Skipping initialization." -ForegroundColor Green
        
        # If user wants to configure remote, do it now
        if ($ConfigureRemote) {
            if ([string]::IsNullOrWhiteSpace($RemoteUrl)) {
                Write-Host "❌ RemoteUrl parameter is required when ConfigureRemote is specified." -ForegroundColor Red
                exit 1
            }
            
            # Check if remote already exists
            $remoteExists = (git remote | Where-Object { $_ -eq $RemoteName }).Count -gt 0
            
            if ($remoteExists) {
                $currentUrl = git remote get-url $RemoteName
                Write-Host "Remote '$RemoteName' already exists with URL: $currentUrl" -ForegroundColor Yellow
                
                $updateRemote = Read-Host "Do you want to update it to $RemoteUrl? (y/n)"
                if ($updateRemote -eq "y") {
                    git remote set-url $RemoteName $RemoteUrl
                    Write-Host "✅ Remote '$RemoteName' updated to: $RemoteUrl" -ForegroundColor Green
                }
            } else {
                git remote add $RemoteName $RemoteUrl
                Write-Host "✅ Remote '$RemoteName' added: $RemoteUrl" -ForegroundColor Green
            }
            
            # Push if requested
            if ($Push) {
                Write-Host "Pushing to remote repository..." -ForegroundColor Yellow
                git push -u $RemoteName $BranchName
                Write-Host "✅ Successfully pushed to remote repository." -ForegroundColor Green
            }
        }
        
        exit 0
    }
} else {
    # Initialize new Git repository
    Write-Host "Initializing Git repository..." -ForegroundColor Yellow
    git init
    Write-Host "✅ Git repository initialized." -ForegroundColor Green
}

# Create .gitignore file
New-GitIgnore

# Ensure Git user is configured
Ensure-GitConfig

# Show repository status
git status

# Add all files to staging
Write-Host "Adding files to staging..." -ForegroundColor Yellow
git add .
Write-Host "✅ Files added to staging." -ForegroundColor Green

# Create initial commit
Write-Host "Creating initial commit..." -ForegroundColor Yellow
git commit -m "Initial commit for Corporate GIS Platform"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Initial commit created successfully." -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create initial commit." -ForegroundColor Red
    exit 1
}

# Rename branch to main if needed
$currentBranch = git branch --show-current
if ($currentBranch -ne $BranchName) {
    Write-Host "Renaming branch from '$currentBranch' to '$BranchName'..." -ForegroundColor Yellow
    git branch -m $currentBranch $BranchName
    Write-Host "✅ Branch renamed to '$BranchName'." -ForegroundColor Green
}

# Configure remote repository if requested
if ($ConfigureRemote) {
    if ([string]::IsNullOrWhiteSpace($RemoteUrl)) {
        Write-Host "❌ RemoteUrl parameter is required when ConfigureRemote is specified." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Configuring remote repository '$RemoteName'..." -ForegroundColor Yellow
    git remote add $RemoteName $RemoteUrl
    Write-Host "✅ Remote repository configured." -ForegroundColor Green
    
    # Push if requested
    if ($Push) {
        Write-Host "Pushing to remote repository..." -ForegroundColor Yellow
        git push -u $RemoteName $BranchName
        Write-Host "✅ Successfully pushed to remote repository." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   Git Repository Setup Completed Successfully" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Make changes to your project"
Write-Host "2. Use 'git add .' to stage changes"
Write-Host "3. Use 'git commit -m \"Your message\"' to commit changes"
if (-not $ConfigureRemote) {
    Write-Host "4. Configure a remote repository with:"
    Write-Host "   git remote add origin https://github.com/username/corporate-gis.git"
    Write-Host "5. Push your changes with:"
    Write-Host "   git push -u origin main"
} else {
    Write-Host "4. Push additional changes with:"
    Write-Host "   git push"
}
Write-Host "" 