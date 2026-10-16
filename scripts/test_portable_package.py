import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


class PortablePackageTests(unittest.TestCase):
    def test_windows_zip_contains_portable_marker_and_full_bundle(self):
        scripts = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'scripts').mkdir()
            for name in ['app_build.py', 'package_release.py']:
                shutil.copy2(scripts / name, root / 'scripts' / name)
            (root / 'pubspec.yaml').write_text('version: 0.1.0+1\n', encoding='utf-8')
            bundle = root / 'build/windows/x64/runner/Release'
            for name in [
                'zhenguojian.exe', 'duanju_core.dll', 'flutter_windows.dll',
                'libffmpegkit.dll', 'libmpv-2.dll', 'msvcp140.dll',
                'vcruntime140.dll', 'data/icudtl.dat', 'data/app.so',
            ]:
                target = bundle / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b'fixture')
            subprocess.run(
                [sys.executable, str(root / 'scripts/package_release.py'),
                 '--platform', 'windows', '--all-sources'],
                check=True, capture_output=True, text=True,
            )
            package = root / 'dist/windows/zhenguojian-0.1.0+1-windows-x64.zip'
            with zipfile.ZipFile(package) as archive:
                names = set(archive.namelist())
                self.assertIn('portable.flag', names)
                self.assertIn('zhenguojian.exe', names)
                self.assertIn('data/app.so', names)
                self.assertNotIn('hongguojian.exe', names)


if __name__ == '__main__':
    unittest.main()
