#!/bin/sh
set -eu

mode="${1:-check}"
secure_path="${2:-/var/lib/aarast-otp-staging/secure}"
expected_mapper="/dev/mapper/aarast_otp_staging_crypt"
chain="AARAST-OTP-STAGING"
source_subnet="10.77.50.0/28"
staging_supernet="10.77.50.0/26"
protected_subnets="10.77.50.16/28 10.77.50.32/28 10.77.50.48/28"
proxy_network="aarast_otp_staging_proxy"
proxy_subnet="10.77.50.16/28"
npm_container="${NPM_CONTAINER_NAME:-nginx-proxy-manager}"

require_encrypted_mount() {
  source="$(findmnt -T "$secure_path" -n -o SOURCE)"
  test "$source" = "$expected_mapper"
  test -f "$secure_path/.aarast-otp-encrypted"
}

proxy_network_is_valid() {
  test "$(docker network inspect -f '{{.Internal}}' "$proxy_network")" = true
  test "$(docker network inspect -f '{{.EnableIPv6}}' "$proxy_network")" = false
  test "$(docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' "$proxy_network")" = "$proxy_subnet"
  npm_id="$(docker inspect -f '{{.Id}}' "$npm_container")"
  docker network inspect -f '{{json .Containers}}' "$proxy_network" | grep -q "$npm_id"
}

ensure_proxy_network() {
  if ! docker network inspect "$proxy_network" >/dev/null 2>&1; then
    docker network create --driver bridge --internal --subnet "$proxy_subnet" \
      "$proxy_network" >/dev/null
  fi
  test "$(docker network inspect -f '{{.Internal}}' "$proxy_network")" = true
  test "$(docker network inspect -f '{{.EnableIPv6}}' "$proxy_network")" = false
  test "$(docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' "$proxy_network")" = "$proxy_subnet"
  if ! proxy_network_is_valid; then
    docker network connect --gw-priority=-1 "$proxy_network" "$npm_container"
  fi
  proxy_network_is_valid
}

apply_rules() {
  test "$(id -u)" = "0"
  require_encrypted_mount
  ensure_proxy_network
  iptables -N "$chain" 2>/dev/null || true
  iptables -F "$chain"
  for destination in \
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 \
    169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.168.0.0/16 \
    198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
  do
    iptables -A "$chain" -s "$source_subnet" -d "$destination" -j REJECT
  done
  for protected_subnet in $protected_subnets; do
    iptables -A "$chain" -s "$protected_subnet" -d "$staging_supernet" -j RETURN
    iptables -A "$chain" -s "$protected_subnet" -j REJECT
  done
  iptables -A "$chain" -j RETURN
  iptables -C DOCKER-USER -j "$chain" 2>/dev/null || \
    iptables -I DOCKER-USER 1 -j "$chain"
  while iptables -C INPUT -s "$source_subnet" -j REJECT 2>/dev/null; do
    iptables -D INPUT -s "$source_subnet" -j REJECT
  done
  iptables -C INPUT -s "$staging_supernet" -j REJECT 2>/dev/null || \
    iptables -I INPUT 1 -s "$staging_supernet" -j REJECT
  iptables -C INPUT -s "$staging_supernet" -m conntrack \
    --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -I INPUT 1 -s "$staging_supernet" -m conntrack \
      --ctstate ESTABLISHED,RELATED -j ACCEPT
}

check_rules() {
  require_encrypted_mount
  proxy_network_is_valid
  iptables -C DOCKER-USER -j "$chain"
  iptables -C INPUT -s "$staging_supernet" -m conntrack \
    --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -C INPUT -s "$staging_supernet" -j REJECT
  iptables -C "$chain" -s "$source_subnet" -d 10.0.0.0/8 -j REJECT
  iptables -C "$chain" -s "$source_subnet" -d 169.254.0.0/16 -j REJECT
  iptables -C "$chain" -s "$source_subnet" -d 172.16.0.0/12 -j REJECT
  iptables -C "$chain" -s "$source_subnet" -d 192.168.0.0/16 -j REJECT
  for protected_subnet in $protected_subnets; do
    iptables -C "$chain" -s "$protected_subnet" -d "$staging_supernet" -j RETURN
    iptables -C "$chain" -s "$protected_subnet" -j REJECT
  done
}

remove_rules() {
  test "$(id -u)" = "0"
  while iptables -C DOCKER-USER -j "$chain" 2>/dev/null; do
    iptables -D DOCKER-USER -j "$chain"
  done
  while iptables -C INPUT -s "$staging_supernet" -j REJECT 2>/dev/null; do
    iptables -D INPUT -s "$staging_supernet" -j REJECT
  done
  while iptables -C INPUT -s "$staging_supernet" -m conntrack \
    --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; do
    iptables -D INPUT -s "$staging_supernet" -m conntrack \
      --ctstate ESTABLISHED,RELATED -j ACCEPT
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
