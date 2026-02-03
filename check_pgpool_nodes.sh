#!/bin/bash

# Port 5433 is exposed for Pgpool in docker-compose
PGPOOL_PORT=5433
PGPOOL_HOST=127.0.0.1
USER=postgres
DB=appdb

echo "========================================================"
echo "1. Current Pgpool Backend Nodes (SHOW POOL_NODES)"
echo "========================================================"
# Connect to Pgpool and ask for status
PGPASSWORD=secret psql -h $PGPOOL_HOST -p $PGPOOL_PORT -U $USER -d $DB -c "SHOW POOL_NODES"

echo ""
echo "========================================================"
echo "2. Testing Load Balancing (Executing 10 Queries)"
echo "========================================================"
# Run 10 simple queries to check which node IP responds
for i in {1..10}; do
    SERVER_IP=$(PGPASSWORD=secret psql -h $PGPOOL_HOST -p $PGPOOL_PORT -U $USER -d $DB -t -c "SELECT inet_server_addr();" | tr -d '[:space:]')
    echo "Query $i handled by: $SERVER_IP"
done

echo ""
echo "Note: Compare IPs with 'docker inspect' to identify container names."
