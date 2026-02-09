# Pgpool-II Custom Dockerfile
# ARM64 compatible, full config control

FROM postgres:17-alpine

# Install pgpool
RUN apk add --no-cache \
    pgpool \
    pgpool-openrc \
    bash

# Create directories
RUN mkdir -p /etc/pgpool-II /var/run/pgpool /var/log/pgpool && \
    chown -R postgres:postgres /etc/pgpool-II /var/run/pgpool /var/log/pgpool

# Copy configuration files
COPY pgpool.conf /etc/pgpool-II/pgpool.conf
COPY pool_hba.conf /etc/pgpool-II/pool_hba.conf
COPY pool_passwd /etc/pgpool-II/pool_passwd
COPY pcp.conf /etc/pgpool-II/pcp.conf

# Create .pcppass for local PCP commands (client-side auth)
RUN echo "localhost:9898:postgres:secret" > /var/lib/postgresql/.pcppass && \
    echo "127.0.0.1:9898:postgres:secret" >> /var/lib/postgresql/.pcppass && \
    echo "/var/run/pgpool:9898:postgres:secret" >> /var/lib/postgresql/.pcppass && \
    chmod 600 /var/lib/postgresql/.pcppass && \
    chown postgres:postgres /var/lib/postgresql/.pcppass

# Set permissions
RUN chmod 600 /etc/pgpool-II/pool_passwd && \
    chown -R postgres:postgres /etc/pgpool-II

# Expose ports
EXPOSE 5432 9898

# Start script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER postgres

ENTRYPOINT ["/entrypoint.sh"]
