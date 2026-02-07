#!/bin/bash
set -e

# Data directory is usually /var/lib/postgresql/data
if [ -z "$(ls -A "$PGDATA")" ]; then
    echo "No data found in $PGDATA. Starting base backup from primary..."
    
    # Wait for primary to be ready
    until pg_isready -h primary -p 5432 -U ${REP_USER:-replica}; do
        echo "Waiting for request to primary database..."
        sleep 2
    done

    echo "Taking base backup..."
    # -R flag writes PostgreSQL configuration for replication (creates standout.signal and postgresql.auto.conf)
    # -S sets the replication slot name
    # -X stream ensures WAL files are included in the backup
    pg_basebackup -h primary -D "$PGDATA" -U ${REP_USER:-replica} -v -R -X stream -S ${REPLICATION_SLOT} -P

    echo "Base backup completed."
    
    # Fix permissions (just in case)
    chmod 0700 "$PGDATA"
else
    echo "Data directory is not empty. Skipping base backup."
fi

# Hand over control to the original entrypoint
exec docker-entrypoint.sh "$@"
