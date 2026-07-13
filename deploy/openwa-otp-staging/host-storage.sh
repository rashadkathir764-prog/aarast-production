#!/bin/sh
set -eu

mode="${1:-check}"
root="${2:-/var/lib/aarast-otp-staging}"
container="$root/secure.luks"
mountpoint="$root/secure"
mapper_name="aarast_otp_staging_crypt"
mapper="/dev/mapper/$mapper_name"

read_key() {
  IFS= read -r luks_key
  luks_key="$(printf %s "$luks_key" | tr -d '\r')"
  test -n "$luks_key"
}

mount_secure_data() {
  sudo -n install -d -m 0700 "$mountpoint"
  sudo -n mount -o nodev,nosuid,noexec "$mapper" "$mountpoint"
  sudo -n test -f "$mountpoint/.aarast-otp-encrypted"
}

create_storage() {
  ! sudo -n test -e "$container"
  ! sudo -n test -e "$mapper"
  read_key
  sudo -n install -d -m 0700 "$root"
  cleanup=true
  trap '
    status=$?
    unset luks_key
    if [ "$status" -ne 0 ] && [ "${cleanup:-false}" = true ]; then
      sudo -n umount "$mountpoint" 2>/dev/null || true
      sudo -n cryptsetup close "$mapper_name" 2>/dev/null || true
      sudo -n rm -f "$container"
    fi
    exit "$status"
  ' EXIT INT TERM
  sudo -n truncate -s "${LUKS_FILE_SIZE:-4G}" "$container"
  sudo -n chmod 0600 "$container"
  printf %s "$luks_key" | sudo -n cryptsetup luksFormat \
    --type luks2 --batch-mode --key-file - "$container"
  printf %s "$luks_key" | sudo -n cryptsetup open \
    --type luks2 --key-file - "$container" "$mapper_name"
  unset luks_key
  sudo -n mkfs.ext4 -q -L aarast_otp_staging "$mapper"
  sudo -n install -d -m 0700 "$mountpoint"
  sudo -n mount -o nodev,nosuid,noexec "$mapper" "$mountpoint"
  sudo -n touch "$mountpoint/.aarast-otp-encrypted"
  sudo -n chmod 0600 "$mountpoint/.aarast-otp-encrypted"
  cleanup=false
  trap - EXIT INT TERM
}

unlock_storage() {
  sudo -n test -f "$container"
  if ! sudo -n test -e "$mapper"; then
    read_key
    printf %s "$luks_key" | sudo -n cryptsetup open \
      --type luks2 --key-file - "$container" "$mapper_name"
    unset luks_key
  fi
  if ! sudo -n mountpoint -q "$mountpoint"; then mount_secure_data; fi
}

check_storage() {
  sudo -n test -e "$mapper"
  test "$(sudo -n findmnt -T "$mountpoint" -n -o SOURCE)" = "$mapper"
  sudo -n test -f "$mountpoint/.aarast-otp-encrypted"
  options="$(sudo -n findmnt -T "$mountpoint" -n -o OPTIONS)"
  echo "$options" | grep -qw nodev
  echo "$options" | grep -qw nosuid
  echo "$options" | grep -qw noexec
}

close_storage() {
  sudo -n umount "$mountpoint"
  sudo -n cryptsetup close "$mapper_name"
}

verify_key() {
  read_key
  printf %s "$luks_key" | sudo -n cryptsetup open \
    --test-passphrase --key-file - "$container"
  unset luks_key
}

case "$mode" in
  create) create_storage ;;
  unlock) unlock_storage ;;
  check) check_storage ;;
  close) close_storage ;;
  verify-key) verify_key ;;
  *) echo "usage: $0 create|unlock|check|close|verify-key [storage-root]" >&2; exit 64 ;;
esac
