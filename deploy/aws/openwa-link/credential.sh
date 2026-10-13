#!/bin/sh
# Fetches the OpenWA backend credential every 10 minutes (the key there runs
# one fixed command that prints it) and replaces /credential/openwa.env
# atomically, readable only by the backend user (uid 1000). The values are
# never printed.
set -eu
: "${OPENWA_LINK_TARGET:?OPENWA_LINK_TARGET is required (user@host)}"
out=/credential/openwa.env
while :; do
  tmp=$(mktemp /credential/.openwa.env.XXXXXX)
  if ssh -T \
      -o BatchMode=yes \
      -o ConnectTimeout=20 \
      -o StrictHostKeyChecking=yes \
      -o UserKnownHostsFile=/keys/known_hosts \
      -i /keys/credential \
      "$OPENWA_LINK_TARGET" </dev/null >"$tmp" 2>/dev/null \
    && grep -q '^OPENWA_SESSION_ID=' "$tmp" \
    && grep -q '^OPENWA_API_KEY=' "$tmp"; then
    chown 1000:1000 "$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" "$out"
    echo "openwa credential refreshed"
    sleep 600
  else
    rm -f "$tmp"
    echo "openwa credential fetch failed; retrying in 60s" >&2
    sleep 60
  fi
done
