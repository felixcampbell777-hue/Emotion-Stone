# World Rise dedicated hosting

The first container target is Linux x86_64, Godot 4.5.1. Clients run the ordinary game and do not need Docker. The server uses no display, GPU, microphone or audio device. Hosting integration is accepted only after the separate server/client and persistence tests pass; `build-server` itself certifies only content validation and packaging.

## Build and start

Complete the LFS/bootstrap steps in PORTABLE-TOOLS.md first. From the checkout root:

```sh
./tools/platform.sh build-server
docker compose -f hosting/compose.yaml build
mkdir -p hosting/secrets
python3 -c 'import secrets; from pathlib import Path; p=Path("hosting/secrets/server_password"); p.exists() or p.write_text(secrets.token_urlsafe(32)+"\n"); p.chmod(0o600)'
docker compose -f hosting/compose.yaml up -d
docker compose -f hosting/compose.yaml ps
```

`build-server --skip-tests` skips content validation and is explicitly untested packaging. Neither mode runs the full multiplayer/voice/combat acceptance matrix. The exporter restores the previous client presets. A versioned executable, durable helper, notices and SHA-256 manifest are written to ignored `output/linux-server/v<VERSION>/`. Change both Compose image/build version fields deliberately with a release; never substitute an unpinned latest image. The base Python image is pinned by digest. OS security updates require a reviewed image rebuild.

The example binds game UDP 24571 and authenticated voice UDP 24572 to loopback. Set `WORLD_RISE_BIND_ADDRESS` to a private LAN/VPN interface address when ready. The voice channel uses a separate authenticated UDP socket with an ephemeral session token delivered by the authenticated game session; tokens are not persistent configuration or a public admin API. Registration through Docker NAT must be tested with the actual client endpoint. The initial transport requires a trusted private VPN; set it up before exposing the port to remote friends. Ordinary ENet does not encrypt a password or voice stream. Do not publish this prototype unauthenticated on the public Internet. Supply membership secrets through the ignored `hosting/secrets/server_password`, mounted as a Docker secret, and share credentials out of band. No administration socket is exposed.

On native Linux, file-backed Compose secrets retain host ownership. Before starting, give only the service UID access: `sudo chown 10001:10001 hosting/secrets/server_password` and `sudo chmod 600 hosting/secrets/server_password`. Docker Desktop on this Mac was tested with UID 10001 successfully; verify readability on another host with `docker compose -f hosting/compose.yaml run --rm --no-deps --entrypoint python3 world-rise -c 'from pathlib import Path; assert Path("/run/secrets/server_password").read_bytes().strip()'`. This check prints no secret.

The image runs UID/GID 10001 with a read-only application, a bounded temporary filesystem, dropped capabilities and a persistent named `/data` volume. Docker initializes the volume ownership for that UID. For a host bind mount create it with matching ownership first. Secrets are separate from the data volume and backups. Runtime options: `WORLD_RISE_PORT` (game UDP port, default 24571), `WORLD_RISE_VOICE_PORT` (separate authenticated voice UDP port, default 24572), `WORLD_RISE_DATA_DIR` (default `/data`), `WORLD_RISE_PASSWORD_FILE` (default `/run/secrets/server_password`), and the explicit `WORLD_RISE_PRIVATE_VPN=1` transport acknowledgement. Compose uses matching external/internal port numbers so the advertised voice port remains reachable through Docker NAT. When changing the game port, explicitly choose a distinct voice port as well (normally game+1). Direct server launches default voice to game+1; game 65535 therefore requires an explicit voice port. Both ports must be distinct and within 1024–65535.

## Stop, health and recovery

```sh
docker compose -f hosting/compose.yaml stop
docker compose -f hosting/compose.yaml start
docker compose -f hosting/compose.yaml logs --tail=100
```

SIGTERM asks the supervisor to create `/data/stop.request`. The server stops joins, commits the final state, removes readiness and exits. It has 25 seconds before supervisor termination and 35 seconds before Docker's final kill. Readiness is `/data/ready.json`, refreshed by the live simulation; the health check fails after 15 seconds without a refresh. Persistent write failures must reject durable mutations and clear readiness. Log rotation retains at most three 10 MB files per container.

`restart: unless-stopped` restarts an exited/crashed process; Docker health status alone never restarts one. An administrative `docker stop`/`docker kill` suppresses automatic restart until explicitly started again; crash testing kills the Godot child instead. A stalled process therefore needs an external supervisor/operator to inspect status and issue an orderly restart; do not assume a green Docker process means a healthy simulation. No automatic updater or public administration endpoint is configured. Keep whitelist/kick/ban/save/restart administration local to the host and use only commands actually exposed by the server version.

After a forced kill, launch the same server version to recover the last durable checkpoint/journal, inspect status, then stop cleanly before a backup. Runtime rejects incompatible protocol/content/save versions. Record the exact image digest and package manifest with each accepted backup; a development version tag can be rebuilt with incompatible candidate formats. Keep the prior image and pre-upgrade snapshot; never let an older image write a newer schema. Disk-full/read-only storage is an operation failure, never a successful in-memory purchase.

## Local administration

Run commands inside the server container as its existing non-root user:

```sh
docker compose -f hosting/compose.yaml exec world-rise python3 /app/admin.py status
docker compose -f hosting/compose.yaml exec world-rise python3 /app/admin.py save
docker compose -f hosting/compose.yaml exec world-rise python3 /app/admin.py kick <character-id>
docker compose -f hosting/compose.yaml exec world-rise python3 /app/admin.py ban <character-id>
docker compose -f hosting/compose.yaml exec world-rise python3 /app/admin.py whitelist --enable <character-id> <character-id>
docker compose -f hosting/compose.yaml exec world-rise python3 /app/admin.py whitelist --disable
docker compose -f hosting/compose.yaml exec world-rise python3 /app/admin.py restart
```

Status returns connected peer/character IDs. These IDs are 32 lowercase hex characters. Whitelist and bans are durable world configuration; an empty enabled whitelist admits nobody. The CLI serializes local administrator calls with a process lock, installs a bounded request atomically and waits for a matching result ID. A timeout is an uncertain outcome: inspect status/health before repeating. Restart saves first and asks the process to exit; the Compose restart policy brings it back. There is no remote administrative endpoint. Do not place administrator request files in backups; the helper excludes them to prevent command replay after restore.

## Offline rolling backup and restore

A volume is not a backup. Stop cleanly, then snapshot it to separate storage. The helper holds the same OS writer lock throughout the snapshot and also rejects a readiness file, including a server still starting before its first health update. If the writer lock is missing, start/recover/stop the matching server first. It stores seven rolling archives by default, verifies every file checksum before restore, refuses symlinks/path traversal, and restores only to an empty target. Run it with volume access; copy `hosting/backup.py` into an operations environment or mount it read-only. Example using the Compose volume without hard-coding its project-prefixed name:

```sh
docker compose -f hosting/compose.yaml stop
mkdir -p hosting/backups
docker compose -f hosting/compose.yaml run --rm --no-deps --user "$(id -u):$(id -g)" --entrypoint python3 -v "$PWD/hosting/backup.py:/ops/backup.py:ro" -v "$PWD/hosting/backups:/backups" world-rise /ops/backup.py backup /data /backups
```

For restore create a **new empty volume**, run `/ops/backup.py restore /backups/<chosen>.tar.gz /data` against it and start the matching server image. Confirm world UUID/revision, characters, encounter state and claims with two disposable clients before switching the service to the restored volume. Retain the old stopped volume for rollback. Copy accepted backups off the host, test restore periodically and retain one pre-upgrade archive outside rolling retention. A hash check alone does not establish playable recovery.

## Network access

LAN clients use the host's LAN address and configured game UDP port; the authenticated game connection advertises the separate voice port. Allow both configured UDP ports through the host firewall. For public hosting, router forwarding maps both public UDP ports to matching ports at the server LAN address; the host may also need a public address/DNS. Docker does not create a router mapping and does not solve CGNAT. Use a private VPN or a VPS when forwarding is unavailable. Public transport needs an authenticated encryption design and validation before becoming a supported hosting mode. Never expose local administration or Docker's control socket.
