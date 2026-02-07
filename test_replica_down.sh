#!/bin/bash

# Test Replica Down Scenario
# Stops pg-replica1 completely to test Pgpool failover behavior

REPLICA="pg-replica1"
DOWN_DURATION=20

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    REPLICA DOWN TEST - $REPLICA                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Initial status
echo "[$(date +%H:%M:%S)] Initial Pgpool node status:"
PGPASSWORD=secret psql -h 127.0.0.1 -p 5433 -U postgres -d appdb -c "SHOW POOL_NODES" 2>/dev/null

echo ""
echo "[$(date +%H:%M:%S)] Initial replication status:"
docker exec pg-primary psql -U postgres -c "SELECT client_addr, state, replay_lag FROM pg_stat_replication;" 2>/dev/null

# Stop replica1
echo ""
echo "[$(date +%H:%M:%S)] ⛔ STOPPING $REPLICA..."
docker stop $REPLICA >/dev/null 2>&1
echo "[$(date +%H:%M:%S)] $REPLICA stopped."

# Wait for Pgpool to detect
echo ""
echo "[$(date +%H:%M:%S)] Waiting 5s for Pgpool to detect..."
sleep 5

# Show status after stop
echo ""
echo "[$(date +%H:%M:%S)] Pgpool node status (after $REPLICA stopped):"
PGPASSWORD=secret psql -h 127.0.0.1 -p 5433 -U postgres -d appdb -c "SHOW POOL_NODES" 2>/dev/null

echo ""
echo "[$(date +%H:%M:%S)] Replication status (after $REPLICA stopped):"
docker exec pg-primary psql -U postgres -c "SELECT client_addr, state, replay_lag FROM pg_stat_replication;" 2>/dev/null

# Wait remaining time
remaining=$((DOWN_DURATION - 5))
echo ""
echo "[$(date +%H:%M:%S)] Waiting ${remaining}s before restarting..."
sleep $remaining

# Start replica1 again
echo ""
echo "[$(date +%H:%M:%S)] ▶️  STARTING $REPLICA..."
docker start $REPLICA >/dev/null 2>&1
echo "[$(date +%H:%M:%S)] $REPLICA started."

# Wait for recovery
echo ""
echo "[$(date +%H:%M:%S)] Waiting 10s for $REPLICA to recover and sync..."
sleep 10

# Final status
echo ""
echo "[$(date +%H:%M:%S)] Final Pgpool node status:"
PGPASSWORD=secret psql -h 127.0.0.1 -p 5433 -U postgres -d appdb -c "SHOW POOL_NODES" 2>/dev/null

echo ""
echo "[$(date +%H:%M:%S)] Final replication status:"
docker exec pg-primary psql -U postgres -c "SELECT client_addr, state, replay_lag FROM pg_stat_replication;" 2>/dev/null

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          TEST COMPLETE                                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
