# Docker Setup

This project includes Docker and Docker Compose configurations for both development and production environments.

## Development Mode

Development mode runs with hot code reloading and mounted volumes for easy development.

```bash
# Start development environment
docker-compose --profile dev up

# Or build and start
docker-compose --profile dev up --build

# Run in background
docker-compose --profile dev up -d

# View logs
docker-compose logs -f web-dev

# Stop
docker-compose --profile dev down
```

Access the application at http://localhost:4000

### Development Features
- Hot code reloading enabled
- Source code mounted as volume
- Dependencies cached in named volumes
- Automatic database setup
- Phoenix live reload

## Production Mode

Production mode creates an optimized release with compiled assets.

```bash
# Start production environment
docker-compose --profile prod up

# Or build and start
docker-compose --profile prod up --build

# Run in background
docker-compose --profile prod up -d

# View logs
docker-compose logs -f web-prod

# Stop
docker-compose --profile prod down
```

Access the application at http://localhost:4000

### Production Features
- Compiled release (smaller image)
- Optimized assets
- Database stored in named volume (persists between restarts)
- Production-ready configuration

### Important: Secret Key

**WARNING:** The default `SECRET_KEY_BASE` in docker-compose.yml is for testing only!

For production deployment, generate a secure key:
```bash
mix phx.gen.secret
```

Then either:
1. Update `docker-compose.yml` with the new key
2. Or create a `.env` file (recommended):

```bash
# .env
SECRET_KEY_BASE=your_generated_secret_key_here
```

## Database Persistence

### Development
Database is stored in the mounted `./` directory as `cd_robot_dev.db`

### Production
Database is stored in a Docker named volume `prod-data` for persistence.

To backup production database:
```bash
# Copy database from container
docker-compose run --rm web-prod tar czf - -C /app/data cd_robot.db > cd_robot_backup.tar.gz

# Or access the volume directly
docker volume inspect cd_robot_prod-data
```

## Useful Commands

```bash
# Run mix commands in dev container
docker-compose --profile dev run --rm web-dev mix deps.get
docker-compose --profile dev run --rm web-dev mix test

# Access IEx console in dev
docker-compose --profile dev run --rm web-dev iex -S mix

# Rebuild images
docker-compose --profile dev build
docker-compose --profile prod build

# Clean up everything (including volumes)
docker-compose down -v

# View running containers
docker-compose ps
```

## Troubleshooting

### Port already in use
If port 4000 is already in use, edit `docker-compose.yml`:
```yaml
ports:
  - "4001:4000"  # Use port 4001 on host
```

### Permission issues
If you encounter permission issues with mounted volumes:
```bash
# Fix ownership
sudo chown -R $USER:$USER .
```

### Database locked errors
Ensure only one instance is running:
```bash
docker-compose --profile dev down
docker-compose --profile prod down
```

### Clean start
To start fresh (removes all data):
```bash
docker-compose down -v
docker-compose --profile dev up --build
```
