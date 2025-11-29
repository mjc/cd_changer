#!/bin/sh
set -e

# Handle signals properly
trap 'exit 0' TERM INT

# Extract directory from DATABASE_PATH
DB_DIR=$(dirname "${DATABASE_PATH}")

# Create database directory if it doesn't exist
if [ ! -d "$DB_DIR" ]; then
  echo "Creating database directory: $DB_DIR"
  mkdir -p "$DB_DIR"
fi

# Ensure database file exists (SQLite will create it, but let's be explicit)
if [ ! -f "$DATABASE_PATH" ]; then
  echo "Database file will be created at: $DATABASE_PATH"
  touch "$DATABASE_PATH"
fi

echo "Running migrations..."
# Run migrations
/app/bin/cd_robot eval "CdRobot.Release.migrate"

echo "Starting server..."
# Start the server - exec replaces the shell process with the server
exec /app/bin/cd_robot start
