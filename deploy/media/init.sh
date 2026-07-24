#!/bin/sh

set -eu

: "${MINIO_ROOT_USER:?MINIO_ROOT_USER is required}"
: "${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD is required}"
: "${AARAST_MEDIA_BUCKET:?AARAST_MEDIA_BUCKET is required}"
: "${AARAST_MEDIA_ACCESS_KEY_ID:?AARAST_MEDIA_ACCESS_KEY_ID is required}"
: "${AARAST_MEDIA_SECRET_ACCESS_KEY:?AARAST_MEDIA_SECRET_ACCESS_KEY is required}"

case "$AARAST_MEDIA_BUCKET" in
  *[!a-z0-9.-]*|.*|*.|*..*)
    echo "FAIL: media bucket name is not DNS-compatible" >&2
    exit 1
    ;;
esac

if [ "${#AARAST_MEDIA_BUCKET}" -lt 3 ] ||
   [ "${#AARAST_MEDIA_BUCKET}" -gt 63 ]; then
  echo "FAIL: media bucket name is not DNS-compatible" >&2
  exit 1
fi

if [ "$MINIO_ROOT_USER" = "$AARAST_MEDIA_ACCESS_KEY_ID" ] ||
   [ "$MINIO_ROOT_PASSWORD" = "$AARAST_MEDIA_SECRET_ACCESS_KEY" ]; then
  echo "FAIL: Backend media credentials must differ from MinIO root" >&2
  exit 1
fi

if [ "${#AARAST_MEDIA_ACCESS_KEY_ID}" -lt 3 ] ||
   [ "${#AARAST_MEDIA_ACCESS_KEY_ID}" -gt 20 ] ||
   [ "${#AARAST_MEDIA_SECRET_ACCESS_KEY}" -lt 8 ] ||
   [ "${#AARAST_MEDIA_SECRET_ACCESS_KEY}" -gt 40 ]; then
  echo "FAIL: Backend media service-account credentials are too short" >&2
  exit 1
fi

POLICY_FILE=/tmp/aarast-backend-media-policy.json
. /opt/aarast/media/backend-policy.sh
write_aarast_backend_media_policy "$AARAST_MEDIA_BUCKET" "$POLICY_FILE"

mc alias set root http://media:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
mc mb --ignore-existing "root/$AARAST_MEDIA_BUCKET"

# Reset anonymous access before applying the exact four public prefixes.
mc anonymous set none "root/$AARAST_MEDIA_BUCKET"
mc anonymous set download "root/$AARAST_MEDIA_BUCKET/user-avatar"
mc anonymous set download "root/$AARAST_MEDIA_BUCKET/provider-logo"
mc anonymous set download "root/$AARAST_MEDIA_BUCKET/provider-cover"
mc anonymous set download "root/$AARAST_MEDIA_BUCKET/service-image"
mc anonymous set none "root/$AARAST_MEDIA_BUCKET/chat-image"

if mc admin user svcacct info \
  root "$AARAST_MEDIA_ACCESS_KEY_ID" >/dev/null 2>&1; then
  mc admin user svcacct edit \
    root "$AARAST_MEDIA_ACCESS_KEY_ID" \
    --secret-key "$AARAST_MEDIA_SECRET_ACCESS_KEY" \
    --policy "$POLICY_FILE" \
    --name aarast-backend \
    --description "Aarast Backend bucket-prefix access" >/dev/null
else
  mc admin user svcacct add \
    root "$MINIO_ROOT_USER" \
    --access-key "$AARAST_MEDIA_ACCESS_KEY_ID" \
    --secret-key "$AARAST_MEDIA_SECRET_ACCESS_KEY" \
    --policy "$POLICY_FILE" \
    --name aarast-backend \
    --description "Aarast Backend bucket-prefix access" >/dev/null
fi

mc admin user svcacct info root "$AARAST_MEDIA_ACCESS_KEY_ID" >/dev/null
echo "PASS: MinIO bucket, public prefixes, and Backend service account are ready"
