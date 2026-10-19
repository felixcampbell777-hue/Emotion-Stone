"""Release gate checks with tiny disposable packages, no engine or player data."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import prepare_release_downloads as release
import zipfile

from prepare_release_downloads import archive, sha, verified_package
from runtime_paths import isolated_environment


class ReleaseChecks(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory(prefix='wr-release-check-')
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        self.folder = self.root / 'package'
        self.folder.mkdir()
        self.binary = self.folder / 'server.x86_64'
        self.binary.write_bytes(b'fixture executable bytes')
        self.manifest = {'game_version': '0.42.0', 'source_stable_during_export': True,
                         'validated_content': True, 'source_before': {'scripts': 'frozen'},
                         'source_after': {'scripts': 'frozen'}, 'files': {'server.x86_64': sha(self.binary)}}
        self.save()

    def save(self):
        (self.folder / 'manifest.json').write_text(json.dumps(self.manifest))

    def verify(self):
        return verified_package(self.folder, {'scripts': 'frozen'}, '0.42.0')

    def test_current_release_requires_three_original_categories(self):
        catalog = self.root / 'game/content/world_rise/skills.json'
        catalog.parent.mkdir(parents=True)
        current = {'tree_version': 6, 'attributes': [{'id': value} for value in ('strength', 'agility', 'greatsword')]}
        catalog.write_text(json.dumps(current))
        with mock.patch.object(release, 'ROOT', self.root):
            self.assertEqual(6, release.progression_contract()['tree_version'])
            current['attributes'] = [{'id': value} for value in ('body', 'reflexes', 'technical_ability', 'intelligence', 'cool')]
            catalog.write_text(json.dumps(current))
            with self.assertRaisesRegex(ValueError, 'Strength, Agility and Greatsword'):
                release.progression_contract()

    def test_valid_package_and_tampered_binary(self):
        self.assertEqual(2, len(self.verify()))
        self.binary.write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
            self.verify()

    def test_source_and_validation_gates(self):
        for key, value in [('source_stable_during_export', False), ('validated_content', False),
                           ('source_after', {'scripts': 'drifted'}), ('game_version', '0.41.4')]:
            with self.subTest(key=key):
                original = self.manifest[key]
                self.manifest[key] = value
                self.save()
                with self.assertRaises(ValueError):
                    self.verify()
                self.manifest[key] = original

    def test_manifest_path_traversal_refused(self):
        self.manifest['files'] = {'../private-file': 'anything'}
        self.save()
        with self.assertRaisesRegex(ValueError, 'Unsafe manifest member'):
            self.verify()

    def test_archive_is_reproducible_and_executable(self):
        files = [('output/server.x86_64', self.binary), ('manifest.json', self.folder / 'manifest.json')]
        first, second = self.root / 'one.zip', self.root / 'two.zip'
        archive(first, files)
        archive(second, reversed(files))
        self.assertEqual(sha(first), sha(second))
        with zipfile.ZipFile(first) as content:
            self.assertEqual(0o100755, content.getinfo('output/server.x86_64').external_attr >> 16)
            self.assertEqual(self.binary.read_bytes(), content.read('output/server.x86_64'))

    def test_fixture_temp_paths_are_inside_disposable_root(self):
        env = isolated_environment(self.root / 'isolated')
        for key in ('TMPDIR', 'TEMP', 'TMP', 'APPDATA', 'XDG_DATA_HOME'):
            self.assertTrue(Path(env[key]).is_relative_to(self.root))
            self.assertTrue(Path(env[key]).is_dir())


if __name__ == '__main__':
    unittest.main()
