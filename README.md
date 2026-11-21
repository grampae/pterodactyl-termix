# Pterodactyl Termix

Runs [Termix](https://github.com/Termix-SSH/Termix) as a Pterodactyl server, so Wings manages it like everything else.

This image wraps the official `ghcr.io/termix-ssh/termix` image. Termix doesn't change. The wrapper adapts it for Wings:

- **Data:** the database, keys, plugins and uploads live in `/home/container/data` (set through `DATA_DIR`), not in `/app/data`.
- **Port:** Termix listens on the server's primary allocation (`SERVER_PORT`).
- **Startup:** the custom entrypoint runs Pterodactyl's `STARTUP` command (`/entrypoint.sh`, Termix's own startup script).
- **HTTPS:** Termix's built-in HTTPS is turned off, because it writes to a fixed path that's read-only under Wings. Put Termix behind your reverse proxy for TLS.

Wings already runs containers the way Termix's own strictest setup describes: a non-root user, a read-only root filesystem and a tmpfs `/tmp`. In that mode, Termix's plugins share the core process's user instead of each getting its own.

## Setup

1. Push to `main`. The workflow publishes `ghcr.io/grampae/pterodactyl-termix:26.11.2` and `:latest`. Make the package public, or configure registry credentials in Wings.
2. Import `egg-termix.json` into the panel.
3. Create a server:
   - **Memory:** at least 1536 MB. Termix idles around 450–600 MB with the standard plugins, and more with extra plugins or remote desktop.
   - **Disk:** 5 GB or more.
   - **Allocation:** one port. Pick one that doesn't clash with Wings' own ports (8080 for the API, 2022 for SFTP).
4. Start the server. It's ready when the console shows `Termix backend started successfully`. Open `http://<node>:<port>` and create the admin account.

To build locally instead, tag the image `pterodactyl-termix:26.11.2` and set the egg image to `~pterodactyl-termix:26.11.2`. The `~` prefix tells Wings not to pull it.

## Updating Termix

Run the workflow manually with a new `termix_version`, add the new tag to the egg's Docker images, then switch the server to the new image and restart. Back up `data/` first. Reinstalling the server never deletes `data/`.

## Notes

- **Web UI copy:** under Wings the root filesystem is read-only, so upstream Termix would copy its ~140 MB web UI into the RAM-backed `/tmp` on every start, and that's more than Wings' default 100 MB `/tmp`. Instead, the image points `/app/html` at `/home/container/.termix-html` and fills it from a pristine copy in the image. That happens on the first start and again whenever the Termix version or `BASE_PATH` changes. It uses about 140 MB of the server's disk and no RAM, and you don't need to change `tmpfs_size`.
- **Expected warning:** `WARNING: Data directory is not writable` in the log refers to the unused `/app/data` and can be ignored.
- **`VOLUME /app/data`:** the upstream image declares this, so Docker creates an unused anonymous volume for the container. To clean them up now and then, run `docker volume ls -f dangling=true`.
- **Access:** `data/` holds every saved host credential and the key that encrypts them. Anyone with file-manager or SFTP access to this server in the panel can read it, so keep panel access to it admin-only.
- **Networking:** Termix connects out to your hosts over SSH from inside the Wings container. If your hosts are reached over a VPN or mesh network running on the node, test one host before relying on it.
