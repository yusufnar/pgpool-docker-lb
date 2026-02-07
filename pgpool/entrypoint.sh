#!/bin/bash
set -e

echo "Starting Pgpool-II..."

# Show config for debugging
echo "=== Pgpool Configuration ==="
grep -E "backend_hostname|delay_threshold|prefer_lower|sr_check_period" /etc/pgpool-II/pgpool.conf | head -10

# Start pgpool
exec pgpool -n -f /etc/pgpool-II/pgpool.conf -F /etc/pgpool-II/pcp.conf -a /etc/pgpool-II/pool_hba.conf
