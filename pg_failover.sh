#!/bin/bash

# Configurazione
PRIMARY_HOST=""  # IP del Master
STANDBY_HOST=""  # IP dello Standby
PG_USER="postgres"            # Utente PostgreSQL
PGDATA=""          # Data directory
CHECK_INTERVAL=10             # Intervallo di controllo (secondi)
FAILOVER_TIMEOUT=30           # Tempo prima del failover (secondi)

# Variabili interne
failover_timer=0
master_is_down=false
failover_executed=false

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

while true; do
    # Controlla se il master è attivo
    if ! pg_isready -h $PRIMARY_HOST -U $PG_USER >/dev/null 2>&1; then
        log "Master $PRIMARY_HOST NON RISPONDE."

        if [ "$master_is_down" = false ]; then
            failover_timer=$(date +%s)  # Avvia il timer
            master_is_down=true
        fi

        # Controlla se è scaduto il timeout per il failover
        now=$(date +%s)
        elapsed=$((now - failover_timer))

        if [ "$elapsed" -ge "$FAILOVER_TIMEOUT" ] && [ "$failover_executed" = false ]; then
            log "Timeout superato: promuovo lo standby a MASTER!"
            ssh $STANDBY_HOST "/usr/lib/postgresql/17/bin/pg_ctl promote -D $PGDATA"

            log "Failover completato. Lo script ora attende il ritorno del vecchio Master per il riallineamento."
            failover_executed=true
        fi
    else
        # Se il Master è tornato ONLINE dopo il failover, avvia il riallineamento
        if [ "$failover_executed" = true ]; then
            log "Il Master è tornato ONLINE. Avvio pg_rewind per riallineamento..."
            
            # Stop del vecchio Master per il rewind
            sudo systemctl stop postgresql
            sleep $CHECK_INTERVAL

            # Eseguo il rewind
            /usr/lib/postgresql/17/bin/pg_rewind --target-pgdata=$PGDATA --source-server="host=$STANDBY_HOST user=$PG_USER"
            
            # Lo preparo come standby
            echo "primary_conninfo = 'user=user password=password host=$STANDBY_HOST port=5432'" > $PGDATA/postgresql.auto.conf
            touch $PGDATA/standby.signal
            sleep $CHECK_INTERVAL

            # Avvio postgres come standby
            sudo systemctl start postgresql

            log "Master riallineato come standby! Esco dallo script."

            exit 0
        fi

        master_is_down=false
    fi

    sleep $CHECK_INTERVAL
done
