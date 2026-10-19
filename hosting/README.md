# Dedicated server operations

This is a development hosting candidate. Use the [full hosting guide](../docs/DEDICATED-SERVER.md) for configuration, private VPN/NAT, storage recovery and acceptance limits. Final multiplayer/voice/load acceptance requires a fresh package after the source freeze.

From the checkout root, after materializing Git LFS and completing [portable setup](../docs/PORTABLE-TOOLS.md):

```sh
./tools/platform.sh validate
./tools/platform.sh build-server
mkdir -p hosting/secrets
python3 -c 'import secrets; from pathlib import Path; p=Path("hosting/secrets/server_password"); p.exists() or p.write_text(secrets.token_urlsafe(32)+"\n"); p.chmod(0o600)'
docker compose -f hosting/compose.yaml build
docker compose -f hosting/compose.yaml up -d
docker compose -f hosting/compose.yaml ps
docker compose -f hosting/compose.yaml exec world-rise python3 /app/admin.py status
```

On native Linux, apply the [secret ownership step](../docs/DEDICATED-SERVER.md) before starting; Compose file secrets retain host ownership.

The ordinary client needs no Docker: open World Rise's connection screen and join the host address/game UDP port using the membership password. Both game UDP 24571 and separate authenticated voice UDP 24572 must be reachable. The example binds loopback; set `WORLD_RISE_BIND_ADDRESS` to the intended LAN/private VPN interface. Keep published/container voice ports identical; when changing ports, set both `WORLD_RISE_PORT` and `WORLD_RISE_VOICE_PORT` deliberately. Use a trusted private VPN for remote play. Docker does not solve router forwarding or CGNAT.

The container is Linux x86_64, non-root UID/GID 10001, read-only application, persistent named `/data`, bounded logs and 2 CPU/2 GiB defaults. Secrets remain outside Git and the data volume. `admin.py save`, `kick <character-id>`, `ban <character-id>`, `whitelist --enable <ids...>`, `whitelist --disable` and `restart` are local host commands; no remote administration endpoint is exposed.

Stop cleanly with `docker compose -f hosting/compose.yaml stop` before making a backup. The [backup/restore procedure](../docs/DEDICATED-SERVER.md#offline-rolling-backup-and-restore) uses `hosting/backup.py` against the stopped volume, retains seven archives by default, verifies checksums and restores only into a new empty volume. Test a restored world with the matching image and disposable clients before switching volumes. Keep an independent pre-upgrade snapshot and the old image.

For a disposable load fixture, use Compose project `wr-hosting-fixture`, then run `python3 tools/measure_hosting.py --seconds 30 --expect-players 8 --bulk-save-every 3` while eight test clients are connected. Mutation stress refuses other Compose project names. This measures that scenario; it does not certify the Internet/combat/voice acceptance matrix.

Apple Silicon Docker results use x86_64 emulation and must be identified as such. macOS client candidates require ASTC texture imports, the pinned universal template and the shipped native capture payload; they use an ad-hoc signature rather than a notarized public distribution. Windows packages can be exported here but require actual Windows execution before claiming runtime support. ARM64 server images are not yet verified.
