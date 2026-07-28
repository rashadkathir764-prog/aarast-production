#!/bin/sh
set -eu

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_public_https_origin() {
  name="$1"
  value="$2"
  case "$value" in
    https://*) ;;
    *) fail "$name must be a public HTTPS origin" ;;
  esac
  rest="${value#https://}"
  case "$rest" in
    ""|*"/"*|*"?"*|*"#"*|*"@"*)
      fail "$name must be a public HTTPS origin"
      ;;
  esac
  host="${rest%%:*}"
  case "$host" in
    localhost|*.localhost|*.local|0.0.0.0|127.*|10.*|169.254.*|192.168.*)
      fail "$name must be a public HTTPS origin"
      ;;
    172.*)
      second="${host#172.}"
      second="${second%%.*}"
      case "$second" in
        1[6-9]|2[0-9]|3[01])
          fail "$name must be a public HTTPS origin"
          ;;
      esac
      ;;
  esac
}

manifest=/usr/share/nginx/html/aarast-build-config.json
[ -r "$manifest" ] || fail "admin build config manifest is missing"

build_origin="$(
  sed -n 's/^{"apiOrigin":"\([^"]*\)"}$/\1/p' "$manifest"
)"
[ -n "$build_origin" ] || fail "admin build config manifest is invalid"

: "${API_ORIGIN:?API_ORIGIN is required}"
: "${ADMIN_PUBLIC_ORIGIN:?ADMIN_PUBLIC_ORIGIN is required}"
: "${CORS_ORIGINS:?CORS_ORIGINS is required}"

require_public_https_origin API_ORIGIN "$API_ORIGIN"
require_public_https_origin ADMIN_PUBLIC_ORIGIN "$ADMIN_PUBLIC_ORIGIN"

[ "$build_origin" = "$API_ORIGIN" ] ||
  fail "build API origin does not match runtime API origin"

cors_compact="$(printf '%s' "$CORS_ORIGINS" | tr -d '[:space:]')"
cors_match=false
old_ifs="$IFS"
IFS=','
for origin in $cors_compact; do
  if [ "$origin" = "$ADMIN_PUBLIC_ORIGIN" ]; then
    cors_match=true
    break
  fi
done
IFS="$old_ifs"

[ "$cors_match" = true ] ||
  fail "ADMIN_PUBLIC_ORIGIN is not present in CORS_ORIGINS"

exec /docker-entrypoint.sh "$@"
