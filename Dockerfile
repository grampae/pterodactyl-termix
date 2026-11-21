ARG TERMIX_VERSION=26.11.2
FROM ghcr.io/termix-ssh/termix:${TERMIX_VERSION}

LABEL org.opencontainers.image.title="Pterodactyl Termix Runtime" \
      org.opencontainers.image.description="Pterodactyl-compatible wrapper around the official Termix image" \
      org.opencontainers.image.source="https://github.com/grampae/pterodactyl-termix"

USER root

# Pterodactyl convention: a user named "container" with home /home/container.
# Wings still runs the server with its own configured UID/GID; uid 1000 is
# already taken by "node" in the upstream image, so let useradd pick one.
RUN useradd -m -d /home/container -s /bin/bash container \
    && chown -R container:container /home/container

COPY pterodactyl-entrypoint.sh /pterodactyl-entrypoint.sh
COPY install.sh /usr/local/share/pterodactyl-termix/install.sh
RUN chmod 0755 /pterodactyl-entrypoint.sh /usr/local/share/pterodactyl-termix/install.sh

# Termix's backend reads DATA_DIR everywhere, so the database, keys, plugins
# and uploads live in the server volume instead of /app/data.
ENV USER=container \
    HOME=/home/container \
    DATA_DIR=/home/container/data \
    ENABLE_SSL=false

WORKDIR /home/container

# Root so the same image can be the egg's installer container (writes to
# /mnt/server). Wings overrides the user for the runtime container.
USER root

ENTRYPOINT ["/pterodactyl-entrypoint.sh"]
CMD ["pterodactyl"]
