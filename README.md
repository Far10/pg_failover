# pg_failover
# Postgresql automatic failover for streaming replication

#Step One : create pg_failover.sh on each server
#Pay attention to this variable:

PRIMARY_HOST=""  # IP del Master
STANDBY_HOST=""  # IP dello Standby
PG_USER="postgres"            # Utente PostgreSQL
PGDATA=""          # Data directory
