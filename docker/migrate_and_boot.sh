#!/bin/ash

# Maximum amount of seconds to wait for the PostgreSQL container
# to accept our connection before exiting.
timeout=5

# Interval at which the PostgreSQL container should be checked for availability.
interval=1

max_retries=$(expr ${timeout} \* ${interval})
attempt=0

function ping_postgres() {
    nc -z postgres:5432
    return $?
}

# Wait for the PostgreSQL container to be accessible.
while [[ ! ping_postgres ]]; do
    if [[ ${attempt} -eq ${max_retries} ]]; then
        echo [!] Unable to access PostgreSQL after maximum
        echo [!] specified timeout of ${timeout} seconds.
        exit 1
    fi

    echo [i] Waiting for the PostgreSQL to boot,
    echo [i] attempt ${attempt}/${max_retries}. Sleeping for ${interval}s.
    sleep ${interval}
    let attempt+=1
done

# Ensure our schema is up-to-date, and start bolt.
mix ecto.migrate --quiet
exec mix run --no-halt
