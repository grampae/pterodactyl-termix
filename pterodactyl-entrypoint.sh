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

# /app/html is a symlink to this folder in the server volume, so the web UI is
# served from disk instead of being copied into the RAM-backed /tmp. Refresh it
# from the image's pristine copy whenever the Termix version or BASE_PATH
# changes, and apply upstream's path substitutions here.
HTML_SRC=/opt/termix-html
HTML_DST=/home/container/.termix-html
termix_version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' /app/package.json | head -n 1)"
clean_base_path="${BASE_PATH:-}"
clean_base_path="${clean_base_path%/}"
case "$clean_base_path" in
    "" | /*) ;;
    *) echo "ERROR: BASE_PATH must start with /" >&2; exit 1 ;;
esac
case "$clean_base_path" in
    *[!A-Za-z0-9_./~-]*) echo "ERROR: BASE_PATH contains unsupported characters" >&2; exit 1 ;;
esac
stamp="${termix_version}|${clean_base_path}"

if [ ! -f "$HTML_DST/.pterodactyl-stamp" ] || [ "$(cat "$HTML_DST/.pterodactyl-stamp")" != "$stamp" ]; then
    echo "Preparing the Termix ${termix_version} web UI in ${HTML_DST}..."
    rm -rf "${HTML_DST}.tmp"
    cp -R "$HTML_SRC" "${HTML_DST}.tmp"
    find "${HTML_DST}.tmp" -name "sw.js" -exec sed -i "s|__TERMIX_SW_BASE_PATH__|${clean_base_path}|g" {} +
    if [ -n "$clean_base_path" ]; then
        find "${HTML_DST}.tmp" -name "index.html" -exec sed -i "s|name=\"termix-base-path\" content=\"\"|name=\"termix-base-path\" content=\"${clean_base_path}\"|g" {} +
    fi
    printf '%s' "$stamp" > "${HTML_DST}.tmp/.pterodactyl-stamp"
    rm -rf "$HTML_DST"
    mv "${HTML_DST}.tmp" "$HTML_DST"
fi

if [ -z "${STARTUP:-}" ]; then
    echo "ERROR: The Pterodactyl STARTUP environment variable is empty." >&2
    exit 1
fi

# Pterodactyl startup commands may contain {{VARIABLE}} placeholders.
modified_startup="$(printf '%s' "$STARTUP" | sed -e 's/{{/${/g' -e 's/}}/}/g')"

echo "container@pterodactyl~ ${modified_startup}"
exec /bin/sh -c "$(eval "printf '%s' \"$modified_startup\"")"
