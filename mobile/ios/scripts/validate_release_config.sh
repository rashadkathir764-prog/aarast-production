#!/bin/sh
set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

fail() {
  echo "error: $1" >&2
  exit 1
}

decode_define() {
  encoded="$1"
  if decoded="$(printf '%s' "$encoded" | /usr/bin/base64 -D 2>/dev/null)"; then
    printf '%s' "$decoded"
    return 0
  fi
  if decoded="$(printf '%s' "$encoded" | /usr/bin/base64 --decode 2>/dev/null)"; then
    printf '%s' "$decoded"
    return 0
  fi
  return 1
}

api_base_url=""
dev_bypass="false"
old_ifs="$IFS"
IFS=','
for encoded in ${DART_DEFINES:-}; do
  decoded="$(decode_define "$encoded")" || fail "Release dart-defines contain invalid Base64."
  key="${decoded%%=*}"
  value="${decoded#*=}"
  case "$key" in
    AARAST_API_BASE_URL) api_base_url="$value" ;;
    AARAST_DEV_BYPASS_LOGIN_GATES) dev_bypass="$value" ;;
  esac
done
IFS="$old_ifs"

[ -n "$api_base_url" ] || fail "Release builds require --dart-define=AARAST_API_BASE_URL=https://your-production-api."

case "$api_base_url" in
  https://*) ;;
  *) fail "AARAST_API_BASE_URL must use HTTPS in Release builds." ;;
esac

compact_url="$(printf '%s' "$api_base_url" | tr -d '[:space:]')"
[ "$compact_url" = "$api_base_url" ] || fail "AARAST_API_BASE_URL must not contain whitespace."

authority_and_path="${api_base_url#https://}"
authority="${authority_and_path%%/*}"
[ -n "$authority" ] || fail "AARAST_API_BASE_URL must include a public host."
case "$authority" in
  \[*\]) fail "AARAST_API_BASE_URL must use a DNS host or public IPv4 address." ;;
esac
case "$api_base_url" in
  *'@'*|*'?'*|*'#'*) fail "AARAST_API_BASE_URL must not contain credentials, query parameters, or fragments." ;;
esac

host="$(printf '%s' "$authority" | sed 's/:.*$//' | tr '[:upper:]' '[:lower:]')"
[ -n "$host" ] || fail "AARAST_API_BASE_URL must include a public host."

# A host made only of digits and dots must be a syntactically valid IPv4
# address. This prevents malformed numeric hosts from bypassing the private
# network checks through platform-specific URL parsing differences.
case "$host" in
  *[!0-9.]*) ;;
  *)
    ipv4_ifs="$IFS"
    IFS='.'
    set -- $host
    IFS="$ipv4_ifs"
    [ "$#" -eq 4 ] || fail "AARAST_API_BASE_URL contains an invalid IPv4 address."
    for octet in "$@"; do
      case "$octet" in
        ''|*[!0-9]*) fail "AARAST_API_BASE_URL contains an invalid IPv4 address." ;;
      esac
      [ "$octet" -le 255 ] || fail "AARAST_API_BASE_URL contains an invalid IPv4 address."
    done
    ;;
esac

case "$host" in
  localhost|*.localhost|0.0.0.0|127.*|10.*|169.254.*|192.168.*)
    fail "AARAST_API_BASE_URL must not target a local or private host."
    ;;
  172.*)
    second_octet="$(printf '%s' "$host" | cut -d. -f2)"
    case "$second_octet" in
      ''|*[!0-9]*) ;;
      *)
        if [ "$second_octet" -ge 16 ] && [ "$second_octet" -le 31 ]; then
          fail "AARAST_API_BASE_URL must not target a local or private host."
        fi
        ;;
    esac
    ;;
esac

case "$(printf '%s' "$dev_bypass" | tr '[:upper:]' '[:lower:]')" in
  true|1) fail "AARAST_DEV_BYPASS_LOGIN_GATES must stay disabled in Release builds." ;;
esac
