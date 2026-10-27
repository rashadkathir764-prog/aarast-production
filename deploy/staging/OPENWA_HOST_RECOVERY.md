# OpenWA host storage and recovery

Snapshot date: 2026-10-27

This runbook covers the independently linked Test Release OpenWA service on
`rk-server` and the Aarast API at `https://aarast-api.shadowgardn.com`.
AWS verification was excluded by the owner during this incident.

## Incident and recovery

After a host reboot the LUKS2 session volume and secondary backend credential
bind were absent. Docker was running against ordinary directories underneath
the missing mounts. The OpenWA HTTP health check passed with zero sessions;
the rotator could not create its lock in the root-owned replacement directory.
The backend repeatedly failed its existing credential-file startup check.
Restarting that container alone cannot restore the missing mounts.

The original LUKS2 image is preserved and its header validates. Its encrypted
contents could not be inspected without the key. Its off-host key was
not found in the current local files, relevant backups, or Recycle Bin. The
known original key path was recovered from the initial deployment record;
the key itself was randomly generated and was not printed by that deployment.
Do not format or replace the original image to work around the missing key.

The independent session archive from 2026-10-03 was verified before recovery:

- SHA-256: `95e5f9560c040198f13ff82f199565b65d736f8712d5829072f5eca0683103ed`.
- Both SQLite quick checks passed; its session database contained one session.
- The restored archive excludes only the three Chromium process-lock symlinks.
- The current stopped master-authentication database was retained separately;
  fresh scoped transport/audit keys were issued by the existing bootstrap.
- Application PostgreSQL, Redis, media, and frontend data were not restored.

The recovery image is
`/var/lib/aarast-full-staging-openwa-test/session-data-recovery-20261026.luks`.
It mounts at `/var/lib/aarast-full-staging-openwa-test/secure` through
`/dev/mapper/aarast-full-staging-openwa-recovery-20261026`, with
`nodev,nosuid,noexec`. The old image and the ordinary placeholder directory
are preserved separately. The backend credential directory is again a bind
of `secure/backend-secret`.

## Startup ownership

Use `aarast-openwa.service` for OpenWA and its credential rotator. The host
overlay disables Docker's independent restart policy for these two services.
The systemd service requires both mount units, is configured to stop with them, and
runs `openwa_storage_check.py` before every start. The checker verifies the
actual mount source, LUKS2 mapper backing file, mount flags, session database,
marker, and identical device/inode for the encrypted credential directory and
its backend bind. A marker on an ordinary filesystem is insufficient.

Installed runtime files are:

- `/usr/local/lib/aarast/openwa_storage_check.py`.
- `/etc/aarast/openwa-host.compose.yml` (the checked-in host overlay).
- `/etc/aarast/openwa-host.env` (non-secret paths; mode `0600`).
- `/etc/systemd/system/aarast-openwa.service`.
- The systemd `.mount` units for the encrypted root and backend credential bind.

The host environment file supplies `OPENWA_SECURE_ROOT`, `OPENWA_MAPPER`,
`OPENWA_STORAGE_IMAGE`, `OPENWA_CREDENTIAL_BIND`, `OPENWA_ENV_FILE`,
`OPENWA_BASE_COMPOSE`, `OPENWA_ROUTE_COMPOSE`, and `OPENWA_HOST_COMPOSE`.
The three Compose files retain the same pinned OpenWA image, loopback-only
operator port, private network, 2 GiB memory limit and 1.5 CPU limit.
Do not change these settings as part of a storage recovery.

## After a host reboot

The encryption key deliberately remains off-server. Unattended boot cannot
unlock this volume. Until an operator unlocks it, the host service fails
closed rather than starting against an empty ordinary directory.

On the original Windows account, run the private operator helper:

```powershell
& "$env:LOCALAPPDATA\Aarast\OpenWaRecovery-20261026\unlock-storage.ps1"
```

It decrypts `storage-key.dpapi` in memory, verifies the LUKS passphrase over
authenticated SSH, opens the mapper when needed, and starts the two mount
units. It never prints or persists the plaintext key on the server. The
folder ACL grants the current Windows account access only. A second identical
protected copy and the operator helpers are saved under
`D:\projects\aarast-backups\openwa-recovery-20261026`, with a current-user-only
ACL and a verified ciphertext checksum. DPAPI recovery depends on that Windows
account; an independently recoverable offline key backup is still an operator
responsibility. Do not delete these recovery folders during cleanup.

Then start the guarded runtime:

```sh
sudo systemctl reset-failed aarast-openwa.service
sudo systemctl start aarast-openwa.service
sudo systemctl status aarast-openwa.service --no-pager
```

After OpenWA restores its linked session, reconcile credentials through the
reviewed bootstrap, especially after a long outage. This is a server-side
shell command; it reads configuration paths without printing secret values:

```sh
sudo sh -c '
  set -eu
  . /etc/aarast/openwa-host.env
  docker compose --env-file "$OPENWA_ENV_FILE" \
    -f "$OPENWA_BASE_COMPOSE" -f "$OPENWA_ROUTE_COMPOSE" \
    -f "$OPENWA_HOST_COMPOSE" run --rm --no-deps openwa-bootstrap
'
```

If the existing backend is stopped, start that backend only after its mounted
credential is valid. Do not run a whole-stack deployment or migrations for a
messaging-storage incident. Require the real session `otp-readiness` to return
`ready:true` and the public API `/ready` to return `200` with OpenWA `up`.

For an ordinary OpenWA restart with its mounts already verified, use:

```sh
sudo systemctl restart aarast-openwa.service
```

Container health alone does not prove a linked session or OTP delivery. A
real recipient delivery/verification test needs a separately authorized
recipient; no real message was sent by this recovery.
