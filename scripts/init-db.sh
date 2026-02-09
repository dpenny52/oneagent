#!/bin/bash
set -e

# Create databases if they don't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    SELECT 'CREATE DATABASE oneagent_dev'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'oneagent_dev')\gexec

    SELECT 'CREATE DATABASE oneagent_test'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'oneagent_test')\gexec
EOSQL
