import importlib.util
import hashlib
from pathlib import Path
import tempfile
import unittest
import zipfile


class MacAssetsTests(unittest.TestCase):
    def setUp(self):
        script = Path(__file__).parents[1] / 'prepare-macos-assets.py'
        self.assertTrue(script.is_file(), 'Mac source checkout needs an asset preparation entry point')
        spec = importlib.util.spec_from_file_location('mac_assets', script)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def test_bad_archive_hash_writes_nothing(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp).resolve() / 'bad.zip'
            archive.write_bytes(b'not the approved archive')
            output = Path(temp).resolve() / 'resources'
            with self.assertRaisesRegex(ValueError, 'SHA256'):
                self.module.extract(archive, output)
            self.assertFalse(output.exists())

    def test_extracts_only_fixed_runtime_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp).resolve() / 'fixture.zip'
            expected = self.module.ENTRIES
            with zipfile.ZipFile(archive, 'w') as z:
                for member in expected:
                    z.writestr(member, member.encode())
                z.writestr('../../outside.txt', 'must never extract')
            output = Path(temp).resolve() / 'resources'
            self.module.extract(archive, output, hashlib.sha256(archive.read_bytes()).hexdigest())
            actual = {str(p.relative_to(output)) for p in output.rglob('*') if p.is_file()}
            self.assertEqual(actual, set(expected.values()))
            self.assertFalse((Path(temp) / 'outside.txt').exists())

    def test_missing_member_writes_nothing(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp).resolve() / 'missing.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                z.writestr('unrelated', 'irrelevant')
            output = Path(temp).resolve() / 'resources'
            with self.assertRaisesRegex(ValueError, 'Missing'):
                self.module.extract(archive, output, hashlib.sha256(archive.read_bytes()).hexdigest())
            self.assertFalse(output.exists())
