#!/bin/sh
set -eu

mode="${1:-check}"
secure_path="${2:-/var/lib/aarast-otp-staging/secure}"
expected_mapper="/dev/mapper/aarast_otp_staging_crypt"
chain="AARAST-OTP-STAGING"
source_subnet="172.30.50.0/28"

require_encrypted_mount() {
  source="$(findmnt -T "$secure_path" -n -o SOURCE)"
  test "$source" = "$expected_mapper"
  test -f "$secure_path/.aarast-otp-encrypted"
}

apply_rules() {
  test "$(id -u)" = "0"
  require_encrypted_mount
  iptables -N "$chain" 2>/dev/null || true
  iptables -F "$chain"
  for destination in \
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 \
    169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.168.0.0/16 \
    198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
  do
    iptables -A "$chain" -s "$source_subnet" -d "$destination" -j REJECT
  done
  iptables -A "$chain" -j RETURN
  iptables -C DOCKER-USER -j "$chain" 2>/dev/null || \
    iptables -I DOCKER-USER 1 -j "$chain"
  iptables -C INPUT -s "$source_subnet" -j REJECT 2>/dev/null || \
    iptables -I INPUT 1 -s "$source_subnet" -j REJECT
}

check_rules() {
  require_encrypted_mount
  iptables -C DOCKER-USER -j "$chain"
  iptables -C INPUT -s "$source_subnet" -j REJECT
  iptables -C "$chain" -s "$source_subnet" -d 10.0.0.0/8 -j REJECT
  iptables -C "$chain" -s "$source_subnet" -d 169.254.0.0/16 -j REJECT
  iptables -C "$chain" -s "$source_subnet" -d 172.16.0.0/12 -j REJECT
  iptables -C "$chain" -s "$source_subnet" -d 192.168.0.0/16 -j REJECT
}

remove_rules() {
  test "$(id -u)" = "0"
  while iptables -C DOCKER-USER -j "$chain" 2>/dev/null; do
    iptables -D DOCKER-USER -j "$chain"
  done
  while iptables -C INPUT -s "$source_subnet" -j REJECT 2>/dev/null; do
    iptables -D INPUT -s "$source_subnet" -j REJECT
  done
  iptables -F "$chain" 2>/dev/null || true
  iptables -X "$chain" 2>/dev/null || true
}

case "$mode" in
  apply) apply_rules ;;
  check) check_rules ;;
  remove) remove_rules ;;
  *) echo "usage: $0 apply|check|remove [secure-path]" >&2; exit 64 ;;
esac
