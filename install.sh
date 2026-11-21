#!/bin/bash
set -euo pipefail

# Termix sets itself up on first start (database, keys, admin account), so the
# installer only prepares the data folder. Reinstalling never touches existing
# data: Termix's database, keys and plugins in data/ are kept.
mkdir -p /mnt/server/data

# The installer runs as root; hand the folder to the UID/GID that owns the
# server volume, which is the user Wings runs the server as.
server_uid="$(stat -c '%u' /mnt/server)"
server_gid="$(stat -c '%g' /mnt/server)"
chown "${server_uid}:${server_gid}" /mnt/server/data
# The data folder holds every saved host credential and the key that encrypts them.
chmod 0700 /mnt/server/data

echo "Termix installation complete. Data directory: /home/container/data"
