# PostgreSQL 16 with pgTAP extension pre-installed
FROM postgres:16-alpine

# Install pgTAP extension
RUN apk add --no-cache postgresql-pgtap

# Copy init script to enable extension on template1 (so all new databases have it)
COPY init-pgtap.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/init-pgtap.sh

# Default postgres settings optimized for testing
CMD ["postgres", \
     "-c", "max_connections=100", \
     "-c", "shared_buffers=256MB", \
     "-c", "effective_cache_size=768MB", \
     "-c", "maintenance_work_mem=64MB"]
