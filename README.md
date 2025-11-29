# CD Robot

A Phoenix LiveView application for managing a 101-disc CD changer, with support for both standalone deployment and embedded hardware control via Nerves.

## Features

- 🎵 **MusicBrainz Integration** - Search and add albums with metadata
- 📀 **101 Slot Management** - Track and organize your CD collection
- 🖼️ **Album Artwork** - Automatic cover art from Cover Art Archive
- 🔌 **Hardware Control** - Direct GPIO/UART control on Raspberry Pi (Nerves mode)
- 🐳 **Docker Ready** - Production and development Docker configurations
- 💻 **Cross-Platform** - Run on Linux, Mac, Windows, or embedded hardware

## Quick Start

### Development Mode

```bash
# Install dependencies
mix setup

# Start Phoenix server
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) from your browser.

### Production Deployment

Choose your deployment method:

#### Docker (Recommended)

```bash
# Production mode (port 4002)
docker-compose --profile prod up

# Development mode with hot reload (port 4000)
docker-compose --profile dev up
```

See [DOCKER.md](DOCKER.md) for complete Docker setup and configuration.

#### Windows

```powershell
# Build Windows release
.\build_windows.ps1

# Run the application
_build\prod\rel\cd_robot\start.bat
```

See [WINDOWS.md](WINDOWS.md) for Windows deployment guide.

#### Embedded Hardware (Nerves)

```bash
# Build for Raspberry Pi 4
export MIX_TARGET=rpi4
./build_firmware.sh

# Burn to SD card
mix firmware.burn
```

Access at `http://cdrobot.local` after booting.

See [NERVES.md](NERVES.md) for complete embedded hardware setup.

## Deployment Options

| Platform | Guide | Best For |
|----------|-------|----------|
| Docker | [DOCKER.md](DOCKER.md) | Servers, cloud hosting |
| Windows | [WINDOWS.md](WINDOWS.md) | Windows desktops/servers |
| Nerves | [NERVES.md](NERVES.md) | Raspberry Pi, embedded hardware |

## Architecture

### Standalone Mode
- **Web Framework:** Phoenix LiveView
- **Database:** SQLite (Ecto)
- **HTTP Client:** Req
- **MusicBrainz:** Rate-limited API integration
- **Hardware:** Simulation mode (no physical control)

### Nerves Embedded Mode
- All standalone features, plus:
- **Hardware Control:** GPIO, UART, I2C via Circuits
- **Networking:** VintageNet (WiFi/Ethernet)
- **mDNS:** Auto-discovery at cdrobot.local
- **OTA Updates:** Upload new firmware over network

## Project Structure

```
lib/
  cd_robot/           # Core application logic
    musicbrainz.ex    # MusicBrainz API client
    hardware.ex       # Hardware interface (GPIO/UART)
    release.ex        # Production migrations & seeding
  cd_robot_web/       # Phoenix web interface
    live/             # LiveView pages
      add_live.ex     # Add CDs via MusicBrainz search
      load_live.ex    # Load CDs into slots
      slots_live.ex   # View all slots
config/
  target.exs          # Nerves-specific configuration
  runtime.exs         # Dynamic runtime configuration
```

## Development

### Prerequisites

- Elixir 1.15+
- Erlang/OTP 26+
- SQLite

### Common Commands

```bash
# Setup database and dependencies
mix setup

# Run tests
mix test

# Run precommit checks (compile, format, test)
mix precommit

# Generate migration
mix ecto.gen.migration add_field_to_table

# Reset database
mix ecto.reset
```

## Learn More

- Phoenix Framework: https://www.phoenixframework.org/
- Nerves Project: https://nerves-project.org/
- MusicBrainz API: https://musicbrainz.org/doc/MusicBrainz_API
- Elixir: https://elixir-lang.org/

