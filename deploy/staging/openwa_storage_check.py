#!/usr/bin/env python3
"""Read-only host preflight: a marker never substitutes for the LUKS2 mount."""
import argparse
import json
import pathlib
import subprocess
import sys


def validate_evidence(*, mount, secure, mapper, image, crypt_type, backing_file,
                      marker, session_database, credential_identity, encrypted_identity):
    if mount.get('target') != secure or mount.get('source') != mapper:
        raise ValueError('The dedicated encrypted mount is absent')
    if not {'nodev', 'nosuid', 'noexec'} <= set(mount.get('options', '').split(',')):
        raise ValueError('Required encrypted mount flags are absent')
    if crypt_type != 'LUKS2' or backing_file != image:
        raise ValueError('The mapper does not use the expected LUKS2 image')
    if not marker or not session_database:
        raise ValueError('The restored session storage is incomplete')
    if credential_identity != encrypted_identity:
        raise ValueError('The backend credential directory is not the encrypted directory')


def output(args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=10).stdout


def check(secure, mapper, image, credential):
    secure, image, credential = map(pathlib.Path, (secure, image, credential))
    if any(not p.is_absolute() or p.is_symlink() for p in (secure, image, credential)):
        raise ValueError('Storage paths must be absolute and must not be symbolic links')
    mount = json.loads(output(['findmnt', '-J', '-M', str(secure)]))['filesystems'][0]
    status = output(['cryptsetup', 'status', pathlib.Path(mapper).name])
    fields = dict(line.strip().split(':', 1) for line in status.splitlines()
                  if ':' in line and line[:1].isspace())
    backing = output(['losetup', '-n', '-O', 'BACK-FILE', fields['device'].strip()]).strip()
    marker = secure / '.aarast-full-staging-openwa-encrypted'
    database = secure / 'openwa' / 'openwa.sqlite'
    expected = (secure / 'backend-secret').stat()
    actual = credential.stat()
    validate_evidence(
        mount=mount, secure=str(secure), mapper=mapper, image=str(image),
        crypt_type=fields['type'].strip(), backing_file=backing,
        marker=marker.is_file() and not marker.is_symlink(),
        session_database=database.is_file() and not database.is_symlink() and database.stat().st_size > 0,
        credential_identity=(actual.st_dev, actual.st_ino),
        encrypted_identity=(expected.st_dev, expected.st_ino),
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('secure', 'mapper', 'image', 'credential'):
        parser.add_argument('--' + name, required=True)
    args = parser.parse_args()
    try:
        check(args.secure, args.mapper, args.image, args.credential)
    except (OSError, ValueError, KeyError, IndexError, subprocess.SubprocessError):
        print('FAIL: OpenWA requires its verified encrypted session and credential mounts', file=sys.stderr)
        return 1
    print('PASS: OpenWA encrypted storage and backend credential bind verified')
    return 0


if __name__ == '__main__':
    sys.exit(main())
