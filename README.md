# Pgpool-II PostgreSQL Read Load Balancing Setup

This project demonstrates **read load balancing** for PostgreSQL using **Pgpool-II** and Docker Compose. It distributes SELECT queries across multiple streaming replicas while directing all write operations to the primary server.

> **Note**: This setup focuses on **read scaling** and **connection pooling**. It does not include automatic primary failover (promoting a replica to primary). It also assumes that your application manages read queries appropriately — Pgpool will load balance all SELECT statements across replicas, so ensure your application can tolerate eventual consistency for read operations.

## 🏗️ Architecture

```
                    ┌─────────────────┐
                    │   Application   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │    Pgpool-II    │ ← Port 5433 (Load Balancer)
                    │  (Connection    │
                    │   Pooler +      │
                    │   Read LB)      │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ postgres-primary│ │ postgres-replica1│ │ postgres-replica2│
│  (Write Only)   │ │   (Read Only)    │ │   (Read Only)    │
│   weight = 0    │ │   weight = 1     │ │   weight = 1     │
└─────────────────┘ └──────────────────┘ └──────────────────┘
```

## ✨ Features

- **⚖️ Read Load Balancing**: SELECT queries are automatically distributed across replicas (primary has weight 0)
- **🔄 Streaming Replication**: WAL-based replication using physical replication slots
- **🏥 Health Check**: Backend health monitoring every 5 seconds; unhealthy nodes are excluded from load balancing
- **🕒 Replication Lag Detection**: Replicas with lag exceeding 10 seconds are temporarily removed from the read pool
- **🔁 Auto Failback**: Recovered replicas are automatically re-added to the read pool
- **🏊 Connection Pooling**: Efficient connection management (16 child processes, 2 connections per backend each)

## 📋 Prerequisites

- Docker
- Docker Compose
- psql client (for test scripts)

## 🚀 Getting Started

### 1. Start the Cluster

```bash
docker-compose up -d
```

This command starts the following containers:
- `postgres-primary` - Primary PostgreSQL instance (Port 5432)
- `postgres-replica1` - First streaming replica
- `postgres-replica2` - Second streaming replica
- `pgpool` - Pgpool-II load balancer (Port 5433)

### 2. Monitor the Startup Process

```bash
docker-compose logs -f
```

### 3. Check Cluster Status

```bash
./check_pgpool_nodes.sh
```

## 📡 Connection

### Via Pgpool (Recommended)

```bash
PGPASSWORD=secret psql -h localhost -p 5433 -U postgres -d appdb
```

### Direct to Primary

```bash
PGPASSWORD=secret psql -h localhost -p 5432 -U postgres -d appdb
```

## 🧪 Test Scripts

### Replication Status Check

```bash
./check_replication.sh
```

This script:
1. Checks replication lag on both Primary and Replicas
2. Inserts new data into Primary
3. Verifies data replication on Replicas
4. Validates recovery mode status

### Detailed Replication Lag Check

```bash
./check_lag.sh
```

This script displays:
- `pg_stat_replication` information from Primary
- Replication slot details
- LSN and time lag for each replica

### Pgpool Node Status

```bash
./check_pgpool_nodes.sh
```

This script:
1. Shows all backend statuses via `SHOW POOL_NODES`
2. Runs 10 test queries to verify load balancing

### Failover Timing Test

```bash
./test_failover_timing.sh
```

This script:
1. Stops a replica container
2. Measures Pgpool's failure detection time
3. Restarts the replica
4. Measures auto-failback recovery time

## ⚙️ Configuration

### Pgpool Settings (docker-compose.yml)

| Parameter | Value | Description |
|-----------|-------|-------------|
| `PGPOOL_HEALTH_CHECK_PERIOD` | 5 | Health check interval (seconds) |
| `PGPOOL_HEALTH_CHECK_TIMEOUT` | 3 | Health check timeout (seconds) |
| `PGPOOL_HEALTH_CHECK_MAX_RETRIES` | 3 | Retry count before marking node down |
| `PGPOOL_SR_CHECK_PERIOD` | 5 | Replication lag check interval |
| `PGPOOL_DELAY_THRESHOLD_BY_TIME` | 10 | Maximum allowed lag (seconds) |
| `PGPOOL_AUTO_FAILBACK` | yes | Auto failback enabled |
| `PGPOOL_AUTO_FAILBACK_INTERVAL` | 5 | Failback check interval |

### Backend Weights

```yaml
PGPOOL_BACKEND_NODES: >
  0:postgres-primary:5432:0,      # Weight 0 - Write only
  1:postgres-replica1:5432:1,     # Weight 1 - Read load balancing
  2:postgres-replica2:5432:1      # Weight 1 - Read load balancing
```

Since the primary has a weight of 0, read queries are directed only to replicas.

## 📁 Project Structure

```
pgpool/
├── docker-compose.yml        # Main container orchestration
├── README.md                 # This file
│
├── primary/                  # Primary PostgreSQL configuration
│   ├── init.sql              # Replication user, slots, and test table
│   ├── 01_hba.sh             # pg_hba.conf settings
│   └── postgresql.conf       # PostgreSQL config
│
├── replica/                  # Replica configuration
│   ├── init_replica.sh       # Base backup and replication setup
│   ├── postgresql.conf       # Replica-specific config
│   └── recovery.conf         # Replication parameters
│
├── pgpool/                   # Pgpool configuration
│   ├── pgpool.conf           # Pgpool settings
│   └── pool_hba.conf         # Client authentication
│
└── scripts (root level)
    ├── check_lag.sh              # Detailed replication lag check
    ├── check_replication.sh      # Full replication test
    ├── check_pgpool_nodes.sh     # Pgpool node and LB test
    └── test_failover_timing.sh   # Failover timing test
```

## 🔧 Troubleshooting

### View Container Logs

```bash
# All logs
docker-compose logs -f

# Specific container
docker-compose logs -f pgpool
docker-compose logs -f postgres-primary
docker-compose logs -f postgres-replica1
```

### Replica Synchronization Issues

If a replica is not synchronizing:

```bash
# Clean volumes and restart
docker-compose down -v
docker-compose up -d
```

### Pgpool Node Down Status

```bash
# Restart Pgpool
docker-compose restart pgpool
```

### Check Replication Slots

```bash
docker exec postgres-primary psql -U postgres -c "SELECT * FROM pg_replication_slots;"
```

## 🧹 Cleanup

### Stop Containers

```bash
docker-compose down
```

### Remove All Data

```bash
docker-compose down -v
```

## 📚 References

- [Pgpool-II Documentation](https://www.pgpool.net/docs/latest/en/html/)
- [PostgreSQL Streaming Replication](https://www.postgresql.org/docs/current/warm-standby.html)
- [PostgreSQL Replication Slots](https://www.postgresql.org/docs/current/warm-standby.html#STREAMING-REPLICATION-SLOTS)

## 📄 License

This project is intended for educational and development purposes.
