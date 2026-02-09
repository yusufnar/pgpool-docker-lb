# Pgpool-II PostgreSQL Read Load Balancing Setup

This project demonstrates **read load balancing** for PostgreSQL using **Pgpool-II** and Docker Compose. It distributes SELECT queries across multiple streaming replicas while directing all write operations to the primary server.

> **Note**: This setup focuses on **read scaling** and **connection pooling**. It does not include automatic primary failover (promoting a replica to primary).

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
│   pg-primary    │ │   pg-replica1    │ │   pg-replica2    │
│  (Write Only)   │ │   (Read Only)    │ │   (Read Only)    │
│   weight = 0    │ │   weight = 1     │ │   weight = 1     │
└─────────────────┘ └──────────────────┘ └──────────────────┘
```

## ✨ Features

- **⚖️ Read Load Balancing**: SELECT queries distributed across replicas (primary has weight 0)
- **🔄 Streaming Replication**: WAL-based replication using physical replication slots
- **🏥 Health Check**: Backend health monitoring every 1 second
- **🕒 Replication Lag Detection**: Replicas with lag > 1 second are excluded from load balancing
- **🔁 Auto Failback**: Recovered replicas automatically re-added to the read pool
- **🏊 Connection Pooling**: 64 child processes, 2 connections per backend each (max 384 connections)
- **🐳 Custom Dockerfile**: Full control over Pgpool configuration

## 🐳 Container Images

| Container | Image | Description |
|-----------|-------|-------------|
| pg-primary | `postgres:17` | Official PostgreSQL 17 image (primary) |
| pg-replica1 | `postgres:17` | Official PostgreSQL 17 image (streaming replica) |
| pg-replica2 | `postgres:17` | Official PostgreSQL 17 image (streaming replica) |
| pgpool-read | Custom build | `postgres:17-alpine` + pgpool (ARM64/AMD64 compatible) |

### Why Custom Pgpool Image?

- **Official `pgpool/pgpool`**: Only AMD64, not ARM64 compatible (fails on M1/M2 Macs)
- **Bitnami `bitnami/pgpool`**: Discontinued from Docker Hub (Aug 2025)
- **Our solution**: Custom Dockerfile based on `postgres:15-alpine` with pgpool package

### Pgpool-Read Dockerfile

```dockerfile
FROM postgres:17-alpine
RUN apk add --no-cache pgpool pgpool-openrc bash
COPY pgpool.conf pool_hba.conf pool_passwd pcp.conf /etc/pgpool-II/
EXPOSE 5432 9898
```

This provides:
- Full control over `pgpool.conf`
- ARM64 & AMD64 compatibility
- No dependency on third-party images

## 📋 Prerequisites

- Docker & Docker Compose
- psql client (for test scripts)

## 🚀 Getting Started

### 1. Start the Cluster

```bash
docker-compose up -d
```

This starts:
- `pg-primary` - Primary PostgreSQL (Port 5432)
- `pg-replica1` - Streaming replica
- `pg-replica2` - Streaming replica
- `pgpool-read` - Custom-built Pgpool-II load balancer (Port 5433)

### 2. Check Cluster Status

```bash
PGPASSWORD=secret psql -h localhost -p 5433 -U postgres -d appdb -c "SHOW POOL_NODES"
```

## 📡 Connection

```bash
# Via Pgpool (recommended)
PGPASSWORD=secret psql -h localhost -p 5433 -U postgres -d appdb

# Direct to Primary
PGPASSWORD=secret psql -h localhost -p 5432 -U postgres -d appdb
```

## 🧪 Test & Monitor Scripts

| Script | Description |
|--------|-------------|
| `./monitor_load_balancing.sh` | Real-time query distribution monitor |
| `./monitor_connections.sh` | Backend connection stats (idle/active) |
| `./check_lag.sh` | Detailed replication lag info |
| `./check_replication.sh` | Full replication test |
| `./check_pgpool_nodes.sh` | Pgpool node status |
| `./test_failover_timing.sh` | Failover detection timing |
| `./test_artificial_lag.sh` | Test lag detection on one replica |
| `./test_replica_down.sh` | Test replica down scenario |
| `./test_both_replicas_down.sh` | Test all replicas down |
| `./test_both_replicas_lag.sh` | Test lag on all replicas |

## ⚙️ Configuration

### Pgpool Settings (pgpool/pgpool.conf)

| Parameter | Value | Description |
|-----------|-------|-------------|
| `num_init_children` | 64 | Max concurrent client connections |
| `max_pool` | 2 | Connections per backend per child |
| `connection_life_time` | 600 | Connection lifetime (10 min) |
| `health_check_period` | 1 | Health check interval (seconds) |
| `health_check_max_retries` | 1 | Retries before marking down |
| `sr_check_period` | 1 | Replication lag check interval |
| `delay_threshold_by_time` | 1000 | Max allowed lag (1 second = 1000ms) |
| `prefer_lower_delay_standby` | on | Prefer replica with lower lag |
| `auto_failback` | on | Auto re-add recovered replicas |

### Backend Weights

Primary has weight 0 = read queries only go to replicas:
```
backend_weight0 = 0  # pg-primary (write only)
backend_weight1 = 1  # pg-replica1 (read)
backend_weight2 = 1  # pg-replica2 (read)
```

## 📁 Project Structure

```
pgpool/
├── docker-compose.yml          # Container orchestration
├── README.md
│
├── pg-primary/                 # Primary PostgreSQL
│   ├── init.sql                # Replication user, slots, test table
│   ├── 01_hba.sh               # pg_hba.conf settings
│   └── postgresql.conf
│
├── replica/                    # Replica configuration
│   ├── init_replica.sh         # Base backup and replication setup
│   ├── postgresql.conf
│   └── recovery.conf
│
├── pgpool/                     # Custom Pgpool-Read build
│   ├── Dockerfile              # Custom ARM64-compatible image
│   ├── entrypoint.sh           # Startup script
│   ├── pgpool.conf             # Full configuration
│   ├── pool_hba.conf           # Client authentication
│   ├── pool_passwd             # User passwords
│   └── pcp.conf                # PCP admin config
│
└── scripts (root)
    ├── monitor_load_balancing.sh   # Real-time LB monitor
    ├── monitor_connections.sh      # Connection stats monitor
    ├── check_lag.sh                # Replication lag check
    ├── check_replication.sh        # Full replication test
    ├── check_pgpool_nodes.sh       # Pool nodes status
    ├── test_failover_timing.sh     # Failover timing test
    ├── test_artificial_lag.sh      # Lag detection test
    ├── test_replica_down.sh        # Replica down test
    ├── test_both_replicas_down.sh  # All replicas down test
    └── test_both_replicas_lag.sh   # All replicas lag test
```

## 🔧 Troubleshooting

### View Logs

```bash
docker-compose logs -f pgpool-read
docker-compose logs -f pg-primary
```

### Reset Everything

```bash
docker-compose down -v
docker-compose up -d --build
```

### Check Replication Slots

```bash
docker exec pg-primary psql -U postgres -c "SELECT * FROM pg_replication_slots;"
```

## 📚 References

- [Pgpool-II Documentation](https://www.pgpool.net/docs/latest/en/html/)
- [PostgreSQL Streaming Replication](https://www.postgresql.org/docs/current/warm-standby.html)

## 📄 License

This project is intended for educational and development purposes.
