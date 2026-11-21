#!/bin/sh
set -eu

# Anything other than the default command runs as-is (debugging, the installer).
if [ "$#" -gt 0 ] && [ "$1" != "pterodactyl" ]; then
    exec "$@"
fi

cd /home/container

export HOME=/home/container
export DATA_DIR="${DATA_DIR:-/home/container/data}"
# Termix's nginx listens on PORT; use the server's primary allocation.
export PORT="${SERVER_PORT:-${PORT:-8080}}"
# Upstream's HTTPS mode writes certificates to a hard-coded /app/data/ssl,
# which is read-only under Wings. Terminate TLS at your reverse proxy instead.
export ENABLE_SSL=false

mkdir -p "$DATA_DIR"
if [ ! -w "$DATA_DIR" ]; then
    echo "ERROR: $DATA_DIR is not writable by uid $(id -u). Reinstall the server or fix ownership." >&2
    exit 1
fi

# Wings runs a read-only root filesystem, so upstream copies the web UI into
# /tmp on every start. /tmp is a Wings tmpfs (docker.tmpfs_size, 100 MB by
# default), so check it fits before Termix half-starts.
html_kb="$(du -sk /app/html | cut -f1)"
tmp_free_kb="$(df -Pk /tmp | awk 'NR==2 {print $4}')"
need_kb=$((html_kb + 20480))
if [ "$tmp_free_kb" -lt "$need_kb" ]; then
    echo "ERROR: /tmp has ${tmp_free_kb} KB free but Termix needs about ${need_kb} KB." >&2
    echo "Raise docker.tmpfs_size in /etc/pterodactyl/config.yml on this node and restart Wings." >&2
    exit 1
fi

if [ -z "${STARTUP:-}" ]; then
    echo "ERROR: The Pterodactyl STARTUP environment variable is empty." >&2
    exit 1
fi

# Pterodactyl startup commands may contain {{VARIABLE}} placeholders.
modified_startup="$(printf '%s' "$STARTUP" | sed -e 's/{{/${/g' -e 's/}}/}/g')"

echo "container@pterodactyl~ ${modified_startup}"
exec /bin/sh -c "$(eval "printf '%s' \"$modified_startup\"")"
