#!/bin/bash
set -euo pipefail

# Dump local dev database and load it into the Docker container
echo "Dumping local oneagent_dev database..."
pg_dump -h localhost -U dpenny oneagent_dev > /tmp/oneagent_dev.sql

echo "Copying dump into container..."
docker compose cp /tmp/oneagent_dev.sql db:/tmp/

echo "Loading dump into container database..."
docker compose exec db psql -U postgres oneagent_dev -f /tmp/oneagent_dev.sql

echo "Cleaning up..."
rm /tmp/oneagent_dev.sql

echo "Done! Local dev database has been seeded into the container."
