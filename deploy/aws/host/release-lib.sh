#!/bin/bash
# Shared by deploy.sh and rollback.sh: one implementation of the steps a
# release start needs. Sourced, never run on its own.

env_file=/opt/aarast/app/.env

# Push notifications: the FCM service account lives in SSM as a SecureString.
# It is written root-made, backend-readable only (uid 1000, mode 0600) and is
# never printed. Without it the backend starts with push disabled.
release_push_env() {
  local region key_file
  region=$(sed -n 's/^AWS_REGION=//p' "$env_file")
  install -d -m 0755 /opt/aarast/firebase
  key_file=/opt/aarast/firebase/service-account.json
  if aws ssm get-parameter --region "$region" --name /aarast/firebase-service-account \
       --with-decryption --query Parameter.Value --output text >"$key_file.tmp" 2>/dev/null; then
    chown 1000:1000 "$key_file.tmp"
    chmod 0600 "$key_file.tmp"
    mv -f "$key_file.tmp" "$key_file"
    export PUSH_NOTIFICATIONS_ENABLED=true
    FIREBASE_PROJECT_ID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["project_id"])' "$key_file")
    export FIREBASE_PROJECT_ID
    echo "push notifications enabled for $FIREBASE_PROJECT_ID"
  else
    rm -f "$key_file.tmp"
    export PUSH_NOTIFICATIONS_ENABLED=false
    echo "push notifications disabled (no FCM key in SSM)"
  fi
}

# docker compose against the host env file, from the release's deploy/aws.
dc() { docker compose --env-file "$env_file" "$@"; }

# The release /opt/aarast/current points at, or nothing on a first deploy.
release_current() {
  # `readlink -f` answers even for a missing link, so the link is checked first.
  if [ -L /opt/aarast/current ]; then basename "$(readlink -f /opt/aarast/current)"; fi
}

# A dump of the live database before anything changes it (RA-OP-05). Run from
# a release's deploy/aws. Kept five on the host and copied to the ops bucket.
release_backup_before() {
  local reason=$1 ops_bucket=$2 db owner stamp dir dump
  if [ -z "$(dc ps -q postgres 2>/dev/null)" ]; then
    echo "no running database yet: nothing to back up"
    return 0
  fi
  db=$(sed -n 's/^POSTGRES_DB=//p' "$env_file")
  owner=$(sed -n 's/^POSTGRES_OWNER_USER=//p' "$env_file")
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  dir=/opt/aarast/backups/pre-deploy
  install -d -m 0700 "$dir"
  dump="$dir/$stamp-$reason.dump"
  dc exec -T postgres pg_dump -U "$owner" -d "$db" --format=custom >"$dump.tmp"
  [ -s "$dump.tmp" ] || { rm -f "$dump.tmp"; echo "FAIL: the pre-deploy dump is empty" >&2; return 1; }
  mv -f "$dump.tmp" "$dump"
  aws s3 cp "$dump" "s3://$ops_bucket/backups/pre-deploy/$(basename "$dump")" --only-show-errors
  echo "pre-deploy backup: $(basename "$dump") ($(stat -c %s "$dump") bytes, copied to the ops bucket)"
  ls -1t "$dir"/*.dump 2>/dev/null | tail -n +6 | xargs -r rm -f
}

# Waits up to about four minutes for the backend health check.
release_wait_healthy() {
  local state=starting
  echo "waiting for the backend to become healthy"
  for _ in $(seq 1 40); do
    state=$(docker inspect --format '{{.State.Health.Status}}' "$(dc ps -q backend)" 2>/dev/null || echo starting)
    [ "$state" = healthy ] && break
    sleep 6
  done
  dc ps --format 'table {{.Service}}\t{{.Status}}'
  if [ "$state" != healthy ]; then
    dc logs --tail 60 backend
    return 1
  fi
}
