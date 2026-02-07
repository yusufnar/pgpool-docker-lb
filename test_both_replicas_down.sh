#!/bin/bash

# Test Both Replicas Down Scenario
# Stops both pg-replica1 and pg-replica2 to test Pgpool behavior

DOWN_DURATION=20

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    BOTH REPLICAS DOWN TEST                                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Initial status
echo "[$(date +%H:%M:%S)] Initial Pgpool node status:"
PGPASSWORD=secret psql -h 127.0.0.1 -p 5433 -U postgres -d appdb -c "SHOW POOL_NODES" 2>/dev/null

echo ""
echo "[$(date +%H:%M:%S)] Initial replication status:"
docker exec pg-primary psql -U postgres -c "SELECT client_addr, state, replay_lag FROM pg_stat_replication;" 2>/dev/null

# Stop both replicas
echo ""
echo "[$(date +%H:%M:%S)] ⛔ STOPPING pg-replica1..."
docker stop pg-replica1 >/dev/null 2>&1
echo "[$(date +%H:%M:%S)] ⛔ STOPPING pg-replica2..."
docker stop pg-replica2 >/dev/null 2>&1
echo "[$(date +%H:%M:%S)] Both replicas stopped."

# Wait for Pgpool to detect
echo ""
echo "[$(date +%H:%M:%S)] Waiting 5s for Pgpool to detect..."
sleep 5

# Show status after stop
echo ""
echo "[$(date +%H:%M:%S)] Pgpool node status (both replicas stopped):"
PGPASSWORD=secret psql -h 127.0.0.1 -p 5433 -U postgres -d appdb -c "SHOW POOL_NODES" 2>/dev/null

echo ""
echo "[$(date +%H:%M:%S)] Replication status (both replicas stopped):"
docker exec pg-primary psql -U postgres -c "SELECT client_addr, state, replay_lag FROM pg_stat_replication;" 2>/dev/null

# Test if queries still work (should go to primary)
echo ""
echo "[$(date +%H:%M:%S)] Testing queries (should go to primary only):"
for i in 1 2 3 4 5; do
    ip=$(PGPASSWORD=secret psql -h 127.0.0.1 -p 5433 -U postgres -d appdb -t -c "SELECT inet_server_addr();" 2>/dev/null | tr -d '[:space:]')
    echo "  Query $i: $ip"
done

# Wait remaining time
remaining=$((DOWN_DURATION - 5))
echo ""
echo "[$(date +%H:%M:%S)] Waiting ${remaining}s before restarting..."
sleep $remaining

# Start both replicas again
echo ""
echo "[$(date +%H:%M:%S)] ▶️  STARTING pg-replica1..."
docker start pg-replica1 >/dev/null 2>&1
echo "[$(date +%H:%M:%S)] ▶️  STARTING pg-replica2..."
docker start pg-replica2 >/dev/null 2>&1
echo "[$(date +%H:%M:%S)] Both replicas started."

# Wait for recovery
echo ""
echo "[$(date +%H:%M:%S)] Waiting 15s for replicas to recover and sync..."
sleep 15

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
