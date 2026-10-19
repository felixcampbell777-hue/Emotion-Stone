"""Offline hosting checks use only fresh temporary directories."""
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('wr_backup', ROOT / 'hosting/backup.py')
backup_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup_module)


supervise_spec = importlib.util.spec_from_file_location('wr_supervise', ROOT / 'hosting/supervise.py')
supervise_module = importlib.util.module_from_spec(supervise_spec)
supervise_spec.loader.exec_module(supervise_module)


class PortChecks(unittest.TestCase):
    def test_default_and_custom_adjacent(self):
        self.assertEqual((24571,24572),supervise_module.configured_ports({}))
        self.assertEqual((30000,30001),supervise_module.configured_ports({'WORLD_RISE_PORT':'30000'}))

    def test_overflow_requires_explicit_distinct_voice(self):
        with self.assertRaises(ValueError):supervise_module.configured_ports({'WORLD_RISE_PORT':'65535'})
        self.assertEqual((65535,24572),supervise_module.configured_ports({'WORLD_RISE_PORT':'65535','WORLD_RISE_VOICE_PORT':'24572'}))

    def test_collision_and_privileged_ports_rejected(self):
        for environment in ({'WORLD_RISE_PORT':'1023'}, {'WORLD_RISE_PORT':'24571','WORLD_RISE_VOICE_PORT':'24571'}, {'WORLD_RISE_VOICE_PORT':'65536'}):
            with self.assertRaises(ValueError):supervise_module.configured_ports(environment)


class BackupChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='wr-hosting-check-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = self.root / 'data'
        self.data.mkdir()
        (self.data / 'world.json').write_text('{"sequence":42,"claims":["one"]}')
        (self.data / 'world.writer.lock').write_text('0')

    def test_roundtrip_and_retention(self):
        for _ in range(3):
            source = backup_module.backup(self.data, self.root / 'backups', 2)
        self.assertEqual(2, len(list((self.root / 'backups').glob('*.tar.gz'))))
        backup_module.restore(source, self.root / 'restored')
        self.assertEqual((self.data / 'world.json').read_bytes(), (self.root / 'restored/world.json').read_bytes())

    def test_live_refused(self):
        (self.data / 'ready.json').write_text('{}')
        with self.assertRaises(ValueError):
            backup_module.backup(self.data, self.root / 'backups', 2)

    def test_writer_before_readiness_refused(self):
        with backup_module.offline_world(self.data):
            with self.assertRaisesRegex(ValueError, 'active writer'):
                backup_module.backup(self.data, self.root / 'backups', 2)
        source = backup_module.backup(self.data, self.root / 'backups', 2)
        self.assertTrue(source.is_file())

    def test_missing_writer_lock_refused(self):
        (self.data / 'world.writer.lock').unlink()
        with self.assertRaisesRegex(ValueError, 'writer lock is missing'):
            backup_module.backup(self.data, self.root / 'backups', 2)

    def test_nonempty_restore_refused(self):
        source = backup_module.backup(self.data, self.root / 'backups', 2)
        with self.assertRaises(ValueError):
            backup_module.restore(source, self.data)

    def test_checksum_refused_before_install(self):
        archive = self.root / 'bad.tar.gz'
        with tarfile.open(archive, 'w:gz') as output:
            for name, raw in [('data/world.json', b'corrupt'), ('backup-manifest.json', json.dumps({'format': 1, 'files': {'world.json': '0' * 64}}).encode())]:
                item = tarfile.TarInfo(name)
                item.size = len(raw)
                output.addfile(item, io.BytesIO(raw))
        target = self.root / 'restored'
        with self.assertRaises(ValueError):
            backup_module.restore(archive, target)
        self.assertFalse(target.exists())

    def test_admin_commands_not_replayed_on_restore(self):
        (self.data / 'admin.request.json').write_text('{"op":"restart"}')
        (self.data / 'admin.result.json').write_text('{}')
        (self.data / 'world.json.request.json').write_text('{"unacknowledged":true}')
        (self.data / 'world.writer.lock').write_text('0')
        for name in ('world.json.pending.abc123','world.json.request.abc123.json','world.json.request.abc123.json.pending'):
            (self.data / name).write_text('unacknowledged')
        (self.data / 'world.json.previous').write_text('durable backup')
        source = backup_module.backup(self.data, self.root / 'backups', 2)
        backup_module.restore(source, self.root / 'restored')
        self.assertFalse((self.root / 'restored/admin.request.json').exists())
        self.assertFalse((self.root / 'restored/admin.result.json').exists())
        self.assertFalse((self.root / 'restored/world.json.request.json').exists())
        self.assertFalse((self.root / 'restored/world.writer.lock').exists())
        for name in ('world.json.pending.abc123','world.json.request.abc123.json','world.json.request.abc123.json.pending'):
            self.assertFalse((self.root / 'restored' / name).exists())
        self.assertEqual('durable backup',(self.root / 'restored/world.json.previous').read_text())

    def test_symlink_refused(self):
        (self.data / 'outside').symlink_to(self.root / 'outside')
        with self.assertRaises(ValueError):
            backup_module.backup(self.data, self.root / 'backups', 2)


if __name__ == '__main__':
    unittest.main()
