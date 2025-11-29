# Windows Deployment Guide

This guide explains how to build and run cd_robot on Windows.

## Prerequisites

1. **Install Erlang/OTP**
   - Download from: https://www.erlang.org/downloads
   - Recommended version: OTP 26 or 27
   - Add to PATH during installation

2. **Install Elixir**
   - Download from: https://elixir-lang.org/install.html#windows
   - Use the Windows installer
   - Verify installation: `elixir --version`

3. **Install Git** (optional, for cloning)
   - Download from: https://git-scm.com/download/win

## Building the Release

1. **Open PowerShell** (as Administrator recommended)

2. **Navigate to the project directory**
   ```powershell
   cd path\to\cd_robot
   ```

3. **Run the build script**
   ```powershell
   .\build_windows.ps1
   ```

   This script will:
   - Check for Elixir installation
   - Install dependencies
   - Compile the application
   - Build assets (CSS/JS)
   - Create a production release
   - Generate startup scripts

## Running the Application

After building, you'll find the release in `_build\prod\rel\cd_robot\`

### Option 1: Background Mode (Recommended)

Run the generated startup script:
```batch
_build\prod\rel\cd_robot\start.bat
```

The application will start in the background. Open your browser to http://localhost:4000

### Option 2: Interactive Console

For debugging or development:
```batch
_build\prod\rel\cd_robot\start_console.bat
```

This provides an interactive Elixir console while the server runs.

## Configuration

Edit `start.bat` or `start_console.bat` to customize:

- **DATABASE_PATH**: Location of the SQLite database
  ```batch
  set DATABASE_PATH=C:\cd_robot_data\cd_robot.db
  ```

- **PORT**: Web server port (default: 4000)
  ```batch
  set PORT=8080
  ```

- **SECRET_KEY_BASE**: Cryptographic secret (REQUIRED for production)
  ```batch
  set SECRET_KEY_BASE=your_64_character_secret_here
  ```
  
  Generate a new secret with:
  ```powershell
  mix phx.gen.secret
  ```

- **PHX_HOST**: Hostname for URL generation
  ```batch
  set PHX_HOST=example.com
  ```

## Deploying to Another Windows Machine

1. **Copy the entire release folder** to the target machine:
   ```
   _build\prod\rel\cd_robot\
   ```

2. **No Elixir/Erlang installation needed!** The release is self-contained.

3. **Edit start.bat** to set your configuration (especially SECRET_KEY_BASE)

4. **Run start.bat** on the target machine

## Troubleshooting

### Port Already in Use

If port 4000 is busy:
```batch
set PORT=8080
```

### Database Permission Errors

Ensure the data directory is writable:
```batch
mkdir C:\cd_robot_data
set DATABASE_PATH=C:\cd_robot_data\cd_robot.db
```

### Application Won't Start

1. Check the logs in `_build\prod\rel\cd_robot\`
2. Verify SECRET_KEY_BASE is set and is 64+ characters
3. Ensure no antivirus is blocking the application

### Manual Database Migration

If migrations don't run automatically:
```batch
cd _build\prod\rel\cd_robot
bin\cd_robot.bat eval "CdRobot.Release.migrate()"
```

### Manual Slot Initialization

To initialize the 101 slots:
```batch
cd _build\prod\rel\cd_robot
bin\cd_robot.bat eval "CdRobot.Release.seed()"
```

## Running as a Windows Service

To run cd_robot as a Windows service, you can use [NSSM (Non-Sucking Service Manager)](https://nssm.cc/):

1. Download NSSM
2. Install the service:
   ```powershell
   nssm install cd_robot "C:\path\to\_build\prod\rel\cd_robot\bin\cd_robot.bat" start
   ```
3. Configure environment variables in NSSM GUI
4. Start the service:
   ```powershell
   nssm start cd_robot
   ```

## Updating the Application

1. Build a new release (run `build_windows.ps1` again)
2. Stop the running application (Ctrl+C or stop the service)
3. Replace the release folder
4. Start the application again

Database migrations will run automatically on startup.

## Firewall Configuration

If accessing from other machines on your network:

1. Allow inbound traffic on your chosen port (default: 4000)
2. Windows Defender Firewall → Advanced Settings → Inbound Rules → New Rule
3. Port: TCP, 4000
4. Action: Allow the connection

## Performance Tips

- **Database location**: For best performance, use a local disk (not network drive)
- **Antivirus**: Add an exception for the release folder to prevent scan delays
- **Memory**: The application typically uses 50-100MB RAM

## Development on Windows

If you want to run in development mode instead:

```powershell
$env:MIX_ENV = "dev"
mix deps.get
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
mix phx.server
```

This runs with hot reload and detailed debugging.
