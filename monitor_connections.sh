#!/bin/bash
# Monitor Pgpool connections to each backend in real-time
# Groups by idle and active connections

echo "Pgpool Connection Monitor (Ctrl+C to stop)"
echo "==========================================="

while true; do
    clear
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  PGPOOL CONNECTION MONITOR  [$(date +%H:%M:%S)]                      ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "=== Backend Connections (Idle / Active / Total) ==="
    printf "%-15s | %6s | %6s | %6s\n" "BACKEND" "IDLE" "ACTIVE" "TOTAL"
    echo "----------------|--------|--------|-------"
    
    for node in pg-primary pg-replica1 pg-replica2; do
        result=$(docker exec $node psql -U postgres -t -c "
            SELECT 
                COALESCE(SUM(CASE WHEN state = 'idle' THEN 1 ELSE 0 END), 0) as idle,
                COALESCE(SUM(CASE WHEN state = 'active' THEN 1 ELSE 0 END), 0) as active,
                COUNT(*) as total
            FROM pg_stat_activity 
            WHERE usename = 'postgres' AND pid != pg_backend_pid()
        " 2>/dev/null | tr -d '[:space:]')
        
        if [ -n "$result" ]; then
            idle=$(echo "$result" | cut -d'|' -f1)
            active=$(echo "$result" | cut -d'|' -f2)
            total=$(echo "$result" | cut -d'|' -f3)
            printf "%-15s | %6s | %6s | %6s\n" "$node" "$idle" "$active" "$total"
        else
            printf "%-15s | %6s | %6s | %6s\n" "$node" "N/A" "N/A" "N/A"
        fi
    done
    
    echo ""
    echo "=== Pool Nodes Status ==="
    PGPASSWORD=secret psql -h 127.0.0.1 -p 5433 -U postgres -d appdb -c "SHOW POOL_NODES" 2>/dev/null
    
    echo ""
    echo "Press Ctrl+C to stop..."
    sleep 1
done
