import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import warnings
import zipfile

spec=importlib.util.spec_from_file_location('portable',Path(__file__).parents[1]/'scripts/verify-package.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class PackageTests(unittest.TestCase):
    def verify(self,entries):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'package.zip'
            with zipfile.ZipFile(path,'w') as z:
                for name,data in entries:z.writestr(name,data)
            return m.verify(path)
    def test_missing_runtime_license_rejected(self):
        with self.assertRaisesRegex(ValueError,'Missing runtime license'):self.verify([('YierBubu/README.txt','hello')])
    def test_zip_traversal_rejected(self):
        with self.assertRaisesRegex(ValueError,'Unsafe ZIP'):self.verify([('../outside.txt','never extract')])
    def test_duplicate_zip_members_rejected(self):
        with warnings.catch_warnings():
            warnings.simplefilter('ignore',UserWarning)
            with self.assertRaisesRegex(ValueError,'Duplicate'):self.verify([('a','first'),('a','second')])
    def test_third_party_notices_are_required(self):
        with self.assertRaisesRegex(ValueError,'third-party'):
            self.verify([('YierBubu/RuntimeNotices/Microsoft.NETCore.App/LICENSE.TXT','MIT'),('YierBubu/RuntimeNotices/Microsoft.WindowsDesktop.App/LICENSE','MIT')])
    def test_x86_executable_rejected(self):
        exe=bytearray(128);exe[:2]=b'MZ';struct.pack_into('<I',exe,0x3c,64);exe[64:68]=b'PE\0\0';struct.pack_into('<H',exe,68,0x14c)
        entries=[('YierBubu/RuntimeNotices/Microsoft.NETCore.App/LICENSE.TXT','MIT'),('YierBubu/RuntimeNotices/Microsoft.NETCore.App/THIRD-PARTY-NOTICES.TXT','third'),('YierBubu/RuntimeNotices/Microsoft.WindowsDesktop.App/LICENSE','MIT'),('YierBubu/YierBubu.exe',exe)]
        with self.assertRaisesRegex(ValueError,'x64'):self.verify(entries)
if __name__=='__main__':unittest.main()
