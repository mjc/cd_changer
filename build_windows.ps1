# Build script for Windows release of cd_robot
# Run this on your Windows machine with Elixir and Erlang/OTP installed

param(
    [string]$Version = "0.1.0"
)

Write-Host "Building cd_robot Windows release v$Version..." -ForegroundColor Green

# Check if Elixir is installed
try {
    $elixirVersion = elixir --version
    Write-Host "Found Elixir:" -ForegroundColor Cyan
    Write-Host $elixirVersion
} catch {
    Write-Host "Error: Elixir is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Elixir from https://elixir-lang.org/install.html#windows" -ForegroundColor Yellow
    exit 1
}

# Set environment variables for production
$env:MIX_ENV = "prod"
$env:PHX_SERVER = "true"

# Generate a secret key base if not set
if (-not $env:SECRET_KEY_BASE) {
    Write-Host "Generating SECRET_KEY_BASE..." -ForegroundColor Cyan
    $env:SECRET_KEY_BASE = mix phx.gen.secret
}

Write-Host "Installing dependencies..." -ForegroundColor Cyan
mix deps.get --only prod

Write-Host "Compiling application..." -ForegroundColor Cyan
mix compile

Write-Host "Compiling assets..." -ForegroundColor Cyan
mix assets.deploy

Write-Host "Creating release..." -ForegroundColor Cyan
mix release --overwrite

$releasePath = ".\\_build\\prod\\rel\\cd_robot"

if (Test-Path $releasePath) {
    Write-Host "`nRelease built successfully!" -ForegroundColor Green
    Write-Host "Location: $releasePath" -ForegroundColor Cyan
    
    # Create a startup script
    $startScript = @"
@echo off
REM Startup script for cd_robot

REM Set the database path (change this to your preferred location)
set DATABASE_PATH=%~dp0data\cd_robot.db

REM Set the secret key base (IMPORTANT: Change this to a secure value!)
set SECRET_KEY_BASE=$env:SECRET_KEY_BASE

REM Set the port (default: 4000)
set PORT=4000

REM Set the host
set PHX_HOST=localhost

REM Enable Phoenix server
set PHX_SERVER=true

REM Create data directory if it doesn't exist
if not exist "%~dp0data" mkdir "%~dp0data"

REM Run database migrations
echo Running database migrations...
call "%~dp0bin\cd_robot.bat" eval "CdRobot.Release.migrate()"

REM Seed the database (first run only)
echo Initializing slots...
call "%~dp0bin\cd_robot.bat" eval "CdRobot.Release.seed()"

REM Start the application
echo Starting cd_robot...
call "%~dp0bin\cd_robot.bat" start

"@
    
    $startScriptPath = Join-Path $releasePath "start.bat"
    Set-Content -Path $startScriptPath -Value $startScript
    Write-Host "Created startup script: $startScriptPath" -ForegroundColor Cyan
    
    # Create a console startup script
    $consoleScript = @"
@echo off
REM Console startup script for cd_robot

REM Set the database path (change this to your preferred location)
set DATABASE_PATH=%~dp0data\cd_robot.db

REM Set the secret key base (IMPORTANT: Change this to a secure value!)
set SECRET_KEY_BASE=$env:SECRET_KEY_BASE

REM Set the port (default: 4000)
set PORT=4000

REM Set the host
set PHX_HOST=localhost

REM Enable Phoenix server
set PHX_SERVER=true

REM Create data directory if it doesn't exist
if not exist "%~dp0data" mkdir "%~dp0data"

REM Run database migrations
echo Running database migrations...
call "%~dp0bin\cd_robot.bat" eval "CdRobot.Release.migrate()"

REM Seed the database (first run only)
echo Initializing slots...
call "%~dp0bin\cd_robot.bat" eval "CdRobot.Release.seed()"

REM Start the application with console
echo Starting cd_robot with interactive console...
call "%~dp0bin\cd_robot.bat" start_iex

"@
    
    $consoleScriptPath = Join-Path $releasePath "start_console.bat"
    Set-Content -Path $consoleScriptPath -Value $consoleScript
    Write-Host "Created console startup script: $consoleScriptPath" -ForegroundColor Cyan
    
    Write-Host "`nTo run the application:" -ForegroundColor Yellow
    Write-Host "1. Copy the entire folder: $releasePath" -ForegroundColor White
    Write-Host "2. Run start.bat (or start_console.bat for interactive mode)" -ForegroundColor White
    Write-Host "3. Open your browser to http://localhost:4000" -ForegroundColor White
    Write-Host "`nIMPORTANT: Edit start.bat to set a unique SECRET_KEY_BASE before deploying!" -ForegroundColor Red
    
} else {
    Write-Host "Error: Release build failed" -ForegroundColor Red
    exit 1
}

Write-Host "`nBuild complete!" -ForegroundColor Green
