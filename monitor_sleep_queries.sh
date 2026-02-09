#!/bin/bash

# Long Query Monitor Script
# Sends SELECT pg_sleep(10) every 10 seconds to test in-flight query behavior

PGPOOL_PORT=5433
PGPOOL_HOST=127.0.0.1
USER=postgres
DB=appdb

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          PGPOOL LONG QUERY (SLEEP) MONITOR                   ║"
echo "║     Sends SELECT pg_sleep(10) every 10 seconds              ║"
echo "║     Press Ctrl+C to stop                                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

while true; do
    timestamp=$(date +%H:%M:%S)
    
    echo "[$timestamp] Sending 4 concurrent SELECT pg_sleep(10)..."
    
    for i in {1..4}; do
        (
            PGPASSWORD=secret psql -h $PGPOOL_HOST -p $PGPOOL_PORT -U $USER -d $DB -c "SELECT inet_server_addr() as node, pg_sleep(20);" 2>&1 | while read line; do
                echo "    [$timestamp Q$i Result] $line"
            done
        ) &
    done
    
    echo "Waiting for all 4 queries to finish..."
    wait
    
done
