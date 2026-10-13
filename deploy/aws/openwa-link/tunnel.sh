#!/bin/sh
# Forwards :2785 here to OpenWA's loopback port on the server that runs it.
# The key there is restricted to this forward from this host's address only
# (no shell). The container restarts when the connection drops.
set -eu
: "${OPENWA_LINK_TARGET:?OPENWA_LINK_TARGET is required (user@host)}"
exec ssh -N -T \
  -o BatchMode=yes \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile=/keys/known_hosts \
  -i /keys/tunnel \
  -L 0.0.0.0:2785:127.0.0.1:2786 \
  "$OPENWA_LINK_TARGET"
