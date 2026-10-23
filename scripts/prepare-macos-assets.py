#!/usr/bin/env python3
"""Recover runtime resources from the fixed public release; artwork is not MIT."""
import argparse
import hashlib
from pathlib import Path
import shutil
import tempfile
import urllib.request
import zipfile

SOURCE_URL = 'https://github.com/Li-Jiangjiu/YierBubu/releases/download/v0.4.0-beta.3/YierBubu-macOS-Universal-v0.4.0-beta.3.zip'
SOURCE_SHA256 = 'e4aa6030330ec0fdbb31bd63d6739793f1086cacf82b4eea1e4187ed8ddaed6b'
PREFIX = 'YierBubu/YierBubu.app/Contents/Resources/'
ENTRIES = {PREFIX + 'Layered/' + name: 'Layered/' + name for name in (
    'compact-scene.png', 'compact-cleanplate.png', 'compact-paws.png')}
ENTRIES[PREFIX + 'YierBubu.icns'] = 'Icon/YierBubu.icns'


def extract(archive, output, expected_hash=SOURCE_SHA256):
    archive, output = Path(archive), Path(output).absolute()
    if hashlib.sha256(archive.read_bytes()).hexdigest() != expected_hash:
        raise ValueError('Source ZIP SHA256 mismatch')
    payload = {}
    with zipfile.ZipFile(archive) as z:
        for member, relative in ENTRIES.items():
            matches = [i for i in z.infolist() if i.filename == member]
            if len(matches) != 1:
                raise ValueError('Missing or duplicate runtime resource: ' + member)
            if matches[0].file_size > 16 * 1024 * 1024:
                raise ValueError('Runtime resource too large: ' + member)
            payload[relative] = z.read(matches[0])
    # Validate every destination before creating or writing any file.
    for relative in payload:
        destination = output / relative
        if any(p.is_symlink() for p in (destination, *destination.parents)):
            raise ValueError('Refusing symlinked resource destination')
        if destination.exists() and destination.read_bytes() != payload[relative]:
            raise ValueError('Refusing to overwrite different resource: ' + relative)
    for relative, data in payload.items():
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, help='Use an already downloaded, checksum-verified release ZIP')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'Resources')
    args = parser.parse_args()
    if args.archive:
        extract(args.archive, args.output)
    else:
        with tempfile.TemporaryDirectory(prefix='yierbubu-mac-assets-') as temp:
            archive = Path(temp) / 'approved-macos.zip'
            with urllib.request.urlopen(SOURCE_URL, timeout=120) as response, archive.open('wb') as file:
                shutil.copyfileobj(response, file)
            extract(archive, args.output)
    print('Three runtime PNGs and ICNS verified from the fixed release. Artwork rights are separate from MIT.')


if __name__ == '__main__':
    main()
