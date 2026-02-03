#!/bin/bash

echo "========================================================"
echo "FAILOVER TIMING TEST"
echo "========================================================"

# Function to get node status
get_node_status() {
    PGPASSWORD=secret psql -h 127.0.0.1 -p 5433 -U postgres -d appdb -t -c "SHOW POOL_NODES" 2>/dev/null | grep "postgres-replica1" | awk -F'|' '{print $4}' | tr -d ' '
}

# Initial status
echo "[$(date +%H:%M:%S)] Initial Status:"
PGPASSWORD=secret psql -h 127.0.0.1 -p 5433 -U postgres -d appdb -c "SELECT node_id, hostname, status, pg_status FROM (SELECT regexp_split_to_table(string_agg(row::text, E'\n'), E'\n') as row FROM (SELECT * FROM pgpool_adm_pcp_node_info(NULL,NULL,NULL,NULL)) t) x LIMIT 3;" 2>/dev/null || ./check_pgpool_nodes.sh | head -15

echo ""
echo "[$(date +%H:%M:%S)] STOPPING postgres-replica1..."
STOP_TIME=$(date +%s)
docker stop postgres-replica1 > /dev/null

# Poll for DOWN status
echo "[$(date +%H:%M:%S)] Waiting for Pgpool to detect failure..."
while true; do
    STATUS=$(get_node_status)
    if [ "$STATUS" == "down" ]; then
        DOWN_TIME=$(date +%s)
        DETECT_DURATION=$((DOWN_TIME - STOP_TIME))
        echo "[$(date +%H:%M:%S)] ✅ Pgpool marked node as DOWN"
        echo "    Detection time: ${DETECT_DURATION} seconds"
        break
    fi
    sleep 1
done

echo ""
echo "[$(date +%H:%M:%S)] STARTING postgres-replica1..."
START_TIME=$(date +%s)
docker start postgres-replica1 > /dev/null

# Poll for UP status
echo "[$(date +%H:%M:%S)] Waiting for Pgpool auto-failback..."
while true; do
    STATUS=$(get_node_status)
    if [ "$STATUS" == "up" ]; then
        UP_TIME=$(date +%s)
        RECOVERY_DURATION=$((UP_TIME - START_TIME))
        echo "[$(date +%H:%M:%S)] ✅ Pgpool marked node as UP"
        echo "    Recovery time: ${RECOVERY_DURATION} seconds"
        break
    fi
    sleep 1
done

echo ""
echo "========================================================"
echo "SUMMARY"
echo "========================================================"
echo "Failure Detection Time: ${DETECT_DURATION} seconds"
echo "Auto-Failback Time:     ${RECOVERY_DURATION} seconds"
echo "========================================================"

# Final status
echo ""
echo "[$(date +%H:%M:%S)] Final Status:"
./check_pgpool_nodes.sh | head -15
