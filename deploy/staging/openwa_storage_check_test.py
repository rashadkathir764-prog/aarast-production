import importlib.util
import pathlib
import unittest


class StorageGuardTests(unittest.TestCase):
    def checker(self):
        path = pathlib.Path(__file__).with_name('openwa_storage_check.py')
        self.assertTrue(path.is_file(), 'The OpenWA host storage guard is missing')
        spec = importlib.util.spec_from_file_location('openwa_storage_check', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.validate_evidence

    def valid(self):
        return dict(
            mount={'target': '/secure', 'source': '/dev/mapper/otp',
                   'options': 'rw,nodev,nosuid,noexec,relatime'},
            secure='/secure', mapper='/dev/mapper/otp', image='/data/session.luks',
            crypt_type='LUKS2', backing_file='/data/session.luks',
            marker=True, session_database=True,
            credential_identity=(253, 42), encrypted_identity=(253, 42),
        )

    def test_verified_encrypted_storage_and_credential_alias_pass(self):
        self.checker()(**self.valid())

    def test_marker_on_ordinary_root_filesystem_is_rejected(self):
        data = self.valid()
        data['mount'] = dict(target='/', source='/dev/sda1', options='rw,relatime')
        with self.assertRaises(ValueError):
            self.checker()(**data)

    def test_other_encrypted_mapper_is_rejected(self):
        data = self.valid()
        data['mount']['source'] = '/dev/mapper/another-project'
        with self.assertRaises(ValueError):
            self.checker()(**data)

    def test_mapper_over_another_image_is_rejected(self):
        data = self.valid()
        data['backing_file'] = '/data/another-project.luks'
        with self.assertRaises(ValueError):
            self.checker()(**data)

    def test_plain_dmcrypt_is_not_accepted_as_the_luks2_volume(self):
        data = self.valid()
        data['crypt_type'] = 'PLAIN'
        with self.assertRaises(ValueError):
            self.checker()(**data)

    def test_each_required_mount_flag_is_enforced(self):
        check = self.checker()
        for flag in ['nodev', 'nosuid', 'noexec']:
            with self.subTest(flag=flag):
                data = self.valid()
                data['mount']['options'] = data['mount']['options'].replace(flag, '')
                with self.assertRaises(ValueError):
                    check(**data)

    def test_credential_directory_left_on_ordinary_disk_is_rejected(self):
        data = self.valid()
        data['credential_identity'] = (8, 80)
        with self.assertRaises(ValueError):
            self.checker()(**data)

    def test_missing_session_database_or_marker_is_rejected(self):
        check = self.checker()
        for field in ['marker', 'session_database']:
            with self.subTest(field=field):
                data = self.valid()
                data[field] = False
                with self.assertRaises(ValueError):
                    check(**data)


if __name__ == '__main__':
    unittest.main()
