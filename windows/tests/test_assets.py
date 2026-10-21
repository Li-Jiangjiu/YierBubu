import hashlib
import importlib.util
import io
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

class AssetsTests(unittest.TestCase):
    def setUp(self):
        spec=importlib.util.spec_from_file_location('assets',Path(__file__).parents[1]/'scripts/prepare-assets.py')
        self.m=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.m)
    def test_ico_uses_256_png_without_redrawing(self):
        png=b'\x89PNG\r\n\x1a\n'+struct.pack('>I4sII',13,b'IHDR',256,256)+b'\x08\x06\0\0\0'
        chunk=b'ic08'+struct.pack('>I',len(png)+8)+png
        ico=self.m.icon_from_icns(b'icns'+struct.pack('>I',len(chunk)+8)+chunk)
        self.assertEqual(struct.unpack('<HHH',ico[:6]),(0,1,1))
        self.assertEqual(struct.unpack('<I',ico[18:22])[0],22)
        self.assertEqual(ico[22:],png)
    def test_corrupt_icon_and_wrong_dimensions_rejected(self):
        for value in (b'',b'icns\0\0\0\x08',b'icns\0\0\0\x10ic08\0\0\0\x01'):
            with self.assertRaises(ValueError):self.m.icon_from_icns(value)
    def test_hash_mismatch_is_rejected_before_extracting(self):
        with tempfile.TemporaryDirectory() as d:
            z=Path(d)/'source.zip';z.write_bytes(b'not a zip');out=Path(d)/'assets'
            with self.assertRaisesRegex(ValueError,'SHA256'):self.m.extract(z,out)
            self.assertFalse(out.exists())
    def test_archive_with_missing_required_files_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            z=Path(d)/'source.zip'
            with zipfile.ZipFile(z,'w') as f:f.writestr('../../unexpected.txt','never extract this')
            with self.assertRaisesRegex(ValueError,'Missing'):self.m.extract(z,Path(d)/'assets',hashlib.sha256(z.read_bytes()).hexdigest())
            self.assertFalse((Path(d)/'unexpected.txt').exists())
    def test_bad_png_cannot_be_treated_as_valid_runtime_art(self):
        with self.assertRaises(ValueError):self.m.validate_png(b'wrong',1536,1024)
    def test_approved_assets_validate_by_real_hash(self):
        root=Path(__file__).parents[2]/'Resources/Layered'
        if not root.exists():self.skipTest('private development resources not in public tree')
        for name,sha in self.m.LAYERS.items():
            data=(root/name).read_bytes();self.m.validate_png(data,1536,1024)
            self.assertEqual(hashlib.sha256(data).hexdigest(),sha)

if __name__=='__main__':unittest.main()
